class_name Enemy
extends CharacterBody2D
## 普通怪：行为由 enemies.csv 的 behavior / behavior_param 决定。
## melee_chase / swarm / tank：近战追击；charge：蓄力冲撞；ranged：保持距离吐弹；hit_and_run：咬两口后撤。

signal died(enemy: Enemy)

var def: EnemyDef
var battle: Battle
var max_hp := 100.0
var hp := 100.0
var atk := 10.0
var defense := 0.0
var alive := true
var facing := -1
var attack_cd := 0.5
var stun_t := 0.0
var slow_t := 0.0
var slow_pct := 0.0
var def_down_t := 0.0
var def_down_pct := 0.0
var knock_left := 0.0
var stand_offset := 0.0
var reward_mult := 1.0
var last_hit_gongfa := ""   # 最近一次技能命中的功法（雷核击杀返还用）
# 行为状态
var _charge_state := 0     # 0 无 / 1 蓄力 / 2 冲刺
var _charge_t := 0.0
var _dash_left := 0.0
var _dash_dir := -1
var _dash_hit := false
var _hits_landed := 0
var _retreat_left := 0.0
var _flash_t := 0.0

@onready var sprite: Sprite2D = $Sprite2D

func setup(d: EnemyDef, hp_mult: float, atk_mult: float, b: Battle) -> void:
	def = d
	battle = b
	max_hp = d.hp * hp_mult
	hp = max_hp
	atk = d.atk * atk_mult
	defense = d.def
	reward_mult = hp_mult
	attack_cd = 0.3 + b.rng.randf() * 0.5
	stand_offset = b.rng.randf_range(0.0, 0.35) * d.attack_range_px
	var tex := load(d.texture_path()) as Texture2D if ResourceLoader.exists(d.texture_path()) else null
	if sprite and tex:
		sprite.texture = tex
		# 脚底锚点对齐节点原点（style_guide：普通怪 (128,152)，首领 (160,308)，即底边上8/12px）
		var sz := tex.get_size()
		var anchor := Vector2(sz.x / 2.0, sz.y - (12.0 if d.is_boss() else 8.0))
		sprite.offset = sz / 2.0 - anchor

func is_boss() -> bool:
	return def != null and def.is_boss()

## 霸体：首领与 super_armor=true 的怪不受击退/眩晕（眩晕对首领减半见 apply_stun）
func is_super_armor() -> bool:
	return is_boss() or def.param_b("super_armor")

func effective_def() -> float:
	return defense * (1.0 - (def_down_pct if def_down_t > 0.0 else 0.0))

## 体型外沿：距离判定（玩家普攻/技能选敌、自动走位）减去该值。普通怪 0；首领见 Boss。
func body_extent() -> float:
	return 0.0

func take_damage(raw: float, crit: bool, tag: String = "", ignore_def: bool = false) -> float:
	if not alive:
		return 0.0
	var d := 0.0 if ignore_def else effective_def()
	var dmg := raw * (1.0 - d / (d + GameData.const_f("DEF_CONST", 100.0)))
	dmg = maxf(dmg, 1.0)
	hp -= dmg
	_flash_t = 0.1
	battle.show_damage_number(self, dmg, crit, tag)
	if hp <= 0.0:
		hp = 0.0
		alive = false
		died.emit(self)
	queue_redraw()
	return dmg

func apply_effect(kind: String, value: float, duration: float) -> void:
	match kind:
		"def_down_pct":
			def_down_pct = maxf(def_down_pct if def_down_t > 0.0 else 0.0, value)
			def_down_t = maxf(def_down_t, duration)
		"slow_pct":
			slow_pct = value
			slow_t = maxf(slow_t, maxf(duration, 0.6))
		"stun_s":
			if def.param_b("super_armor"):
				return
			stun_t = maxf(stun_t, value * (0.5 if is_boss() else 1.0))
		"knockback_px":
			if not is_super_armor():
				knock_left = value

func speed() -> float:
	return def.move_speed * (1.0 - (slow_pct if slow_t > 0.0 else 0.0))

func step(delta: float) -> void:
	if not alive:
		return
	stun_t = maxf(stun_t - delta, 0.0)
	slow_t = maxf(slow_t - delta, 0.0)
	def_down_t = maxf(def_down_t - delta, 0.0)
	attack_cd -= delta
	_flash_t = maxf(_flash_t - delta, 0.0)
	var p := battle.player
	if knock_left > 0.0:
		var k := minf(knock_left, 900.0 * delta)
		position.x += k * signf(position.x - p.position.x)
		knock_left -= k
	elif stun_t <= 0.0 and battle.combat_active():
		_behave(delta, p)
	if sprite:
		sprite.flip_h = facing > 0   # style_guide：敌人素材面朝左，向右时翻转
		sprite.modulate = Color(1.6, 1.6, 1.6) if _flash_t > 0.0 else Color.WHITE
	queue_redraw()

func _behave(delta: float, p: Player) -> void:
	var dx := p.position.x - position.x
	var dist := absf(dx)
	if _charge_state == 0 and _retreat_left <= 0.0:
		facing = 1 if dx > 0 else -1
	match def.behavior:
		"charge":
			_behave_charge(delta, p, dx, dist)
		"ranged":
			_behave_ranged(delta, p, dx, dist)
		"hit_and_run":
			if _retreat_left > 0.0:
				var m := speed() * delta
				position.x -= signf(dx) * m
				_retreat_left -= m
			else:
				_behave_melee(delta, p, dx, dist)
		_:
			_behave_melee(delta, p, dx, dist)

func _behave_melee(delta: float, _p: Player, dx: float, dist: float) -> void:
	var reach := def.attack_range_px
	var stop := minf(reach * 0.6 + stand_offset, reach * 0.95)
	if dist > stop:
		position.x += signf(dx) * minf(speed() * delta, dist - stop)
	if dist <= reach + Player.HALF_WIDTH and attack_cd <= 0.0:
		attack_cd = def.attack_interval_s
		var coef := def.param_f("smash_coef", 1.0)
		battle.enemy_contact_hit(self, atk * coef)
		_hits_landed += 1
		var after := int(def.param_f("retreat_after_hits", 0))
		if def.behavior == "hit_and_run" and after > 0 and _hits_landed % after == 0:
			_retreat_left = def.param_f("retreat_px", 200.0)

func _behave_charge(delta: float, p: Player, dx: float, dist: float) -> void:
	match _charge_state:
		0:
			if dist <= def.param_f("dash_trigger_px", 280.0) and dist > def.attack_range_px and attack_cd <= 0.0:
				_charge_state = 1
				_charge_t = 0.5
				_dash_dir = 1 if dx > 0 else -1
			else:
				_behave_melee(delta, p, dx, dist)
		1:
			_charge_t -= delta
			if _charge_t <= 0.0:
				_charge_state = 2
				_dash_left = def.param_f("dash_px", 260.0)
				_dash_hit = false
		2:
			var m := minf(_dash_left, def.move_speed * 5.0 * delta)
			position.x += _dash_dir * m
			_dash_left -= m
			if not _dash_hit and absf(p.position.x - position.x) <= def.attack_range_px * 0.5 + Player.HALF_WIDTH:
				_dash_hit = true
				battle.enemy_contact_hit(self, atk * def.param_f("dash_coef", 1.5))
			if _dash_left <= 0.0:
				_charge_state = 0
				attack_cd = def.attack_interval_s

func _behave_ranged(delta: float, _p: Player, dx: float, dist: float) -> void:
	var keep := def.param_f("keep_distance_px", 300.0)
	if dist > def.attack_range_px:
		position.x += signf(dx) * speed() * delta
	elif dist < keep * 0.8:
		position.x -= signf(dx) * speed() * 0.6 * delta
	if dist <= def.attack_range_px and attack_cd <= 0.0:
		attack_cd = def.attack_interval_s
		battle.spawn_enemy_bolt(self, atk, def.param_f("projectile_speed", 350.0))

func _draw() -> void:
	if not alive:
		return
	var w := 70.0
	var top := -(sprite.texture.get_size().y - 8.0 if sprite and sprite.texture else 120.0) - 8.0
	if is_boss():
		return   # 首领血条在 HUD 顶部
	draw_rect(Rect2(-w / 2, top, w, 6), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-w / 2, top, w * hp / max_hp, 6), Color("#C9433A"))
	if stun_t > 0.0:
		draw_string(UiStyle.world_font(), Vector2(-12, top - 4), UiText.t("FLOAT_STUN"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.YELLOW)

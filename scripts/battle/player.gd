class_name Player
extends CharacterBody2D
## 主角。所有动作（移动、闪避、普攻、释放技能）都走同一套接口，自动AI和玩家输入共用（计划3.2）。
## 伤害/冷却/计时全部在 step()（由 Battle 物理更新驱动）里处理，Sprite 只做表现。

signal hp_changed(hp: float, max_hp: float)
signal shield_changed(total: float, max_hp: float)
signal dodge_state_changed(cooldown_left: float, cooldown_total: float)

const HALF_WIDTH := 22.0
const FRAMES: SpriteFrames = preload("res://art/characters/hero/chr_hero.tres")
## 正式美术（art/final 第1批）接入：AnimatedSprite2D centered=true，脚底锚点 (144,184) → offset (-16,-88)；朝左 flip_h 且 offset.x 取反
const SPRITE_OFFSET := Vector2(-16, -88)

var battle: Battle
var stats := {}
var max_hp := 500.0
var hp := 500.0
var alive := true
var facing := 1
var god_mode := false            # 测试用
var _move_dir := 0.0
var dodge_t := 0.0               # >0 = 闪避位移中
var dodge_elapsed := -1.0        # 本次闪避已过时间；0 ≤ elapsed ≤ DODGE_DURATION 期间免伤（含按下当帧，共18帧）
var dodge_cd := 0.0
var _dodge_dir := 1
var attack_cd := 0.0
var shields: Array[Dictionary] = []   # {skill_id, amount, max, time, absorbed, reflect_add, counter_coef, burst_*}
var dmg_reduce_t := 0.0
var dmg_reduce_v := 0.0
var _attack_pending_t := 0.0     # >0 = 普攻前摇中（到命中帧结算伤害）
var _moving := false
var _oneshot := ""               # 正在播放的一次性动作 attack/cast/hit

@onready var sprite: AnimatedSprite2D = $Sprite2D

## 动作帧 → 逻辑时间（从 SpriteFrames 读帧率，帧号可由 constants 覆盖）
static func frame_time(anim: StringName, frame_index: int) -> float:
	var fps := FRAMES.get_animation_speed(anim) if FRAMES.has_animation(anim) else 0.0
	return frame_index / fps if fps > 0.0 else 0.0

static func anim_length(anim: StringName) -> float:
	var fps := FRAMES.get_animation_speed(anim) if FRAMES.has_animation(anim) else 0.0
	return FRAMES.get_frame_count(anim) / fps if fps > 0.0 else 0.0

func attack_hit_delay() -> float:
	return frame_time(&"attack", GameData.const_i("HERO_ATTACK_HIT_FRAME", 3))

func cast_release_delay() -> float:
	return frame_time(&"cast", GameData.const_i("HERO_CAST_RELEASE_FRAME", 3))

func _ready() -> void:
	if sprite:
		sprite.animation_finished.connect(_on_anim_finished)
		sprite.play(&"idle")

func reset_for_run(st: Dictionary) -> void:
	stats = st
	max_hp = float(st.get("max_hp", 500.0))
	hp = max_hp
	alive = true
	dodge_t = 0.0
	dodge_elapsed = -1.0
	dodge_cd = 0.0
	attack_cd = 0.0
	_attack_pending_t = 0.0
	_oneshot = ""
	if sprite:
		sprite.play(&"idle")
	shields.clear()
	dmg_reduce_t = 0.0
	modulate = Color.WHITE
	rotation = 0.0
	hp_changed.emit(hp, max_hp)
	shield_changed.emit(0.0, max_hp)

# ---------- 动作接口（AI 与输入共用） ----------
func move(dir: float) -> void:
	_move_dir = clampf(dir, -1.0, 1.0)

func face(dir: int) -> void:
	if dir != 0:
		facing = signi(dir)

func dodge(dir: int = 0) -> bool:
	if not alive or dodge_cd > 0.0 or dodge_t > 0.0:
		return false   # 冷却中忽略，不排队
	_dodge_dir = dir if dir != 0 else facing
	_attack_pending_t = 0.0   # 闪避打断普攻前摇
	dodge_t = GameData.const_f("DODGE_DURATION", 0.3)
	dodge_elapsed = 0.0
	dodge_cd = GameData.const_f("DODGE_COOLDOWN", 3.0)
	return true

func is_dodging() -> bool:
	return dodge_t > 0.0

func is_invulnerable() -> bool:
	return in_dodge_iframes() or god_mode

## 免伤窗口：按下当帧起 DODGE_DURATION 秒（含端点，固定步长下恰 18 帧），与位移计时分开（BUG-006）
func in_dodge_iframes() -> bool:
	return dodge_elapsed >= 0.0 and dodge_elapsed <= GameData.const_f("DODGE_DURATION", 0.3) + 1e-6

func dodge_cooldown_total() -> float:
	return GameData.const_f("DODGE_COOLDOWN", 3.0)

# ---------- 护盾 ----------
func add_shield(data: Dictionary) -> void:
	# 同一技能重复释放：替换旧盾（旧盾按“结束”处理，金刚不坏会爆发）
	for s in shields.duplicate():
		if s.skill_id == data.skill_id:
			_end_shield(s, false)
	data["absorbed"] = 0.0
	shields.append(data)
	_emit_shield()

func shield_total() -> float:
	var t := 0.0
	for s in shields:
		t += s.amount
	return t

func has_shield_from(skill_id: String) -> bool:
	for s in shields:
		if s.skill_id == skill_id and s.amount > 0.0:
			return true
	return false

## 护盾期间的额外反伤（护体 effect2 reflect_add）
func shield_reflect_bonus() -> float:
	var r := 0.0
	for s in shields:
		r += float(s.get("reflect_add", 0.0))
	return r

## 反震系数（护体 damage_coef），没有则 0
func shield_counter_coef() -> float:
	var c := 0.0
	for s in shields:
		c = maxf(c, float(s.get("counter_coef", 0.0)))
	return c

const SHIELD_FX_SCENE := "res://art/fx/shield_fx.tscn"
## 护盾正式特效（第 3 批 shield_fx.tscn）：原点在身体中心（脚底上方约 90px），有盾时显示，护盾吸收伤害时 hit()
var shield_fx: Node2D

func _sync_shield_fx(hit := false) -> void:
	var on := shield_total() > 0.0
	if shield_fx == null:
		if not on or battle == null or not battle.visual_fx or not ResourceLoader.exists(SHIELD_FX_SCENE):
			return
		shield_fx = load(SHIELD_FX_SCENE).instantiate()
		shield_fx.position = Vector2(0, -90)
		shield_fx.scale = Vector2.ONE * 0.85
		add_child(shield_fx)
	shield_fx.visible = on
	if hit and on and shield_fx.has_method("hit"):
		shield_fx.call("hit")

## 用护盾吸收伤害，返回剩余伤害（新盾先吸收）
func absorb(dmg: float) -> float:
	var hit_shield := dmg > 0.0 and shield_total() > 0.0
	var i := shields.size() - 1
	while i >= 0 and dmg > 0.0:
		var s: Dictionary = shields[i]
		var a := minf(s.amount, dmg)
		s.amount -= a
		s.absorbed += a
		dmg -= a
		if s.amount <= 0.0:
			_end_shield(s, true)
		i -= 1
	_emit_shield()
	if hit_shield:
		_sync_shield_fx(true)
	return dmg

func _end_shield(s: Dictionary, broken: bool) -> void:
	shields.erase(s)
	if battle:
		battle.on_shield_ended(s, broken)
	_emit_shield()

func _emit_shield() -> void:
	shield_changed.emit(shield_total(), max_hp)
	_sync_shield_fx()

func damage_reduce() -> float:
	return dmg_reduce_v if dmg_reduce_t > 0.0 else 0.0

func apply_hp_loss(amount: float) -> void:
	if not alive:
		return
	hp = maxf(hp - amount, 0.0)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		alive = false
		_attack_pending_t = 0.0
		_oneshot = ""
		if sprite:
			sprite.speed_scale = 1.0
			sprite.play(&"death")
	elif amount > 0.0 and _oneshot == "" and dodge_t <= 0.0:
		_play_oneshot(&"hit")

# ---------- 物理更新 ----------
func step(delta: float) -> void:
	if not alive:
		_move_dir = 0.0
		return
	if dodge_cd > 0.0:
		dodge_cd = _tick_timer(dodge_cd, delta)
		dodge_state_changed.emit(dodge_cd, dodge_cooldown_total())
	if dmg_reduce_t > 0.0:
		dmg_reduce_t -= delta
	for s in shields.duplicate():
		s.time -= delta
		if s.time <= 0.0:
			_end_shield(s, false)
	attack_cd -= delta
	if dodge_elapsed >= 0.0:
		dodge_elapsed += delta
		if not in_dodge_iframes():
			dodge_elapsed = -1.0
	if dodge_t > 0.0:
		var dur := GameData.const_f("DODGE_DURATION", 0.3)
		# BUG-006：按实际剩余时间截断位移，计时用阈值消除浮点残差（位移恰为 DODGE_DISTANCE）
		position.x += _dodge_dir * GameData.const_f("DODGE_DISTANCE", 160.0) / maxf(dur, 0.01) * minf(delta, dodge_t)
		dodge_t = _tick_timer(dodge_t, delta)
	else:
		position.x += _move_dir * float(stats.get("move_speed", 220.0)) * delta
		if absf(_move_dir) > 0.01:
			facing = 1 if _move_dir > 0 else -1
		if _attack_pending_t > 0.0:
			_attack_pending_t -= delta
			if _attack_pending_t <= 0.0:
				_attack_hit()
		else:
			_try_normal_attack()
	if battle:
		position.x = maxf(position.x, battle.left_bound)
	_moving = absf(_move_dir) > 0.01 and dodge_t <= 0.0
	_move_dir = 0.0
	_update_visual(delta)

## 计时器递减；剩余小于 1e-6 视为 0（固定步长 1/60 累减的浮点残差）
static func _tick_timer(t: float, delta: float) -> float:
	var r := t - delta
	return r if r > 1e-6 else 0.0

## 普攻：敌人进入射程后自动触发（手动/自动模式都一样）。
## 起手播放 attack，到命中帧（第 HERO_ATTACK_HIT_FRAME 帧，按 SpriteFrames 帧率换算）才结算伤害；
## 攻速快于动作长度时动作加速，命中帧同比提前。闪避会打断前摇。
func _try_normal_attack() -> void:
	if attack_cd > 0.0 or battle == null:
		return
	var rng := GameData.const_f("PLAYER_NORMAL_ATK_RANGE", 150.0)
	var target := battle.nearest_enemy(position.x, rng)
	if target == null:
		return
	face(signi(int(target.position.x - position.x)))
	var interval := GameData.const_f("PLAYER_NORMAL_ATK_INTERVAL", 0.8) / (1.0 + float(stats.get("atk_speed", 0.0)))   # 词条：攻速
	attack_cd = interval
	var speed := maxf(1.0, anim_length(&"attack") / maxf(interval, 0.01))
	_attack_pending_t = attack_hit_delay() / speed
	_play_oneshot(&"attack", speed)
	if _attack_pending_t <= 0.0:
		_attack_hit()

func _attack_hit() -> void:
	_attack_pending_t = 0.0
	if battle == null or not alive:
		return
	# 命中帧时重新选目标（前摇期间原目标可能已死）
	var target := battle.nearest_enemy(position.x, GameData.const_f("PLAYER_NORMAL_ATK_RANGE", 150.0))
	if target:
		battle.player_hit_enemy(target, GameData.const_f("PLAYER_NORMAL_ATK_COEF", 1.0), {"source": "normal"})

func is_attacking() -> bool:
	return _attack_pending_t > 0.0

func play_cast() -> void:
	_play_oneshot(&"cast")

func _play_oneshot(anim: StringName, speed: float = 1.0) -> void:
	if sprite == null or not alive:
		return
	_oneshot = String(anim)
	sprite.speed_scale = speed
	sprite.play(anim)
	sprite.frame = 0

func _on_anim_finished() -> void:
	if not alive:
		return
	_oneshot = ""
	sprite.speed_scale = 1.0

func _update_visual(_delta: float) -> void:
	if sprite == null:
		return
	sprite.flip_h = facing < 0
	sprite.offset = Vector2(-SPRITE_OFFSET.x if facing < 0 else SPRITE_OFFSET.x, SPRITE_OFFSET.y)
	sprite.modulate = Color.WHITE
	var want: StringName
	if not alive:
		want = &"death"   # 非循环，播完停在最后一帧（墨散）
	elif dodge_t > 0.0:
		want = &"dodge"
		# 动作长度（5帧@16fps≈0.31s）对齐 DODGE_DURATION，整段免伤
		sprite.speed_scale = anim_length(&"dodge") / maxf(GameData.const_f("DODGE_DURATION", 0.3), 0.01)
		_oneshot = ""
	elif _oneshot != "":
		want = StringName(_oneshot)
	else:
		want = &"walk" if _moving else &"idle"
		sprite.speed_scale = 1.0
	if sprite.animation != want or (not sprite.is_playing() and want != &"death"):
		sprite.play(want)
	queue_redraw()

func _draw() -> void:
	var sh := shield_total()
	if sh > 0.0 and shield_fx == null:   # 无正式特效（测试/缺件）时的程序护盾圈
		draw_arc(Vector2(0, -80), 95, 0, TAU, 48, Color("#F2C14E"), 4.0)
		draw_circle(Vector2(0, -80), 95, Color(0.95, 0.76, 0.3, 0.12))

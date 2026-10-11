class_name Player
extends CharacterBody2D
## 主角。所有动作（移动、闪避、普攻、释放技能）都走同一套接口，自动AI和玩家输入共用（计划3.2）。
## 伤害/冷却/计时全部在 step()（由 Battle 物理更新驱动）里处理，Sprite 只做表现。

signal hp_changed(hp: float, max_hp: float)
signal shield_changed(total: float, max_hp: float)
signal dodge_state_changed(cooldown_left: float, cooldown_total: float)

const HALF_WIDTH := 22.0

var battle: Battle
var stats := {}
var max_hp := 500.0
var hp := 500.0
var alive := true
var facing := 1
var god_mode := false            # 测试用
var _move_dir := 0.0
var dodge_t := 0.0               # >0 = 闪避中（免伤）
var dodge_cd := 0.0
var _dodge_dir := 1
var attack_cd := 0.0
var shields: Array[Dictionary] = []   # {skill_id, amount, max, time, absorbed, reflect_add, counter_coef, burst_*}
var dmg_reduce_t := 0.0
var dmg_reduce_v := 0.0
var _lunge_t := 0.0

@onready var sprite: Sprite2D = $Sprite2D

func reset_for_run(st: Dictionary) -> void:
	stats = st
	max_hp = float(st.get("max_hp", 500.0))
	hp = max_hp
	alive = true
	dodge_t = 0.0
	dodge_cd = 0.0
	attack_cd = 0.0
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
	dodge_t = GameData.const_f("DODGE_DURATION", 0.3)
	dodge_cd = GameData.const_f("DODGE_COOLDOWN", 3.0)
	return true

func is_dodging() -> bool:
	return dodge_t > 0.0

func is_invulnerable() -> bool:
	return dodge_t > 0.0 or god_mode

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

## 用护盾吸收伤害，返回剩余伤害（新盾先吸收）
func absorb(dmg: float) -> float:
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
	return dmg

func _end_shield(s: Dictionary, broken: bool) -> void:
	shields.erase(s)
	if battle:
		battle.on_shield_ended(s, broken)
	_emit_shield()

func _emit_shield() -> void:
	shield_changed.emit(shield_total(), max_hp)

func damage_reduce() -> float:
	return dmg_reduce_v if dmg_reduce_t > 0.0 else 0.0

func apply_hp_loss(amount: float) -> void:
	if not alive:
		return
	hp = maxf(hp - amount, 0.0)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		alive = false
		modulate = Color(1, 1, 1, 0.5)
		rotation = -PI / 2 * facing

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
	if dodge_t > 0.0:
		var dur := GameData.const_f("DODGE_DURATION", 0.3)
		# BUG-006：按实际剩余时间截断位移，计时用阈值消除浮点残差（位移恰为 DODGE_DISTANCE）
		position.x += _dodge_dir * GameData.const_f("DODGE_DISTANCE", 160.0) / maxf(dur, 0.01) * minf(delta, dodge_t)
		dodge_t = _tick_timer(dodge_t, delta)
	else:
		position.x += _move_dir * float(stats.get("move_speed", 220.0)) * delta
		if absf(_move_dir) > 0.01:
			facing = 1 if _move_dir > 0 else -1
		_try_normal_attack()
	if battle:
		position.x = maxf(position.x, battle.left_bound)
	_move_dir = 0.0
	_update_visual(delta)

## 普攻：敌人进入射程后自动触发（手动/自动模式都一样）
## 计时器递减；剩余小于 1e-6 视为 0（固定步长 1/60 累减的浮点残差）
static func _tick_timer(t: float, delta: float) -> float:
	var r := t - delta
	return r if r > 1e-6 else 0.0

func _try_normal_attack() -> void:
	if attack_cd > 0.0 or battle == null:
		return
	var rng := GameData.const_f("PLAYER_NORMAL_ATK_RANGE", 150.0)
	var target := battle.nearest_enemy(position.x, rng)
	if target == null:
		return
	face(signi(int(target.position.x - position.x)))
	battle.player_hit_enemy(target, GameData.const_f("PLAYER_NORMAL_ATK_COEF", 1.0), {"source": "normal"})
	attack_cd = GameData.const_f("PLAYER_NORMAL_ATK_INTERVAL", 0.8)
	_lunge_t = 0.15

func _update_visual(delta: float) -> void:
	if sprite == null:
		return
	sprite.flip_h = facing < 0
	_lunge_t = maxf(_lunge_t - delta, 0.0)
	sprite.position.x = (8.0 if _lunge_t > 0.0 else 0.0) * facing
	sprite.modulate = Color(1, 1, 1, 0.45) if dodge_t > 0.0 else Color.WHITE
	queue_redraw()

func _draw() -> void:
	var sh := shield_total()
	if sh > 0.0:
		draw_arc(Vector2(0, -80), 95, 0, TAU, 48, Color("#F2C14E"), 4.0)
		draw_circle(Vector2(0, -80), 95, Color(0.95, 0.76, 0.3, 0.12))

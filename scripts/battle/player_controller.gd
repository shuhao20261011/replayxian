class_name PlayerController
extends Node
## 输入与自动AI。两者调用同一套 Player / SkillSystem 动作接口（计划3.2）：
## - A/D/方向键移动、空格闪避：立即切到手动模式（停止输入后不自动恢复，需点“自动战斗”开关恢复）。
## - 1-4 释放技能：不退出自动模式；同一帧手动释放优先，本帧自动AI不再释放技能。
## - 自动模式负责移动、普攻（普攻本来就是进入射程自动触发）和设为自动的技能；不自动闪避。
## HUD 按钮通过 request_*() 注入与键盘相同的输入；测试通过 virtual_move / request_*() 驱动。

var battle: Battle
var read_device_input := true
var virtual_move := 0.0
var _pending_dodge := false
var _pending_toggle := false
var _pending_skills: Array[int] = []
var last_manual_casts: Array[int] = []

func request_skill(slot: int) -> void:
	_pending_skills.append(slot)

func request_dodge() -> void:
	_pending_dodge = true

func request_toggle_auto() -> void:
	_pending_toggle = true

func update(_delta: float) -> void:
	var move := virtual_move
	var dodge := _pending_dodge
	var toggle := _pending_toggle
	var skills := _pending_skills.duplicate()
	_pending_dodge = false
	_pending_toggle = false
	_pending_skills.clear()
	if read_device_input:
		move += Input.get_axis("move_left", "move_right")
		if Input.is_action_just_pressed("dodge"):
			dodge = true
		for i in PlayerState.slot_count():
			if InputMap.has_action("skill_%d" % (i + 1)) and Input.is_action_just_pressed("skill_%d" % (i + 1)):
				skills.append(i)
		if Input.is_action_just_pressed("toggle_auto"):
			toggle = true
	if toggle:
		PlayerState.set_auto_battle(not PlayerState.auto_battle)
	if absf(move) > 0.05 or dodge:
		PlayerState.set_auto_battle(false)
	var p := battle.player
	# 手动技能先处理（同一帧手动优先）
	last_manual_casts.clear()
	for slot in skills:
		if battle.skills.try_cast(slot, true):
			last_manual_casts.append(slot)
	if dodge:
		p.dodge(signi(int(signf(move))) if absf(move) > 0.05 else p.facing)
	if PlayerState.auto_battle:
		_auto_move()
		if last_manual_casts.is_empty():
			_auto_cast()
	else:
		p.move(move)

func _auto_move() -> void:
	var p := battle.player
	if not p.alive:
		return
	var target := battle.nearest_enemy(p.position.x)
	if target != null:
		var dx := target.position.x - p.position.x
		p.face(1 if dx > 0 else -1)
		var engage := GameData.const_f("PLAYER_NORMAL_ATK_RANGE", 150.0) * 0.8
		if absf(dx) > engage:
			p.move(signf(dx))
	elif battle.should_advance():
		p.move(1.0)

func _auto_cast() -> void:
	for slot in PlayerState.slot_count():
		if not PlayerState.slot_auto[slot] or not battle.skills.is_ready(slot):
			continue
		var s := battle.skills.skill_in_slot(slot)
		if not wants_auto_cast(s):
			continue
		if battle.skills.try_cast(slot, false):
			return   # 每帧最多自动释放1个技能

## 自动释放判定（含 v2 自动护盾AI）：
## - 护盾类且冷却 < AUTO_SHIELD_RESERVE_CD(默认12秒)：按冷却释放（有敌人交战时）。
## - 护盾类且冷却 ≥ 12秒（金刚不坏）：若首领有 true_maxhp 招式（玄岩天坠），预警期间可用就立刻放；
##   否则只在“冷却好之前不会撞上下一次天坠预警”时才放（为天坠预留）。
func wants_auto_cast(s: SkillDef) -> bool:
	if s == null:
		return false
	if s.shape == "self_buff":
		var cd := battle.skills.cooldown_for(s)
		if cd < GameData.const_f("AUTO_SHIELD_RESERVE_CD", 12.0):
			return battle.has_engaged_enemies()
		if battle.is_true_damage_telegraph_active():
			return true
		var eta := battle.time_until_next_true_damage_attack()
		if eta < INF:
			return eta > cd and battle.has_engaged_enemies()
		return battle.has_engaged_enemies()
	return battle.skills.has_valid_target(s)

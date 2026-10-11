class_name Boss
extends Enemy
## 首领：boss_pattern。招式来自 enemies.behavior_param.attack_ids → boss_attacks.csv，
## 按 min_level_index 逐关加入；危险攻击先显示预警（warn_s，默认 BOSS_WARN_TIME=0.8 秒），同一时刻最多1个危险攻击在预警中。

var level: LevelDef
var attacks: Array[BossAttackDef] = []
var timers := {}          # attack_id -> 距离下次可用的秒数
var busy_t := 0.0         # 危险攻击前摇/预警期间不移动、不普攻
var guard_delays := 0     # 调试/测试：被间隔保护推迟的帧数

func setup_boss(d: EnemyDef, lvl: LevelDef, b: Battle) -> void:
	level = lvl
	setup(d, lvl.boss_hp_mult, lvl.boss_atk_mult, b)
	attacks.clear()
	timers.clear()
	for aid in d.attack_ids:
		var a := GameData.get_boss_attack(aid)
		if a != null and a.min_level_index <= lvl.index:
			attacks.append(a)
			timers[a.id] = a.first_cast_s if a.is_danger else 0.0

## 危险招式最小间隔保护（v5 README 第4节，BUG-005）：表里的节拍已保证间隔，但掌心雷眩晕等会压缩节拍。
## 本招首个判定（现在+预警）距上一次危险判定须 ≥ DODGE_COOLDOWN + DANGER_MIN_GAP_MARGIN_S，否则推迟释放。
static func min_danger_gap() -> float:
	return GameData.const_f("DODGE_COOLDOWN", 3.0) + GameData.const_f("DANGER_MIN_GAP_MARGIN_S", 0.5)

## 预警从起手的下一帧开始计时（BUG-014），判定时刻 = 起手时刻 + warn
func danger_gap_ok(warn: float, _delta: float = 0.0) -> bool:
	if battle.last_danger_resolve_t < 0.0:
		return true
	return battle.sim_time + warn - battle.last_danger_resolve_t >= min_danger_gap() - 1e-6
## 首领占位图较宽（≈240px），与主角保持的最小中心距离
static func min_spacing() -> float:
	return GameData.const_f("BOSS_MIN_SPACING_PX", 180.0)

func stand_distance() -> float:
	return maxf(def.attack_range_px, min_spacing())

## 玩家普攻/技能/自动走位按“体型外沿”计算：首领比普通怪多出 (最小间距 − 自动普攻接敌距离)
func body_extent() -> float:
	var engage := GameData.const_f("PLAYER_NORMAL_ATK_RANGE", 150.0) * 0.8
	return maxf(min_spacing() - engage, 0.0)

func has_attack(attack_id: String) -> bool:
	for a in attacks:
		if a.id == attack_id:
			return true
	return false

## 距离某招式下次可释放的秒数（自动护盾AI用来给天坠预留金刚不坏）
func time_until(attack_id: String) -> float:
	return maxf(float(timers.get(attack_id, INF)), 0.0)

## 返回本首领所有 true_maxhp（真实伤害）类危险招式
func true_damage_attacks() -> Array[BossAttackDef]:
	var out: Array[BossAttackDef] = []
	for a in attacks:
		if a.is_danger and a.is_true_damage():
			out.append(a)
	return out

func step(delta: float) -> void:
	if not alive:
		return
	for k in timers:
		timers[k] = float(timers[k]) - delta
	busy_t = maxf(busy_t - delta, 0.0)
	super.step(delta)

func _behave(delta: float, p: Player) -> void:
	var dx := p.position.x - position.x
	var dist := absf(dx)
	if busy_t > 0.0:
		return
	facing = 1 if dx > 0 else -1
	# 1) 危险攻击：冷却好且场上没有其他预警
	if not battle.has_active_danger_telegraph():
		for a in attacks:
			if a.is_danger and float(timers[a.id]) <= 0.0:
				var warn := a.warn_s if a.warn_s > 0.0 else GameData.const_f("BOSS_WARN_TIME", 0.8)
				# 首领战剩余时间不够这一招结算（限时内放不完）就不再起手
				if battle.phase == Battle.Phase.BOSS and battle.boss_time_left <= warn:
					break
				if not danger_gap_ok(warn, delta):
					guard_delays += 1
					break   # 运行时间隔保护：推迟，计时器保持就绪，间隔够了立刻放
				timers[a.id] = a.cd_s
				busy_t = warn
				battle.start_boss_attack(self, a)
				return
	# 2) 普攻（无预警，近战接触）。站位距离至少 BOSS_MIN_SPACING_PX，普攻判定距离同步放宽到站位距离。
	var stop := stand_distance()
	for a in attacks:
		if not a.is_danger and float(timers[a.id]) <= 0.0 and dist <= stop + Player.HALF_WIDTH:
			if _strike_t >= 0.0:
				return   # 上一记普攻还在起手
			timers[a.id] = a.cd_s
			if dist <= maxf(a.width_px, stop) + Player.HALF_WIDTH:
				_strike_reach = maxf(a.width_px, stop)
				_begin_strike(a.damage_coef, false)   # 正式图集：普攻命中帧结算
			return
	# 3) 走位：靠近到站位距离；玩家贴得比最小间距还近时缓慢后退（不覆盖主角）
	if dist > stop:
		position.x += signf(dx) * minf(speed() * delta, dist - stop)
	elif dist < min_spacing() - 1.0 and stun_t <= 0.0:
		position.x -= signf(dx if dx != 0.0 else -1.0) * minf(speed() * delta, min_spacing() - dist)

## 危险技能出手动画：skill_*（前摇 4 帧共 0.8s，索引 4 出手）。按本招预警时长缩放，出手帧与预警结算同一时刻。
func play_skill(a: BossAttackDef) -> void:
	if anim == null:
		return
	var name := CreatureArt.skill_anim(a.id)
	if not anim.sprite_frames.has_animation(name):
		name = &"attack"
	_strike_t = -1.0
	_play_once(String(name))
	var warn := a.warn_s if a.warn_s > 0.0 else GameData.const_f("BOSS_WARN_TIME", 0.8)
	anim.speed_scale = CreatureArt.BOSS_SKILL_WINDUP_S / maxf(warn, 0.05)

## 死亡：播 death 并停在最后一帧（随后 battle 整体淡出）
func play_death() -> void:
	if anim and anim.sprite_frames.has_animation(&"death"):
		anim.speed_scale = 1.0
		anim.modulate = Color.WHITE
		anim.play(&"death")

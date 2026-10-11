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

## 新预警在起手的同一帧就开始计时，实际判定时刻 = 起手时刻 + warn − 本帧步长（按保守估计）
func danger_gap_ok(warn: float, delta: float = 0.0) -> bool:
	if battle.last_danger_resolve_t < 0.0:
		return true
	return battle.sim_time - delta + warn - battle.last_danger_resolve_t >= min_danger_gap() - 1e-6

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
	# 2) 普攻（无预警，近战接触）
	for a in attacks:
		if not a.is_danger and float(timers[a.id]) <= 0.0 and dist <= def.attack_range_px + Player.HALF_WIDTH:
			timers[a.id] = a.cd_s
			if dist <= a.width_px + Player.HALF_WIDTH:
				battle.enemy_contact_hit(self, atk * a.damage_coef)
			return
	# 3) 走位：靠近到普攻距离
	var stop := def.attack_range_px   # 首领体型大，停在普攻距离边缘，避免与主角重叠
	if dist > stop:
		position.x += signf(dx) * minf(speed() * delta, dist - stop)

extends TestCase
## 自动/手动切换、闪避免伤、伤害规则（防御、真实伤害、护盾、反伤、反震内置间隔）

func _battle() -> Battle:
	var b := make_battle()
	b.start_run(GameData.get_level("LV_1_1"), Battle.RunMode.CHALLENGE)
	return b

func test_move_input_switches_to_manual_and_stays() -> void:
	var b := _battle()
	check(PlayerState.auto_battle, "开局自动")
	b.controller.virtual_move = 1.0
	b.tick(DT)
	check(not PlayerState.auto_battle, "移动输入立即切手动")
	b.controller.virtual_move = 0.0
	sim(b, 3.0)
	check(not PlayerState.auto_battle, "停止输入后不自动恢复")
	b.controller.request_toggle_auto()
	b.tick(DT)
	check(PlayerState.auto_battle, "点开关恢复自动")
	free_battle(b)

func test_dodge_input_switches_to_manual() -> void:
	var b := _battle()
	b.controller.request_dodge()
	b.tick(DT)
	check(not PlayerState.auto_battle, "闪避输入（空格/闪避按钮）切到手动")
	check(b.player.is_dodging(), "闪避已执行")
	free_battle(b)

func test_manual_skill_keeps_auto_and_has_priority() -> void:
	var b := _battle()
	var e := spawn_dummy(b, "EN_BAMBOO_IMP", 120)
	e.max_hp = 1e9; e.hp = 1e9
	# 同一帧：手动按第2格（雷击）；自动AI本来会放第1格（飞剑）
	b.controller.request_skill(1)
	b.tick(DT)
	check(PlayerState.auto_battle, "手动释放技能不退出自动")
	eq(b.skills.cast_log.size(), 1, "本帧只释放了1个技能")
	if b.skills.cast_log.size() > 0:
		eq(b.skills.cast_log[0].slot, 1, "手动释放的格子优先")
		check(b.skills.cast_log[0].manual, "记录为手动释放")
	b.tick(DT)
	var auto_cast := false
	for c in b.skills.cast_log:
		if not c.manual:
			auto_cast = true
	check(auto_cast, "下一帧自动AI继续释放其他技能")
	free_battle(b)

func test_auto_moves_and_attacks() -> void:
	var b := _battle()
	var x0 := b.player.position.x
	sim(b, 1.0)
	check(b.player.position.x > x0, "自动模式向右推进")
	PlayerState.set_auto_battle(false)
	var x1 := b.player.position.x
	sim(b, 1.0)
	near(b.player.position.x, x1, 0.01, "手动模式无输入时不移动")
	free_battle(b)

func test_dodge_iframes_and_cooldown() -> void:
	var b := _battle()
	var e := spawn_dummy(b, "EN_BAMBOO_IMP", 50)
	check(b.player.dodge(), "闪避成功")
	eq(b.damage_player(100.0, e, true), 0.0, "闪避中免伤")
	sim(b, 0.2)
	eq(b.damage_player(100.0, e, true), 0.0, "0.2秒仍免伤")
	sim(b, 0.12)
	check(b.damage_player(100.0, e, true) > 0.0, "0.3秒后恢复受伤")
	check(not b.player.dodge(), "冷却中不能再次闪避")
	sim(b, GameData.const_f("DODGE_COOLDOWN") - 0.3)
	check(b.player.dodge(), "3秒冷却后可再次闪避")
	free_battle(b)

func test_defense_reduces_atk_damage() -> void:
	var b := _battle()
	var d := float(b.player.stats.def)
	var dmg := b.damage_player(100.0, null, false)
	near(dmg, 100.0 * (1.0 - d / (d + GameData.const_f("DEF_CONST", 100.0))), 0.01, "DEF/(DEF+100) 减伤")
	free_battle(b)

func test_true_damage_ignores_def_hits_shield_no_reflect() -> void:
	var b := _battle()
	b.player.stats["def"] = 500.0
	b.player.stats["reflect"] = 0.5
	var e := spawn_dummy(b, "EN_BAMBOO_IMP", 60)
	e.stun_t = 100.0
	b.controller.request_skill(2)   # 护体：护盾 + 反伤/反震
	b.tick(DT)
	var ehp := e.hp
	var shield := b.player.shield_total()
	check(shield > 0.0, "护体产生护盾")
	var hp0 := b.player.hp
	var raw := b.player.max_hp * 0.7
	var dmg := b.damage_player(raw, e, true, true)   # 即使标记为接触，真实伤害也不反伤
	near(dmg, raw, 0.01, "真实伤害无视防御")
	near(b.player.hp, hp0 - (raw - shield), 0.5, "先扣护盾再扣生命")
	near(b.player.shield_total(), 0.0, 0.01, "护盾被打空")
	near(e.hp, ehp, 0.01, "真实伤害不触发反伤/反震")
	eq(b.counter_hits, 0, "无反震")
	eq(b.reflect_hits, 0, "无反伤")
	free_battle(b)

func test_reflect_only_on_contact() -> void:
	var b := _battle()
	b.player.stats["reflect"] = 0.25
	var e := spawn_dummy(b, "EN_THUNDER_TOAD", 300)
	var hp0 := e.hp
	b.damage_player(100.0, e, false)
	near(e.hp, hp0, 0.01, "非接触伤害不反伤")
	b.damage_player(100.0, e, true)
	check(e.hp < hp0, "接触伤害反伤")
	eq(b.reflect_hits, 1, "反伤1次")
	b.player.stats["reflect"] = 5.0
	var hp1 := e.hp
	b.damage_player(100.0, e, true)
	var d := e.effective_def()
	near(hp1 - e.hp, maxf(100.0 * GameData.const_f("REFLECT_CAP") * (1.0 - d / (d + 100.0)), 1.0), 0.01, "反伤受 REFLECT_CAP 封顶")
	free_battle(b)

func test_guard_counter_icd() -> void:
	var b := _battle()
	var e := spawn_dummy(b, "EN_BAMBOO_IMP", 60)
	e.max_hp = 1e9; e.hp = 1e9
	e.stun_t = 100.0   # 不让它自己出手，只测手动触发的接触攻击
	PlayerState.set_auto_battle(false)
	b.controller.request_skill(2)
	b.tick(DT)
	check(b.player.has_shield_from("SK_GANG_GUARD"), "护体护盾存在")
	b.player.shields[0].amount = 1e9   # 保证护盾不破
	b.enemy_contact_hit(e, 10.0)
	eq(b.counter_hits, 1, "第一次接触触发反震")
	b.enemy_contact_hit(e, 10.0)
	eq(b.counter_hits, 1, "内置间隔内不再触发")
	check(b.reflect_hits >= 2, "护盾期间额外反伤每次都生效")
	sim(b, GameData.const_f("REFLECT_COUNTER_ICD") + 0.05)
	b.enemy_contact_hit(e, 10.0)
	eq(b.counter_hits, 2, "间隔过后再次触发")
	free_battle(b)

func test_pause_stops_battle() -> void:
	var b := make_battle()
	b.auto_tick = true
	b.start_run(GameData.get_level("LV_1_1"), Battle.RunMode.CHALLENGE)
	await runner.get_tree().physics_frame
	await runner.get_tree().physics_frame
	var t0 := b.sim_time
	check(t0 > 0.0, "未暂停时战斗时钟推进")
	runner.get_tree().paused = true
	for i in 10:
		await runner.get_tree().physics_frame
	b.tick(DT)
	near(b.sim_time, t0, 0.0001, "暂停期间战斗不推进（含手动tick）")
	runner.get_tree().paused = false
	for i in 5:
		await runner.get_tree().physics_frame
	check(b.sim_time > t0, "关闭面板后恢复")
	free_battle(b)

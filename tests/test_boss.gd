extends TestCase
## 首领预警、闪避判定、自动护盾AI、天坠情境引导

func _boss_battle(level_id: String) -> Battle:
	var b := make_battle()
	b.start_run(GameData.get_level(level_id), Battle.RunMode.CHALLENGE)
	b.debug_force_boss()
	return b

func _attack(id: String) -> BossAttackDef:
	return GameData.get_boss_attack(id)

func test_attacks_filtered_by_level_index() -> void:
	var b := _boss_battle("LV_3_1")
	check(not b.boss.has_attack("BA_YANMO_QUAKE"), "3-1 没有第3关起的地裂")
	check(not b.boss.has_attack("BA_YANMO_SKYFALL"), "3-1 没有第4关起的天坠")
	free_battle(b)
	b = _boss_battle("LV_3_4")
	check(b.boss.has_attack("BA_YANMO_QUAKE") and b.boss.has_attack("BA_YANMO_SKYFALL"), "3-4 有地裂和天坠")
	near(b.boss.time_until("BA_YANMO_SKYFALL"), _attack("BA_YANMO_SKYFALL").first_cast_s, 0.01, "天坠首次释放时间取自 first_cast_s")
	free_battle(b)

func test_telegraph_warns_before_damage() -> void:
	var b := _boss_battle("LV_1_1")
	b.player.stats["def"] = 0.0
	b.boss.stun_t = 100.0
	var a := _attack("BA_ZHUMEI_THORN")
	b.boss.facing = -1 if b.player.position.x < b.boss.position.x else 1
	b.player.position.x = b.boss.position.x + b.boss.facing * 200.0
	b.start_boss_attack(b.boss, a)
	check(b.has_active_danger_telegraph(), "预警出现")
	var hp0 := b.player.hp
	PlayerState.set_auto_battle(false)
	sim(b, GameData.const_f("BOSS_WARN_TIME") - 0.05)
	near(b.player.hp, hp0, 0.01, "预警期间不受伤")
	sim(b, 0.1)
	check(b.player.hp < hp0, "预警结束站在区域内受伤")
	check(not b.has_active_danger_telegraph(), "预警结束")
	free_battle(b)

func test_dodge_at_resolution_avoids_danger() -> void:
	var b := _boss_battle("LV_1_1")
	b.boss.stun_t = 100.0
	PlayerState.set_auto_battle(false)
	var a := _attack("BA_ZHUMEI_LEAF")
	b.player.position.x = b.boss.position.x - 100.0
	b.start_boss_attack(b.boss, a)
	var hp0 := b.player.hp
	sim(b, GameData.const_f("BOSS_WARN_TIME") - 0.15)
	b.controller.request_dodge()
	b.controller.virtual_move = 0.0
	sim(b, 0.2)
	near(b.player.hp, hp0, 0.01, "预警结束瞬间处于闪避免伤 → 无伤")
	free_battle(b)

func test_leaving_area_avoids_danger() -> void:
	var b := _boss_battle("LV_1_1")
	b.boss.stun_t = 100.0
	PlayerState.set_auto_battle(false)
	b.player.position.x = b.boss.position.x - 100.0
	b.start_boss_attack(b.boss, _attack("BA_ZHUMEI_LEAF"))
	var hp0 := b.player.hp
	b.controller.virtual_move = -1.0
	sim(b, GameData.const_f("BOSS_WARN_TIME") + 0.05)
	near(b.player.hp, hp0, 0.01, "走出圆形区域 → 无伤")
	free_battle(b)

func test_only_one_danger_telegraph_at_a_time() -> void:
	var b := _boss_battle("LV_1_5")
	b.player.god_mode = true
	var max_tg := 0
	var distinct_overlap := false
	for i in int(40.0 / DT):
		b.tick(DT)
		var ids := {}
		for tg in b.telegraphs:
			ids[tg.attack.id] = true
		max_tg = maxi(max_tg, ids.size())
		if b.phase != Battle.Phase.BOSS:
			break
	eq(max_tg, 1, "同一时刻最多1种危险攻击在预警")
	free_battle(b)

func test_skyfall_true_damage_through_shield() -> void:
	PlayerState.set_tutorial_state("TUT_07_SKYFALL_DODGE", {"shown": 3, "done": true})   # 排除引导慢放
	var b := _boss_battle("LV_3_4")
	b.boss.stun_t = 100.0
	PlayerState.set_auto_battle(false)
	b.player.stats["def"] = 1000.0
	b.player.add_shield({"skill_id": "TEST", "amount": 100.0, "max": 100.0, "time": 10.0})
	var hp0 := b.player.hp
	b.start_boss_attack(b.boss, _attack("BA_YANMO_SKYFALL"))
	b.player.position.x -= 2000.0   # 全场预警：走位无法躲开
	b.left_bound = -INF
	sim(b, GameData.const_f("BOSS_WARN_TIME") + 0.05)
	var expected := b.player.max_hp * _attack("BA_YANMO_SKYFALL").damage_maxhp_pct - 100.0
	near(hp0 - b.player.hp, expected, 1.0, "天坠：最大生命×比例真实伤害，护盾先吸收，无视防御")
	free_battle(b)

func test_auto_shield_ai() -> void:
	PlayerState.learn_skill_debug("SK_GANG_VAJRA")
	PlayerState.equip_skill(3, "SK_GANG_VAJRA")
	var b := _boss_battle("LV_3_4")
	b.boss.stun_t = 100.0
	var vajra := GameData.get_skill("SK_GANG_VAJRA")
	var guard := GameData.get_skill("SK_GANG_GUARD")
	var cd := b.skills.cooldown_for(vajra)
	check(cd >= GameData.const_f("AUTO_SHIELD_RESERVE_CD", 12.0), "金刚不坏属于长冷却护盾")
	check(b.controller.wants_auto_cast(guard), "护体：交战中按冷却释放")
	b.boss.timers["BA_YANMO_SKYFALL"] = cd - 3.0
	check(not b.controller.wants_auto_cast(vajra), "下次天坠前冷却不好 → 预留不放")
	b.boss.timers["BA_YANMO_SKYFALL"] = cd + 5.0
	check(b.controller.wants_auto_cast(vajra), "冷却好之前不会撞上天坠 → 可以放")
	b.boss.timers["BA_YANMO_SKYFALL"] = cd - 3.0
	b.start_boss_attack(b.boss, _attack("BA_YANMO_SKYFALL"))
	check(b.controller.wants_auto_cast(vajra), "天坠预警期间可用 → 立刻放")
	free_battle(b)

func test_auto_shield_cast_during_skyfall_integration() -> void:
	PlayerState.set_tutorial_state("TUT_07_SKYFALL_DODGE", {"shown": 3, "done": true})
	PlayerState.learn_skill_debug("SK_GANG_VAJRA")
	PlayerState.equip_skill(3, "SK_GANG_VAJRA")
	var b := _boss_battle("LV_3_4")
	b.player.god_mode = true
	var sky_t := -1.0
	var vajra_t := -1.0
	# v5：天坠首放 20 秒（> 金刚不坏冷却），开局先放一次，冷却好后为天坠预留；检查预警期间有一次释放
	for i in int(30.0 / DT):
		b.tick(DT)
		if sky_t < 0.0 and b.is_true_damage_telegraph_active():
			sky_t = b.sim_time
		if sky_t > 0.0 and b.sim_time > sky_t + 1.0:
			break
	for c in b.skills.cast_log:
		if c.skill_id == "SK_GANG_VAJRA" and sky_t > 0.0 and c.t >= sky_t and c.t <= sky_t + GameData.const_f("BOSS_WARN_TIME", 0.8):
			vajra_t = c.t
	check(sky_t > 0.0, "天坠出现")
	check(vajra_t >= sky_t and vajra_t <= sky_t + GameData.const_f("BOSS_WARN_TIME"), "金刚不坏在天坠预警期间释放 (sky=%.2f vajra=%.2f)" % [sky_t, vajra_t])
	near(sky_t, 20.0, 0.1, "v5 天坠首放 20 秒（first_cast_s 来自表）")
	free_battle(b)

func test_skyfall_tutorial_slowmo_and_completion() -> void:
	var b := _boss_battle("LV_3_4")
	b.boss.stun_t = 100.0
	var shown := []
	b.tutorial.hint_shown.connect(func(id: String, text: String) -> void: shown.append([id, text]))
	PlayerState.set_auto_battle(false)
	b.start_boss_attack(b.boss, _attack("BA_YANMO_SKYFALL"))
	eq(shown.size(), 1, "首次天坠预警触发情境引导")
	if shown.size() > 0:
		eq(shown[0][0], "TUT_07_SKYFALL_DODGE", "步骤ID")
		eq(shown[0][1], "按空格闪避！", "提示文案取自表")
	near(b.time_scale, 0.3, 0.001, "慢放0.3倍")
	# 慢放期间输入照常响应：闪避
	var t_game := b.sim_time
	sim(b, 0.75 / 0.3 * 0.9)    # 现实时间约0.675×2.5，游戏时间≈0.675
	b.controller.request_dodge()
	sim(b, 1.0)
	check(PlayerState.tutorial_state("TUT_07_SKYFALL_DODGE").get("done", false), "预警结束时处于闪避 → 完成")
	near(b.time_scale, 1.0, 0.001, "慢放结束")
	check(b.sim_time - t_game > 0.8, "游戏时钟仍在推进")
	free_battle(b)

func test_skyfall_tutorial_max_show_count() -> void:
	PlayerState.reset_new_game()
	var b := _boss_battle("LV_3_4")
	b.boss.stun_t = 100.0
	b.player.god_mode = false
	PlayerState.set_auto_battle(false)
	var max_show := 0
	for r in GameData.tables.tutorial_steps:
		if CsvUtil.s(r, "step_id") == "TUT_07_SKYFALL_DODGE":
			max_show = CsvUtil.i(r, "max_show_count")
	for i in max_show:
		b.player.hp = b.player.max_hp
		b.start_boss_attack(b.boss, _attack("BA_YANMO_SKYFALL"))
		sim(b, 4.0)
		var st := PlayerState.tutorial_state("TUT_07_SKYFALL_DODGE")
		eq(int(st.shown), i + 1, "第%d次提示" % (i + 1))
		eq(bool(st.done), i + 1 >= max_show, "未闪避则不完成，达到次数自动完成")
	b.player.hp = b.player.max_hp
	b.start_boss_attack(b.boss, _attack("BA_YANMO_SKYFALL"))
	eq(int(PlayerState.tutorial_state("TUT_07_SKYFALL_DODGE").shown), max_show, "完成后不再提示")
	near(b.time_scale, 1.0, 0.001, "完成后不再慢放")
	free_battle(b)

func test_skyfall_hint_auto_subtext_from_table() -> void:
	var row: Dictionary = {}
	for r in GameData.tables["tutorial_steps"]:
		if CsvUtil.s(r, "step_id") == "TUT_07_SKYFALL_DODGE":
			row = r
	var sub := TutorialService.auto_subtext(row)
	check(sub != "" and CsvUtil.s(row, "ui_target").contains(sub), "自动模式小字取自 ui_target（%s）" % sub)
	check(sub.contains("Q"), "v4 文案含“按 Q 恢复”")

extends TestCase
## 4格技能栏：装配规则、独立自动设置、冷却

func test_default_bar() -> void:
	var basics := GameData.basic_skill_ids()
	for i in basics.size():
		eq(PlayerState.active_slots[i], basics[i], "第%d格为基础技能" % (i + 1))
		check(PlayerState.slot_auto[i], "基础技能默认自动")
	eq(PlayerState.active_slots[3], "", "第4格为空")

func test_equip_rules() -> void:
	check(not PlayerState.equip_skill(3, "SK_SWORD_FLYING"), "同一技能不能重复占槽")
	check(not PlayerState.equip_skill(3, "SK_SWORD_COMBO"), "未学技能不能装配")
	PlayerState.learn_skill_debug("SK_SWORD_PASSIVE")
	check(not PlayerState.equip_skill(3, "SK_SWORD_PASSIVE"), "被动技能不能进主动栏")
	check(PlayerState.equip_passive("SK_SWORD_PASSIVE"), "被动技能进被动槽")
	PlayerState.learn_skill_debug("SK_THUNDER_PALM")
	check(PlayerState.equip_skill(3, "SK_THUNDER_PALM"), "跨功法混搭可装配")
	check(PlayerState.equip_skill(0, "SK_SWORD_FLYING"), "同格重装自身允许")
	check(not PlayerState.equip_skill(5, "SK_SWORD_FLYING"), "越界格子拒绝")

func test_independent_auto_flags() -> void:
	PlayerState.set_slot_auto(1, false)
	check(PlayerState.slot_auto[0] and not PlayerState.slot_auto[1] and PlayerState.slot_auto[2], "每格独立设置")
	var b := make_battle()
	b.start_run(GameData.get_level("LV_1_1"), Battle.RunMode.CHALLENGE)
	spawn_dummy(b, "EN_BAMBOO_IMP", 120)
	sim(b, 4.0)
	var slots_cast := {}
	for c in b.skills.cast_log:
		if not c.manual:
			slots_cast[c.slot] = true
	check(not slots_cast.has(1), "关闭自动的格子不被自动释放")
	check(slots_cast.has(0), "开启自动的格子会被自动释放")
	free_battle(b)

func test_cooldown_ignore_and_no_queue() -> void:
	var b := make_battle()
	b.start_run(GameData.get_level("LV_1_1"), Battle.RunMode.CHALLENGE)
	PlayerState.set_auto_battle(false)
	var e := spawn_dummy(b, "EN_BAMBOO_IMP", 300)
	e.max_hp = 1e9; e.hp = 1e9
	b.controller.request_skill(0)
	b.tick(DT)
	eq(b.skills.cast_log.size(), 1, "第一次释放成功")
	var cd := b.skills.cds[0]
	near(cd, GameData.get_skill("SK_SWORD_FLYING").level_def(1).cd_s, 0.02, "冷却=表中1级cd")
	b.controller.request_skill(0)
	b.tick(DT)
	eq(b.skills.cast_log.size(), 1, "冷却中按键被忽略")
	sim(b, cd + 0.5)
	eq(b.skills.cast_log.size(), 1, "冷却结束后不会自动补放（不排队）")
	b.controller.request_skill(0)
	b.tick(DT)
	eq(b.skills.cast_log.size(), 2, "冷却结束后再按可释放")
	b.controller.request_skill(3)
	b.tick(DT)
	eq(b.skills.cast_log.size(), 2, "空槽释放无效")
	free_battle(b)

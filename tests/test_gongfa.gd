extends TestCase
## 阶段3：功法 / 技能书 / 学习 / 升级 / 装配 / 残页分解与兑换 / 书池掉落

func _skill_level_row(skill_id: String, lv: int) -> Dictionary:
	for r in GameData.tables["skill_levels"]:
		if CsvUtil.s(r, "skill_id") == skill_id and CsvUtil.i(r, "level") == lv:
			return r
	return {}

func test_new_game_books_from_tutorial_learned_and_equipped() -> void:
	for sid in GameData.basic_skill_ids():
		eq(PlayerState.skill_level(sid), 1, "基础技能 %s 已学（引导赠书→学习）" % sid)
		var bk := GameData.get_book(GameData.get_skill(sid).book_id)
		eq(PlayerState.book_count(bk.id), 0, "赠书学习后已消耗")
	eq(PlayerState.active_slots[3], "", "第4格空")
	check(PlayerState.gongfa_entered("GF_SWORD") and PlayerState.gongfa_entered("GF_THUNDER") and PlayerState.gongfa_entered("GF_GANG"), "三功法均已入门")

func test_learn_consumes_one_book_duplicate_does_not() -> void:
	eq(PlayerState.learn_book("BK_SWORD_COMBO"), "no_book", "无书不能学")
	PlayerState.add_book("BK_SWORD_COMBO", 2)
	eq(PlayerState.learn_book("BK_SWORD_COMBO"), "ok", "学习成功")
	eq(PlayerState.skill_level("SK_SWORD_COMBO"), 1, "学会后1级")
	eq(PlayerState.book_count("BK_SWORD_COMBO"), 1, "消耗1本")
	eq(PlayerState.learn_book("BK_SWORD_COMBO"), "already_learned", "重复学习被拒绝")
	eq(PlayerState.book_count("BK_SWORD_COMBO"), 1, "重复点击不扣书")

func test_upgrade_cost_from_skill_levels_table() -> void:
	var sid := "SK_SWORD_FLYING"
	var cost := CsvUtil.i(_skill_level_row(sid, 1), "upgrade_cost_lingshi")
	check(cost > 0, "表中1→2级费用>0")
	eq(PlayerState.upgrade_cost(sid), cost, "升级费用读 skill_levels（当前级）")
	PlayerState.lingshi = cost - 1
	eq(PlayerState.upgrade_skill(sid), "no_lingshi", "灵石不足")
	eq(PlayerState.skill_level(sid), 1, "未升级")
	PlayerState.lingshi = cost + 5
	eq(PlayerState.upgrade_skill(sid), "ok", "升级成功")
	eq(PlayerState.skill_level(sid), 2, "升到2级")
	eq(PlayerState.lingshi, 5, "扣除对应灵石")
	PlayerState.learn_skill_debug(sid, GameData.const_i("SKILL_MAX_LEVEL"))
	PlayerState.lingshi = 10000000
	eq(PlayerState.upgrade_skill(sid), "max_level", "满级不能再升")
	eq(PlayerState.upgrade_skill("SK_SWORD_EXECUTE"), "not_learned", "未学不能升")

func test_upgrade_changes_battle_values() -> void:
	var s := GameData.get_skill("SK_SWORD_FLYING")
	var b := make_battle()
	b.start_run(GameData.get_level("LV_1_1"), Battle.RunMode.CHALLENGE)
	var cd1 := b.skills.cooldown_for(s)
	PlayerState.lingshi = 100000
	PlayerState.upgrade_skill(s.id)
	PlayerState.upgrade_skill(s.id)
	var cd3 := b.skills.cooldown_for(s)
	near(cd3, s.level_def(3).cd_s * cd1 / s.level_def(1).cd_s, 0.001, "冷却按 skill_levels 第3级")
	free_battle(b)

func test_upgrade_clears_unstable_marks() -> void:
	PlayerState.mark_cleared("LV_1_1")
	PlayerState.record_auto_failure("LV_1_2")
	check(PlayerState.is_unstable("LV_1_2"), "已标记")
	PlayerState.lingshi = 100000
	PlayerState.upgrade_skill("SK_THUNDER_STRIKE")
	check(PlayerState.unstable_levels.is_empty(), "技能升级清除标记（skill_level_up）")

func test_decompose_duplicate_books_to_pages() -> void:
	var bk := GameData.get_book("BK_SWORD_FLYING")
	PlayerState.add_book("BK_SWORD_PIERCE", 1)
	eq(PlayerState.decompose_book("BK_SWORD_PIERCE"), "not_learned", "未学技能的书不能分解")
	PlayerState.add_book(bk.id, 3)
	eq(PlayerState.decompose_book(bk.id, 2), "ok", "分解重复书")
	eq(PlayerState.item_count("MAT_PAGE"), bk.decompose_pages * 2, "得到 decompose_pages×数量 残页")
	eq(PlayerState.book_count(bk.id), 1, "剩1本")
	eq(PlayerState.decompose_book(bk.id, 5), "no_book", "数量不足")

func test_page_exchange_with_region_lock() -> void:
	var qz := GameData.get_book("BK_SWORD_PIERCE")       # 青竹山
	var lz := GameData.get_book("BK_THUNDER_CLOUD")      # 雷泽谷
	eq(qz.region_map_id, "MAP_QINGZHU", "表：破甲剑书属于青竹山")
	eq(lz.region_map_id, "MAP_LEIZE", "表：雷云书属于雷泽谷")
	PlayerState.add_item("MAT_PAGE", qz.exchange_pages - 1)
	eq(PlayerState.exchange_book(qz.id), "no_pages", "残页不足")
	PlayerState.add_item("MAT_PAGE", 1)
	eq(PlayerState.exchange_book(qz.id), "ok", "兑换成功")
	eq(PlayerState.book_count(qz.id), 1, "得到1本")
	eq(PlayerState.item_count("MAT_PAGE"), 0, "扣除 exchange_pages")
	PlayerState.add_item("MAT_PAGE", 50)
	eq(PlayerState.exchange_book(lz.id), "locked_region", "未解锁区域不能兑换")
	PlayerState.set_realm(GameData.get_map("MAP_LEIZE").realm_required)
	eq(PlayerState.exchange_book(lz.id), "ok", "突破后可兑换雷泽谷书")

func test_learned_book_skill_equips_and_casts() -> void:
	PlayerState.add_book("BK_SWORD_COMBO", 1)
	PlayerState.learn_book("BK_SWORD_COMBO")
	check(PlayerState.place_skill(3, "SK_SWORD_COMBO"), "装到第4格")
	eq(PlayerState.active_slots[3], "SK_SWORD_COMBO", "第4格")
	check(PlayerState.place_skill(0, "SK_SWORD_COMBO"), "移到第1格（互换）")
	eq(PlayerState.active_slots[0], "SK_SWORD_COMBO", "第1格=连环剑")
	eq(PlayerState.active_slots[3], "SK_SWORD_FLYING", "原第1格技能换到第4格")
	check(not PlayerState.place_skill(1, "SK_SWORD_EXECUTE"), "未学不能装")
	check(not PlayerState.equip_skill(1, "SK_SWORD_PASSIVE"), "被动不能进主动栏")
	var b := make_battle()
	b.start_run(GameData.get_level("LV_1_1"), Battle.RunMode.CHALLENGE)
	PlayerState.set_auto_battle(false)
	var e := spawn_dummy(b, "EN_BAMBOO_IMP", 200)
	e.stun_t = 100.0
	b.controller.request_skill(0)
	b.tick(DT)
	check(b.skills.cast_log.size() > 0 and b.skills.cast_log[-1].skill_id == "SK_SWORD_COMBO", "新学技能可释放")
	free_battle(b)

func test_passive_learn_and_set() -> void:
	PlayerState.add_book("BK_SWORD_PASSIVE", 1)
	PlayerState.learn_book("BK_SWORD_PASSIVE")
	check(PlayerState.equip_passive("SK_SWORD_PASSIVE"), "设为被动")
	var lv := GameData.get_skill("SK_SWORD_PASSIVE").level_def(1)
	var s := GameData.get_skill("SK_SWORD_PASSIVE")
	var st := PlayerState.combat_stats()
	eq(s.effect2_type, "extra_sword_chance", "表：剑心通明 effect2=追加飞剑")
	near(float(st.extra_sword_chance), lv.effect2_value, 0.0001, "被动 effect2 进入属性")

func test_book_pool_weights() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 99
	var pool: Array = GameData.book_pools["BP_T1"]
	var total := 0.0
	for e in pool:
		total += float(e.weight)
	var counts := {}
	var n := 8000
	for i in n:
		var bid := LootSystem.roll_book("BP_T1", rng)
		counts[bid] = int(counts.get(bid, 0)) + 1
	for e in pool:
		near(float(counts.get(e.book_id, 0)) / n, float(e.weight) / total, 0.025, "书池权重 %s" % e.book_id)
	eq(counts.size(), pool.size(), "只出书池内的书")

func test_boss_drop_table_includes_book_pool() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var lv := GameData.get_level("LV_1_1")
	var books := 0
	var n := 3000
	var chance := 0.0
	for r in GameData.drop_tables[lv.boss_drop_table_id]:
		if CsvUtil.s(r, "entry_type") == "book_pool":
			chance = CsvUtil.f(r, "chance")
	check(chance > 0.0, "首领掉落表含书池行")
	for i in n:
		for g in LootSystem.roll_kill(lv, true, rng):
			if g.type == "book":
				books += 1
	near(float(books) / n, chance, 0.025, "首领掉书概率 = 表中 chance")

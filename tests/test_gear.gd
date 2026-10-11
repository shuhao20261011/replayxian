extends TestCase
## 阶段4：装备生成（底子/档位/品质/权重/词条）、换装、分解、重铸、背包溢出、自动分解、掉落表、首通、存档

func _rng(s: int = 42) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = s
	return r

func _item(base_id: String, q: String, affixes: Array = []) -> GearItem:
	var g := GearItem.new()
	g.base_id = base_id; g.quality_id = q
	for a in affixes:
		g.affixes.append({"affix_id": a[0], "value": float(a[1])})
	return g

func test_quality_weight_distribution() -> void:
	var rng := _rng()
	for set_id in ["QW_NORMAL_T1", "QW_BOSS_T3"]:
		var w: Dictionary = GameData.quality_weights[set_id]
		var total := 0.0
		for q in w:
			total += float(w[q])
		var counts := {}
		var n := 20000
		for i in n:
			var q := GearSystem.roll_quality(set_id, rng)
			counts[q] = int(counts.get(q, 0)) + 1
		for q in w:
			near(float(counts.get(q, 0)) / n, float(w[q]) / total, 0.015, "%s 中 %s 的比例" % [set_id, q])

func test_generated_items_follow_tables() -> void:
	var rng := _rng(7)
	var oranges := 0
	for i in 600:
		var tier := 1 + i % 3
		var g := GearSystem.generate(tier, "QW_BOSS_T%d" % tier, rng)
		check(g != null and g.base() != null, "生成成功")
		var q := g.quality()
		eq(g.affixes.size(), q.affix_count, "词条数=qualities.affix_count (%s)" % q.id)
		if GearSystem.is_top_quality(q.id):
			oranges += 1
			check(g.base().is_core, "橙装只从核心底子出")
		else:
			check(not g.base().is_core, "非橙不出核心底子")
			eq(g.tier(), tier, "底子档位=掉落档位")
		var seen := {}
		for a in g.affixes:
			var af := GameData.affixes[a.affix_id] as AffixDef
			check(not seen.has(af.id), "同件不重复词条")
			seen[af.id] = true
			check(af.allowed_slots.has(g.slot_id()), "%s 允许 %s" % [af.id, g.slot_id()])
			check(GameData.get_quality(af.min_quality).order <= q.order, "%s 品质达标" % af.id)
			var rg := af.range_for(q.id)
			var mult := GameData.get_tier(g.tier()).flat_mult if af.scale_by_tier and af.value_type == "flat" else 1.0
			check(a.value >= floorf(rg.x * mult) - 0.001 and a.value <= ceilf(rg.y * mult) + 0.001, "%s 数值 %s 在区间 %s×%s 内" % [af.id, a.value, rg, mult])
	check(oranges > 0, "首领T3权重组能出橙装")

func test_fixed_slot_generation() -> void:
	var rng := _rng(3)
	for i in 50:
		var g := GearSystem.generate(1, "QW_FIRST_BLUE", rng, "SLOT_WEAPON")
		eq(g.slot_id(), "SLOT_WEAPON", "指定槽位")
		check(g.quality().order >= GameData.get_quality("Q_BLUE").order, "首通保底蓝装以上")

func test_stats_aggregate_base_quality_affixes() -> void:
	var base := GameData.get_base("EQB_WEAPON_T1")
	var st0 := PlayerState.combat_stats()
	var old: GearItem = PlayerState.equipped["SLOT_WEAPON"]
	var g := _item("EQB_WEAPON_T1", "Q_PURPLE", [["AF_ATK_FLAT", 10], ["AF_ATK_PCT", 0.1], ["AF_CRIT_DMG", 0.2]])
	PlayerState.add_gear(g)
	PlayerState.equip_gear(g.uid)
	var st := PlayerState.combat_stats()
	var rl := GameData.get_realm(PlayerState.realm_id)
	var expect_atk := 0.0
	for eqg: GearItem in PlayerState.equipped.values():
		expect_atk += float(eqg.base_stats().atk)
	expect_atk += 10.0
	near(float(st.atk), (rl.atk + expect_atk) * 1.1, 0.01, "攻击=(境界+底子×品质+词条)×(1+攻击%)")
	near(float(g.base_stats().atk), base.atk * GameData.get_quality("Q_PURPLE").base_mult, 0.001, "底子×品质倍率")
	near(float(st.crit_dmg), float(st0.crit_dmg) + 0.2, 0.0001, "暴伤词条")
	check(PlayerState.bag.has(old), "旧武器回到背包")

func test_equip_swap_clears_unstable_marks() -> void:
	PlayerState.mark_cleared("LV_1_1")
	PlayerState.record_auto_failure("LV_1_2")
	check(PlayerState.is_unstable("LV_1_2"), "已标记")
	var g := GearSystem.make_item("EQB_ROBE_T1", "Q_GREEN", _rng())
	PlayerState.add_gear(g)
	check(PlayerState.is_unstable("LV_1_2"), "入包不清除")
	eq(PlayerState.equip_gear(g.uid), "ok", "换装")
	check(PlayerState.unstable_levels.is_empty(), "换装清除标记（loadout_change）")
	eq(PlayerState.equipped["SLOT_ROBE"], g, "已装备")
	eq(PlayerState.decompose_gear(g.uid), "not_in_bag", "已装备的不能直接分解")

func test_decompose_value_from_tables() -> void:
	for tier in [1, 2, 3]:
		var bases := GearSystem.normal_bases(tier)
		var g := GearSystem.make_item(bases[0].id, "Q_BLUE", _rng())
		PlayerState.add_gear(g)
		var before := PlayerState.item_count("MAT_REFINE")
		eq(PlayerState.decompose_gear(g.uid), "ok", "分解")
		var expect := int(round(GameData.get_quality("Q_BLUE").decompose_refine * GameData.get_tier(tier).decompose_mult))
		eq(PlayerState.item_count("MAT_REFINE") - before, expect, "第%d档蓝装分解= decompose_refine×decompose_mult" % tier)

func test_batch_decompose_keeps_orange() -> void:
	var rng := _rng()
	PlayerState.add_gear(GearSystem.make_item("EQB_WEAPON_T1", "Q_WHITE", rng))
	PlayerState.add_gear(GearSystem.make_item("EQB_WEAPON_T1", "Q_GREEN", rng))
	PlayerState.add_gear(GearSystem.make_item("EQB_WEAPON_T1", "Q_PURPLE", rng))
	PlayerState.add_gear(GearSystem.make_item("EQB_CORE_SWORD", "Q_ORANGE", rng))
	eq(PlayerState.decompose_up_to(GameData.get_quality("Q_GREEN").order), 2, "分解白/绿")
	eq(PlayerState.bag.size(), 2, "紫、橙保留")
	eq(PlayerState.decompose_up_to(99), 1, "批量分解不含橙装")

func test_reroll_rules_and_cost() -> void:
	var rng := _rng(11)
	var g := GearSystem.make_item("EQB_WEAPON_T2", "Q_PURPLE", rng)
	PlayerState.add_gear(g)
	var cost := GearSystem.reroll_cost(g)
	var q := GameData.get_quality("Q_PURPLE")
	eq(int(cost.refine), q.reroll_refine, "材料=reroll_refine")
	eq(int(cost.lingshi), int(round(q.reroll_lingshi * GameData.get_tier(2).reroll_lingshi_mult)), "灵石=reroll_lingshi×档位倍率")
	eq(PlayerState.reroll_affix(g.uid, 0), "no_refine", "材料不足")
	PlayerState.add_item("MAT_REFINE", int(cost.refine) * 30)
	PlayerState.lingshi = int(cost.lingshi) * 30
	for i in 25:
		var others := [g.affixes[1].affix_id, g.affixes[2].affix_id]
		eq(PlayerState.reroll_affix(g.uid, 0), "ok", "重铸成功")
		check(not others.has(g.affixes[0].affix_id), "不与其余词条重复")
		var af := GameData.affixes[g.affixes[0].affix_id] as AffixDef
		check(af.allowed_slots.has("SLOT_WEAPON"), "重铸结果槽位允许")
	eq(PlayerState.item_count("MAT_REFINE"), int(cost.refine) * 5, "每次扣材料")
	eq(PlayerState.lingshi, int(cost.lingshi) * 5, "每次扣灵石")
	var w := GearSystem.make_item("EQB_WEAPON_T1", "Q_WHITE", rng)
	PlayerState.add_gear(w)
	eq(PlayerState.reroll_affix(w.uid, 0), "invalid_index", "白装无词条")
	check(GearSystem.reroll_cost(w).is_empty(), "白装不可重铸")

func test_reroll_equipped_clears_marks_and_keeps_orange_effect() -> void:
	var g := GearSystem.make_item("EQB_CORE_SWORD", "Q_ORANGE", _rng())
	PlayerState.add_gear(g)
	PlayerState.equip_gear(g.uid)
	PlayerState.mark_cleared("LV_1_1")
	PlayerState.record_auto_failure("LV_1_2")
	PlayerState.add_item("MAT_REFINE", 999); PlayerState.lingshi = 999999
	eq(PlayerState.reroll_affix(g.uid, 1), "ok", "重铸已装备的橙装")
	check(PlayerState.unstable_levels.is_empty(), "重铸已装备装备清除标记")
	eq(g.orange_effect().id, "OE_SWORD_CORE", "核心特效不变")
	eq(g.affixes.size(), GameData.get_quality("Q_ORANGE").affix_count, "橙装4条词条")

func test_bag_overflow_and_auto_decompose() -> void:
	var rng := _rng()
	var cap := PlayerState.bag_capacity()
	for i in cap:
		PlayerState.bag.append(GearSystem.make_item("EQB_WEAPON_T1", "Q_WHITE", rng))
	var before := PlayerState.item_count("MAT_REFINE")
	var g := GearSystem.make_item("EQB_WEAPON_T1", "Q_BLUE", rng)
	eq(PlayerState.add_gear(g), "overflow", "背包满溢出")
	eq(PlayerState.bag.size(), cap, "不超容量")
	eq(PlayerState.item_count("MAT_REFINE") - before, GearSystem.decompose_value(g), "溢出按分解值转材料")
	var o := GearSystem.make_item("EQB_CORE_GANG", "Q_ORANGE", rng)
	eq(PlayerState.add_gear(o), "ok", "橙装不会被溢出销毁")
	PlayerState.bag.clear()
	check(PlayerState.set_auto_decompose("Q_GREEN", true), "开启绿装自动分解")
	check(not PlayerState.set_auto_decompose("Q_ORANGE", true), "橙装不能自动分解")
	eq(PlayerState.add_gear(GearSystem.make_item("EQB_WEAPON_T1", "Q_GREEN", rng)), "auto_decomposed", "绿装自动分解")
	eq(PlayerState.add_gear(GearSystem.make_item("EQB_WEAPON_T1", "Q_BLUE", rng)), "ok", "蓝装入包")
	eq(PlayerState.bag.size(), 1, "只有蓝装入包")

func test_drop_tables_per_kill() -> void:
	var rng := _rng(21)
	var lv := GameData.get_level("LV_2_1")
	var eq_count := 0
	for i in 200:
		for gr in LootSystem.roll_kill(lv, true, rng):
			if gr.type == "equipment":
				eq_count += 1
				if not gr.item.base().is_core:
					eq(gr.item.tier(), 2, "雷泽谷首领掉第2档")
	check(eq_count >= 200, "首领 chance=1.0 保证掉装备")
	var normal_eq := 0
	var n := 5000
	for i in n:
		for gr in LootSystem.roll_kill(lv, false, rng):
			if gr.type == "equipment":
				normal_eq += 1
	var chance := 0.0
	for r in GameData.drop_tables[lv.normal_drop_table_id]:
		if CsvUtil.s(r, "entry_type") == "equipment":
			chance = CsvUtil.f(r, "chance")
	near(float(normal_eq) / n, chance, 0.012, "普通怪掉装概率=表 chance")

func test_first_clear_rewards() -> void:
	var rng := _rng(8)
	var l11 := GameData.get_level("LV_1_1")
	var gr := LootSystem.roll_first_clear(l11, rng)
	var types := gr.map(func(x: Dictionary) -> String: return x.type)
	check(types.has("lingshi") and types.has("xiuwei") and types.has("equipment"), "1-1 首通含灵石/修为/装备")
	for x in gr:
		if x.type == "equipment":
			eq(x.item.slot_id(), "SLOT_WEAPON", "1-1 首通固定武器")
			check(x.item.quality().order >= GameData.get_quality("Q_BLUE").order, "蓝装以上")
	var ls0 := PlayerState.lingshi
	LootSystem.apply(gr)
	check(PlayerState.lingshi > ls0, "灵石到账")
	check(PlayerState.bag.size() == 1, "装备入包")
	# 1-2 首通保底书
	var g12 := LootSystem.roll_first_clear(GameData.get_level("LV_1_2"), rng)
	LootSystem.apply(g12)
	eq(PlayerState.book_count("BK_SWORD_COMBO"), 1, "1-2 首通给连环剑书")
	# 终关三选一
	var g35 := LootSystem.roll_first_clear(GameData.get_level("LV_3_5"), rng)
	var oc: Array = g35.filter(func(x: Dictionary) -> bool: return x.type == "orange_choice")
	eq(oc.size(), 1, "三行 orange_choice 合并为一组")
	eq((oc[0].choices as Array).size(), 3, "三选一")
	LootSystem.apply(g35)
	eq(PlayerState.pending_orange_choices.size(), 1, "待领取")
	eq(PlayerState.choose_orange(0, "EQB_WEAPON_T1"), "invalid", "只能选组内")
	eq(PlayerState.choose_orange(0, "EQB_CORE_THUNDER"), "ok", "选择雷核")
	var core: GearItem = null
	for g in PlayerState.bag:
		if g.base_id == "EQB_CORE_THUNDER":
			core = g
	check(core != null and core.quality_id == "Q_ORANGE" and core.affixes.size() == 4, "得到橙色雷核，4条词条")
	eq(PlayerState.pending_orange_choices.size(), 0, "已领取")

func test_battle_kill_drops_and_first_clear_once() -> void:
	var b := make_battle(77)
	b.start_run(GameData.get_level("LV_1_1"), Battle.RunMode.CHALLENGE)
	b.debug_force_boss()
	b.boss.hp = 1.0
	b.player_hit_enemy(b.boss, 100.0, {"can_crit": false})
	sim(b, 0.1)
	check(PlayerState.is_cleared("LV_1_1"), "通关")
	check(PlayerState.bag.size() >= 2, "首领保底装备 + 首通装备入包（got %d）" % PlayerState.bag.size())
	var n := PlayerState.bag.size()
	check(not b.last_loot.is_empty(), "掉落条目用于显示光柱/提示")
	sim(b, GameData.const_f("RESULT_SHOW_TIME") + 0.2)
	b.debug_force_boss()
	b.boss.hp = 1.0
	b.player_hit_enemy(b.boss, 100.0, {"can_crit": false})
	sim(b, 0.1)
	check(PlayerState.bag.size() >= n + 1 and PlayerState.bag.size() <= n + 1, "再次击杀只有首领掉落，无首通奖励")
	free_battle(b)

func test_save_roundtrip_inventory() -> void:
	PlayerState.debug_fill_demo(3)
	var d := PlayerState.to_dict()
	var json := JSON.stringify(d)
	PlayerState.reset_new_game()
	PlayerState.from_dict(JSON.parse_string(json))
	var d2 := PlayerState.to_dict()
	eq(JSON.stringify(d2), json, "存档往返一致（背包/已装备/书/材料/三选一）")
	check(PlayerState.equipped["SLOT_WEAPON"] is GearItem, "已装备还原为 GearItem")

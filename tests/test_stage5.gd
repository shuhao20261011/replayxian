extends TestCase
## 阶段5：境界突破 / 破面板 / 地图开放 / 首通奖励 / 终关核心橙装三选一 / 15关内容读表 / 暗图描边 / 全场描边让开 HUD / 构建版本

const MAIN := preload("res://scenes/main.tscn")

func _main() -> Array:
	var m: Node = MAIN.instantiate()
	runner.add_child(m)
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	return [m, m.get_node("HUD"), m.get_node("Battle")]

func _free_main(m: Node) -> void:
	runner.get_tree().paused = false
	runner.remove_child(m); m.queue_free()

## 补足下一次突破所需（只补差额）
func _fund_next() -> void:
	var nx := PlayerState.next_realm()
	if nx == null:
		return
	PlayerState.xiuwei = maxi(PlayerState.xiuwei, nx.xiuwei_cost)
	PlayerState.lingshi = maxi(PlayerState.lingshi, nx.lingshi_cost)
	if nx.material_id != "" and PlayerState.item_count(nx.material_id) < nx.material_count:
		PlayerState.add_item(nx.material_id, nx.material_count - PlayerState.item_count(nx.material_id))

func test_realm_defs_read_table() -> void:
	for r in GameData.tables.realms:
		var rl := GameData.get_realm(CsvUtil.s(r, "realm_id"))
		check(rl != null, "境界 %s 已加载" % CsvUtil.s(r, "realm_id"))
		eq(rl.xiuwei_cost, CsvUtil.i(r, "xiuwei_cost"), "%s 修为消耗读表" % rl.id)
		eq(rl.lingshi_cost, CsvUtil.i(r, "lingshi_cost"), "%s 灵石消耗读表" % rl.id)
		eq(rl.material_id, CsvUtil.s(r, "material_id"), "%s 突破材料读表" % rl.id)
		eq(rl.unlock_map_id, CsvUtil.s(r, "unlock_map_id"), "%s 开放地图读表" % rl.id)
	eq(GameData.maps_ordered().map(func(m: MapDef) -> String: return m.id), ["MAP_QINGZHU", "MAP_LEIZE", "MAP_XUANYAN"], "地图按 order 排序")

func test_breakthrough_requirements_cost_and_unlock() -> void:
	eq(PlayerState.realm_id, "RL_LIANQI", "新存档炼气")
	var st := PlayerState.breakthrough_status()
	eq(st.code, "no_xiuwei", "修为不足")
	eq((st.realm as RealmDef).id, "RL_ZHUJI", "下一境界筑基")
	eq(st.reqs.size(), 3, "三项条件：修为 / 灵石 / 突破材料")
	check(not PlayerState.map_unlocked("MAP_LEIZE"), "雷泽谷未开放")
	var nx: RealmDef = st.realm
	PlayerState.xiuwei = nx.xiuwei_cost + 7
	PlayerState.lingshi = nx.lingshi_cost - 1
	eq(PlayerState.breakthrough(), "no_lingshi", "灵石差1也不行")
	PlayerState.lingshi = nx.lingshi_cost + 5
	eq(PlayerState.breakthrough(), "no_material", "缺突破材料")
	eq(PlayerState.realm_id, "RL_LIANQI", "失败不改境界、不扣资源")
	eq(PlayerState.xiuwei, nx.xiuwei_cost + 7, "失败不扣修为")
	PlayerState.add_item(nx.material_id, nx.material_count + 1)
	var got := []
	PlayerState.realm_broken.connect(func(r: String, mp: String) -> void: got.append([r, mp]), CONNECT_ONE_SHOT)
	PlayerState.record_auto_failure("LV_1_1")
	eq(PlayerState.breakthrough(), "ok", "条件齐全必定成功")
	eq(PlayerState.realm_id, "RL_ZHUJI", "晋入筑基")
	eq(PlayerState.xiuwei, 7, "扣修为")
	eq(PlayerState.lingshi, 5, "扣灵石")
	eq(PlayerState.item_count(nx.material_id), 1, "扣突破材料")
	eq(got, [["RL_ZHUJI", "MAP_LEIZE"]], "发出 realm_broken（地图开放）")
	check(PlayerState.map_unlocked("MAP_LEIZE"), "雷泽谷开放")
	check(not PlayerState.map_unlocked("MAP_XUANYAN"), "玄岩洞仍未开放")
	check(PlayerState.unstable_levels.is_empty(), "突破清除不稳定标记")
	# 属性替换为新境界基础值（无装备时 = 表值）
	PlayerState.equipped.clear()
	var cs := PlayerState.combat_stats()
	near(float(cs.atk), nx.atk, 0.001, "攻击 = 筑基基础攻击")
	near(float(cs.def), nx.def, 0.001, "防御 = 筑基基础防御")
	near(float(cs.crit_dmg), nx.crit_dmg, 0.001, "暴伤 = 筑基表值")

func test_breakthrough_chain_to_max() -> void:
	_fund_next(); eq(PlayerState.breakthrough(), "ok", "筑基")
	_fund_next(); eq(PlayerState.breakthrough(), "ok", "金丹")
	eq(PlayerState.realm_id, "RL_JINDAN", "金丹")
	check(PlayerState.map_unlocked("MAP_XUANYAN"), "玄岩洞开放")
	eq(PlayerState.breakthrough_status().code, "max_realm", "已至最高境界")
	eq(PlayerState.breakthrough(), "max_realm", "无法再突破")

## 15 关内容全部来自表：波次数、每波怪物属于本图普通怪、首领 = 本图首领、首通奖励行存在
func test_all_15_levels_content_from_tables() -> void:
	eq(GameData.levels_ordered.size(), 15, "15 关")
	var waves := {}
	for r in GameData.tables.waves:
		var lid := CsvUtil.s(r, "level_id")
		if not waves.has(lid):
			waves[lid] = {}
		(waves[lid] as Dictionary)[CsvUtil.i(r, "wave_index")] = true
		var l := GameData.get_level(lid)
		var m := GameData.get_map(l.map_id)
		check(m.normal_enemy_ids.has(CsvUtil.s(r, "enemy_id")), "%s 第%d波怪物 %s 属于%s" % [lid, CsvUtil.i(r, "wave_index"), CsvUtil.s(r, "enemy_id"), m.name])
	for l in GameData.levels_ordered:
		var m := GameData.get_map(l.map_id)
		eq((waves.get(l.id, {}) as Dictionary).size(), l.wave_count, "%s 波次数 = wave_count" % l.id)
		eq(l.boss_id, m.boss_id, "%s 首领 = 地图首领" % l.id)
		check(not GameData.first_clear.get(l.first_clear_reward_id, []).is_empty(), "%s 有首通奖励" % l.id)
		check(GameData.get_enemy(l.boss_id) != null, "%s 首领存在" % l.id)

## 从新存档一路打完 15 关：按表解锁、x-5 首通给突破材料、突破后开放下一张图、终关首通三选一
func test_full_progression_15_levels() -> void:
	PlayerState.debug_atk_mult = 40.0
	PlayerState.debug_hp_mult = 50.0
	var b := make_battle()
	var cleared := 0
	for l in GameData.levels_ordered:
		if l.unlock_realm_id != "" and GameData.get_realm(l.unlock_realm_id).order > PlayerState.realm_order():
			check(not PlayerState.can_challenge(l.id), "%s 突破前不可挑战" % l.id)
			var mat := PlayerState.next_realm().material_id
			check(PlayerState.item_count(mat) >= 1, "%s：上一张图首领首通已给突破材料 %s" % [l.id, mat])
			_fund_next()
			eq(PlayerState.breakthrough(), "ok", "突破后挑战 %s" % l.id)
		check(PlayerState.can_challenge(l.id), "%s 可挑战" % l.id)
		var fc := []
		b.first_clear_loot.connect(func(id: String, e: Array) -> void: fc.append([id, e.size()]), CONNECT_ONE_SHOT)
		check(b.challenge(l.id), "开始挑战 %s" % l.id)
		var n := b.runs_completed
		check(sim(b, 400.0, func() -> bool: return b.runs_completed > n), "%s 一轮结束" % l.id)
		eq(b.last_result, "victory", "%s 通关" % l.id)
		eq(fc.size(), 1, "%s 首通奖励发出一次" % l.id)
		if PlayerState.is_cleared(l.id):
			cleared += 1
	eq(cleared, 15, "15 关全部首通")
	eq(PlayerState.realm_id, "RL_JINDAN", "打通时为金丹")
	eq(PlayerState.pending_orange_choices.size(), 1, "终关首通：一组三选一")
	eq(PlayerState.pending_orange_choices[0], ["EQB_CORE_SWORD", "EQB_CORE_THUNDER", "EQB_CORE_GANG"], "三件流派核心橙装（读表）")
	PlayerState.debug_atk_mult = 1.0
	PlayerState.debug_hp_mult = 1.0
	free_battle(b)

func test_break_panel_ui_flow() -> void:
	var r := await _main()
	var m: Node = r[0]; var hud: Hud = r[1]; var battle: Battle = r[2]
	PlayerState.mark_cleared("LV_1_1"); PlayerState.mark_cleared("LV_1_2"); PlayerState.mark_cleared("LV_1_3")
	PlayerState.mark_cleared("LV_1_4"); PlayerState.mark_cleared("LV_1_5")
	hud._refresh_top()
	check(not hud.break_dot.visible, "条件不足时无红点")
	hud.open_panel("break")
	await runner.get_tree().process_frame
	check(runner.get_tree().paused, "打开破面板暂停战斗")
	check(hud.break_panel.visible and hud.is_panel_open(), "破面板可见（不再是占位）")
	check(hud.break_panel.break_btn.disabled, "条件不足按钮不可点")
	var hn := hud.break_panel.find_child("Req_CUR_XIUWEI", true, false)
	check(hn != null, "显示修为条件")
	check(hud.break_panel.find_child("Req_MAT_BT_QINGZHU", true, false) != null, "显示突破材料条件（读表）")
	_fund_next()
	hud.break_panel.refresh()
	hud._refresh_top()
	check(hud.break_dot.visible, "可突破时“破”入口红点")
	check(not hud.break_panel.break_btn.disabled, "条件齐全按钮可点")
	hud.break_panel.break_btn.pressed.emit()
	eq(PlayerState.realm_id, "RL_ZHUJI", "面板突破成功")
	check(hud.break_panel.unlock_card != null and hud.break_panel.unlock_card.name == "MapUnlockCard", "弹出地图开放卡片")
	eq(hud.banner_label.text, UiText.t("BANNER_REALM_UP", {"realm_name": "筑基"}), "突破横幅（读表）")
	eq(hud._banner_queue, [UiText.t("BANNER_MAP_UNLOCK", {"map_name": "雷泽谷"})], "地图开放横幅排队")
	var go := hud.break_panel.unlock_card.find_children("*", "Button", true, false)[0] as Button
	go.pressed.emit()
	check(not hud.is_panel_open() and not runner.get_tree().paused, "前往：关闭面板并恢复")
	eq(battle.level.id, "LV_2_1", "前往雷泽谷第一关")
	_free_main(m)

func test_break_panel_max_realm() -> void:
	PlayerState.set_realm("RL_JINDAN")
	var r := await _main()
	var hud: Hud = r[1]
	hud.open_panel("break")
	check(not hud.break_panel.break_btn.visible, "最高境界不显示突破按钮")
	check(hud.break_panel.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == UiText.t("LABEL_REALM_MAX")), "显示已至最高境界")
	_free_main(r[0])

func test_orange_choice_dialog() -> void:
	var r := await _main()
	var hud: Hud = r[1]
	PlayerState.add_orange_choice(["EQB_CORE_SWORD", "EQB_CORE_THUNDER", "EQB_CORE_GANG"])
	check(hud.open_orange_choice(), "打开三选一")
	check(runner.get_tree().paused and hud.orange_dialog.visible, "三选一暂停并可见")
	eq(hud.orange_dialog.cards.get_child_count(), 3, "三张卡片")
	# 稍后再选：关闭但保留
	var later: Button = null
	for c in hud.orange_dialog.find_children("*", "Button", true, false):
		if (c as Button).text == UiText.t("BTN_CHOOSE_LATER"):
			later = c
	later.pressed.emit()
	check(not hud.orange_dialog.visible and not runner.get_tree().paused, "稍后再选：关闭并恢复")
	eq(PlayerState.pending_orange_choices.size(), 1, "仍保留待选")
	hud.open_orange_choice()
	var card := hud.orange_dialog.cards.get_node("Card_EQB_CORE_THUNDER")
	(card.find_child("Choose", true, false) as Button).pressed.emit()
	check(PlayerState.pending_orange_choices.is_empty(), "选择后清空待选")
	var top: String = GameData.qualities_ordered().back().id
	var found := PlayerState.bag.filter(func(g: GearItem) -> bool: return g.base_id == "EQB_CORE_THUNDER" and g.quality_id == top)
	eq(found.size(), 1, "获得橙色雷音鼓")
	check(not runner.get_tree().paused, "选择后恢复战斗")
	eq(hud.banner_label.text, UiText.t("TOAST_ORANGE_GOT", {"equip_name": GameData.get_base("EQB_CORE_THUNDER").name}), "获得横幅")
	_free_main(r[0])

## 终关首通 → 首通卡片 → 1.5 秒后自动弹出三选一
func test_first_clear_card_then_orange_dialog() -> void:
	var r := await _main()
	var hud: Hud = r[1]; var battle: Battle = r[2]
	for l in GameData.levels_ordered:
		if l.id != "LV_3_5":
			PlayerState.mark_cleared(l.id)
	PlayerState.set_realm("RL_JINDAN")
	battle.start_run(GameData.get_level("LV_3_5"), Battle.RunMode.CHALLENGE)
	battle._finish("victory")
	check(hud.first_clear_card.visible, "首通卡片可见")
	check(hud.first_clear_card.items_box.get_child_count() >= 4, "首通奖励逐项列出（灵石/修为/装备/书/三选一）")
	check(hud.first_clear_card.title_label.text.contains(GameData.get_level("LV_3_5").name), "卡片标题含关卡名")
	check(not hud.orange_dialog.visible, "卡片先亮相")
	hud._process(1.6)
	check(hud.orange_dialog.visible and runner.get_tree().paused, "随后弹出三选一")
	hud.close_panel()
	_free_main(r[0])

func test_map_panel_groups_and_tags() -> void:
	var r := await _main()
	var hud: Hud = r[1]
	eq(Hud.map_tag(GameData.get_map("MAP_LEIZE")), "MAP_TAG_NEED_REALM", "未开放：需境界")
	eq(Hud.map_tag(GameData.get_map("MAP_QINGZHU")), "", "首图无标签")
	hud.open_panel("map")
	var hdr := hud.panel_body.get_node("MapHeader_MAP_LEIZE")
	check(hdr.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == UiText.t("MAP_TAG_NEED_REALM", {"realm_name": "筑基"})), "地图面板显示“需筑基”")
	hud.close_panel()
	_fund_next(); PlayerState.breakthrough()
	eq(Hud.map_tag(GameData.get_map("MAP_LEIZE")), "MAP_TAG_NEW", "刚开放：新开")
	PlayerState.mark_cleared("LV_2_1")
	eq(Hud.map_tag(GameData.get_map("MAP_LEIZE")), "", "通关一关后去掉新开")
	_free_main(r[0])

func test_dark_map_rim_material() -> void:
	check(ResourceLoader.exists(CreatureArt.RIM_MATERIAL), "描边材质存在")
	var mat := load(CreatureArt.RIM_MATERIAL) as ShaderMaterial
	for p in ["outline_color", "outline_alpha", "outline_width_px", "rim_color", "rim_strength", "rim_width_px", "light_dir", "alpha_threshold"]:
		check(mat.get_shader_parameter(p) != null, "参数 %s 可调" % p)
	check(float(mat.get_shader_parameter("outline_alpha")) <= 0.6, "描边克制（alpha ≤ 0.6）")
	var b := make_battle()
	for c in [["LV_1_1", false], ["LV_2_1", true], ["LV_3_1", true]]:
		b.start_run(GameData.get_level(c[0]), Battle.RunMode.FARM)
		var e := b.spawn_enemy(GameData.get_enemy(GameData.get_map(b.level.map_id).normal_enemy_ids[0]), 400.0)
		var anim := e.get_node_or_null("Anim") as CanvasItem
		check(anim != null, "%s 怪物有动画" % c[0])
		eq(anim.material != null, c[1], "%s 描边 = %s" % [c[0], c[1]])
		var bs := b.debug_force_boss()
		eq((bs.get_node("Anim") as CanvasItem).material != null, c[1], "%s 首领描边 = %s" % [c[0], c[1]])
	free_battle(b)

func test_arena_outline_clip_segment() -> void:
	var keep := Telegraph.clip_segment(Vector2(0, 100), Vector2(1000, 100), [Rect2(200, 80, 100, 40), Rect2(600, 0, 50, 50)], 3.0)
	eq(keep.size(), 2, "只被第一个矩形截断（第二个不相交）")
	near(float(keep[0][1]), 197.0, 0.01, "断口起点（含半线宽）")
	near(float(keep[1][0]), 303.0, 0.01, "断口终点")
	var vert := Telegraph.clip_segment(Vector2(10, 0), Vector2(10, 500), [Rect2(0, 100, 50, 50)], 0.0)
	eq(vert, [[0.0, 100.0], [150.0, 500.0]], "竖边同样断开")

## 全场预警描边让开拾取提示 / 挑战按钮 / 引导文字：HUD 每帧把可见控件写进 battle.hud_avoid_rects
func test_arena_frame_avoids_hud_widgets() -> void:
	var r := await _main()
	var hud: Hud = r[1]; var battle: Battle = r[2]
	hud.show_loot_toast({"text": "x", "icon": "", "quality": 4})
	hud._show_hint(UiText.t("BANNER_CLEAR", {"level_name": "x"}))
	hud._process(0.016)
	var rects := battle.hud_avoid_rects
	for c in [hud.loot_toast, hud.challenge_btn]:
		var gr := (c as Control).get_global_rect()
		check(rects.any(func(x: Rect2) -> bool: return x.encloses(gr) or x.is_equal_approx(gr)), "%s 在让开列表" % c.name)
	check(rects.any(func(x: Rect2) -> bool: return hud.hint_label.get_global_rect().intersects(x)), "引导文字在让开列表")
	# 让开区收窄到文字宽度（不吞掉整列）
	var hr: Rect2 = rects.filter(func(x: Rect2) -> bool: return hud.hint_label.get_global_rect().intersects(x))[0]
	check(hr.size.x < hud.hint_label.get_global_rect().size.x or hud.hint_label.get_global_rect().size.x < 400.0, "按文字宽度收窄")
	hud.loot_toast.visible = false
	hud._process(0.016)
	check(not battle.hud_avoid_rects.any(func(x: Rect2) -> bool: return x.is_equal_approx(hud.loot_toast.get_global_rect())), "隐藏后不再让开")
	_free_main(r[0])

func test_build_info_label() -> void:
	eq(UiText.render("{c:raw}", {"c": "12e4567"}), "12e4567", ":raw 不按数字格式化")
	eq(UiText.render("{c}", {"c": 3.0}), "3", "其他格式不受影响")
	eq(BuildInfo.label_text({}), UiText.t("HUD_BUILD_DEV"), "无构建信息 = 开发版")
	eq(BuildInfo.label_text({"stage": "5", "commit": "1234567"}), UiText.t("HUD_BUILD_VERSION", {"stage": "5", "commit": "1234567"}), "阶段 + 提交号")
	check(BuildInfo.label_text({"stage": "5", "commit": "1234567"}).contains("1234567"), "提交号原样显示")
	check(BuildInfo.label_text({"stage": "5", "commit": "abc", "dirty": true}).contains("abc+"), "未提交改动标 +")
	var r := await _main()
	var hud: Hud = r[1]
	check(hud.version_label != null and hud.version_label.is_visible_in_tree() and hud.version_label.text != "", "HUD 显示版本小字")
	_free_main(r[0])

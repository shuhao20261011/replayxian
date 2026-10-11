extends Node
## 截图工具（需窗口渲染：xvfb-run godot --path . res://tools/shot.tscn -- --out=<目录> [--prefix=xxx]）。
## 每张地图：普通波次 + 首领危险招式预警中；另截装备 / 功法面板。演示数据用 PlayerState.debug_fill_demo（固定种子）。

var out := "/tmp"
var prefix := "stage3-4"
var shot_set := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.split("=")[1]
		if a.begins_with("--prefix="): prefix = a.split("=")[1]
		if a.begins_with("--set="): shot_set = a.split("=")[1]
	get_window().size = Vector2i(1280, 720)
	PlayerState.reset_new_game()
	PlayerState.debug_fill_demo()
	PlayerState.add_book("BK_THUNDER_PALM", 1)   # 未学技能书 → 功法红点
	PlayerState.debug_atk_mult = 1.0
	PlayerState.debug_hp_mult = 50.0
	var m: Node = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	var b: Battle = m.get_node("Battle")
	var hud: Hud = m.get_node("HUD")
	if shot_set == "stage5" or shot_set == "orange_auto":
		await _stage5(b, hud) if shot_set == "stage5" else await _final_orange(b, hud, true)
		get_tree().quit(0)
		return
	var cases := [["LV_1_3", "qingzhu", "BA_ZHUMEI_THORN"], ["LV_2_3", "leize", "BA_KUINIU_BOLTS"], ["LV_3_4", "xuanyan", "BA_YANMO_SKYFALL"]]
	for c in cases:
		b.start_run(GameData.get_level(c[0]), Battle.RunMode.FARM)
		await _wait(6.5)
		var loot := LootSystem.apply([{"type": "equipment", "item": GearSystem.make_item(GearSystem.normal_bases(1, "SLOT_WEAPON")[0].id, "Q_PURPLE", b.rng)}])
		b._show_loot(loot, b.player.position + Vector2(160, 0))
		b.player.add_shield({"skill_id": "SK_GANG_GUARD", "amount": 200.0, "max": 200.0, "time": 5.0, "absorbed": 0.0})
		await _wait(0.45)
		await _shot("%s_battle_%s" % [prefix, c[1]])
		var bs := b.debug_force_boss()
		await _wait(2.0)
		bs.stun_t = 3.0
		b.start_boss_attack(bs, GameData.get_boss_attack(c[2]))
		await _wait(0.55)
		await _shot("%s_boss_%s_%s" % [prefix, c[1], str(c[2]).to_lower()])
	b.start_run(GameData.get_level("LV_1_3"), Battle.RunMode.FARM)
	await _wait(3.0)
	hud.open_panel("gear")
	await _wait(0.6)
	await _shot("%s_panel_gear" % prefix)
	hud.open_panel("gongfa")
	hud.gongfa_panel.select_gongfa("GF_SWORD")
	hud.gongfa_panel.select_skill("SK_SWORD_COMBO")
	await _wait(0.6)
	await _shot("%s_panel_gongfa" % prefix)
	hud.open_panel("map")
	await _wait(0.6)
	await _shot("%s_panel_map" % prefix)
	get_tree().quit(0)

## 阶段5：破面板 / 地图开放 / 首通奖励 / 三选一 / 暗图描边（含无描边对照）/ 全场描边让开 HUD / 地图面板标签
func _stage5(b: Battle, hud: Hud) -> void:
	PlayerState.reset_new_game()
	PlayerState.debug_fill_demo()
	PlayerState.realm_id = "RL_LIANQI"
	PlayerState.debug_atk_mult = 1.0
	PlayerState.debug_hp_mult = 50.0
	for id in ["LV_1_1", "LV_1_2", "LV_1_3", "LV_1_4"]:
		PlayerState.mark_cleared(id)
	# 1) 首通奖励：竹魅幽谷（1-5）首通
	b.start_run(GameData.get_level("LV_1_5"), Battle.RunMode.CHALLENGE)
	await _wait(3.0)
	b._finish("victory")
	await _wait(0.5)
	await _shot("%s_first_clear_reward" % prefix)
	await _wait(6.0)
	# 2) 破面板（条件齐全）
	var nx := PlayerState.next_realm()
	PlayerState.xiuwei = maxi(PlayerState.xiuwei, nx.xiuwei_cost + 320)
	PlayerState.lingshi = maxi(PlayerState.lingshi, nx.lingshi_cost + 860)
	hud.open_panel("break")
	await _wait(0.6)
	await _shot("%s_panel_break" % prefix)
	# 3) 突破 → 地图开放卡片
	hud.break_panel.do_breakthrough()
	await _wait(0.6)
	await _shot("%s_map_unlock" % prefix)
	hud.close_panel()
	await _wait(0.3)
	hud.open_panel("map")
	await _wait(0.5)
	await _shot("%s_panel_map_tags" % prefix)
	hud.close_panel()
	# 4) 暗图描边：雷泽谷 / 玄岩洞，各截有描边与无描边对照
	for c in [["LV_2_3", "leize"], ["LV_3_3", "xuanyan"]]:
		PlayerState.realm_id = "RL_JINDAN"
		b.start_run(GameData.get_level(c[0]), Battle.RunMode.FARM)
		await _wait(7.0)
		get_tree().paused = true   # 同一冻结帧上对照（受击闪白等 modulate 不变）
		await _wait(0.1)
		await _shot("%s_dark_%s_rim" % [prefix, c[1]])
		for e in b.enemies:
			var a := e.get_node_or_null("Anim") as CanvasItem
			if a: a.material = null
		await _wait(0.1)
		await _shot("%s_dark_%s_norim" % [prefix, c[1]])
		get_tree().paused = false
	# 5) 全场预警描边在拾取提示 / 挑战按钮 / 引导文字处断开
	PlayerState.reset_new_game(); PlayerState.debug_fill_demo(); PlayerState.debug_hp_mult = 50.0
	b.start_run(GameData.get_level("LV_3_4"), Battle.RunMode.FARM)
	await _wait(2.0)
	var bs := b.debug_force_boss()
	await _wait(2.0)
	var loot := LootSystem.apply([{"type": "equipment", "item": GearSystem.make_item(GearSystem.normal_bases(1, "SLOT_WEAPON")[0].id, "Q_PURPLE", b.rng)}])
	b._show_loot(loot, b.player.position + Vector2(160, 0))
	bs.stun_t = 3.0
	b.start_boss_attack(bs, GameData.get_boss_attack("BA_YANMO_SKYFALL"))
	await _wait(0.55)
	await _shot("%s_arena_frame_avoid_hud" % prefix)
	if shot_set == "stage5":
		await _final_orange(b, hud, false)   # 6) 手动：首通卡片 → 模态三选一
		hud.close_panel()
	await _final_orange(b, hud, true)   # 7) 自动挂机：首通卡片收起后非阻塞卡片（不暂停）

## 终关首通 → 首通卡片 → 三选一（manual：模态；auto：非阻塞卡片）
func _final_orange(b: Battle, hud: Hud, auto: bool) -> void:
	PlayerState.pending_orange_choices.clear()
	PlayerState.cleared_levels.erase("LV_3_5")
	PlayerState.set_auto_battle(auto)
	for l in GameData.levels_ordered:
		PlayerState.mark_cleared(l.id) if l.id != "LV_3_5" else null
	PlayerState.realm_id = "RL_JINDAN"
	b.start_run(GameData.get_level("LV_3_5"), Battle.RunMode.CHALLENGE)
	await _wait(2.0)
	b._finish("victory")
	await _wait(0.5)
	if not auto:
		await _shot("%s_first_clear_final" % prefix)
		await _wait(1.6)
		await _shot("%s_orange_choice" % prefix)
		return
	hud.first_clear_card._t = 0.0
	await _wait(1.0)
	await _shot("%s_orange_auto_card" % prefix)

func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await get_tree().process_frame
		t += get_process_delta_time()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var p := "%s/%s.png" % [out, name]
	get_viewport().get_texture().get_image().save_png(p)
	print("SHOT ", p)

extends Node
## 截图工具（需窗口渲染：xvfb-run godot --path . res://tools/shot.tscn -- --out=<目录> [--prefix=xxx]）。
## 每张地图：普通波次 + 首领危险招式预警中；另截装备 / 功法面板。演示数据用 PlayerState.debug_fill_demo（固定种子）。

var out := "/tmp"
var prefix := "stage3-4"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.split("=")[1]
		if a.begins_with("--prefix="): prefix = a.split("=")[1]
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

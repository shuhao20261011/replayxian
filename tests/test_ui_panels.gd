extends TestCase
## 装备/功法面板：打开暂停战斗、面板内按钮可操作（暂停中 UI 仍可交互）、关闭恢复并刷新属性

const MAIN := preload("res://scenes/main.tscn")

func _find_button(root: Node, prefix: String) -> Button:
	for c in root.find_children("*", "Button", true, false):
		var b := c as Button
		if b.text.begins_with(prefix) and not b.disabled and b.is_visible_in_tree():
			return b
	return null

func test_gear_panel_pause_equip_and_resume() -> void:
	var m: Node = MAIN.instantiate()
	runner.add_child(m)
	await runner.get_tree().process_frame
	var hud: Hud = m.get_node("HUD")
	var battle: Battle = m.get_node("Battle")
	var g := GearSystem.make_item("EQB_WEAPON_T1", "Q_PURPLE", RandomNumberGenerator.new())
	PlayerState.add_gear(g)
	PlayerState.mark_cleared("LV_1_1")
	PlayerState.record_auto_failure("LV_1_2")
	hud.open_panel("gear")
	check(runner.get_tree().paused, "打开装备面板暂停战斗")
	check(hud.gear_panel.visible and hud.is_panel_open(), "装备面板可见")
	eq(hud.gear_panel.process_mode, Node.PROCESS_MODE_INHERIT, "面板继承 HUD 的 ALWAYS")
	check(hud.gear_panel.can_process(), "暂停中面板仍可处理输入")
	var t0 := battle.sim_time
	await runner.get_tree().physics_frame
	await runner.get_tree().physics_frame
	near(battle.sim_time, t0, 0.0001, "暂停期间战斗不推进")
	hud.gear_panel.select(g.uid)
	var eb := _find_button(hud.gear_panel, UiText.t("BTN_EQUIP_GEAR"))
	check(eb != null, "详情里有【装备】按钮")
	if eb:
		eb.pressed.emit()
	eq(PlayerState.equipped["SLOT_WEAPON"], g, "通过面板换装")
	check(PlayerState.unstable_levels.is_empty(), "面板换装清除不稳定标记")
	hud.close_panel()
	check(not runner.get_tree().paused, "关闭恢复")
	near(float(battle.player.stats.atk), float(PlayerState.combat_stats().atk), 0.001, "关闭面板后本局属性已刷新")
	runner.remove_child(m); m.queue_free()

func test_gongfa_panel_learn_upgrade_equip() -> void:
	var m: Node = MAIN.instantiate()
	runner.add_child(m)
	await runner.get_tree().process_frame
	var hud: Hud = m.get_node("HUD")
	PlayerState.add_book("BK_SWORD_COMBO", 1)
	PlayerState.lingshi = 100000
	hud.open_panel("gongfa")
	check(runner.get_tree().paused and hud.gongfa_panel.visible, "功法面板打开并暂停")
	hud.gongfa_panel.select_gongfa("GF_SWORD")
	hud.gongfa_panel.select_skill("SK_SWORD_COMBO")
	var lb := _find_button(hud.gongfa_panel, UiText.t("BTN_LEARN", {"book_name": GameData.get_book("BK_SWORD_COMBO").name}))
	check(lb != null, "有【学习】按钮")
	if lb:
		lb.pressed.emit()
	eq(PlayerState.skill_level("SK_SWORD_COMBO"), 1, "面板学习")
	hud.gongfa_panel.refresh()
	var ub := _find_button(hud.gongfa_panel, UiText.t("BTN_UPGRADE", {"cost": PlayerState.upgrade_cost("SK_SWORD_COMBO")}))
	if ub:
		ub.pressed.emit()
	eq(PlayerState.skill_level("SK_SWORD_COMBO"), 2, "面板升级")
	hud.gongfa_panel.refresh()
	var e4 := _find_button(hud.gongfa_panel, UiText.t("BTN_EQUIP_TO_SLOT", {"slot": 4}))
	if e4:
		e4.pressed.emit()
	eq(PlayerState.active_slots[3], "SK_SWORD_COMBO", "面板装配到第4格")
	hud.close_panel()
	check(not runner.get_tree().paused, "关闭恢复")
	runner.remove_child(m); m.queue_free()

func _main() -> Array:
	var m: Node = MAIN.instantiate()
	runner.add_child(m)
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	return [m, m.get_node("HUD"), m.get_node("Battle")]

func _end(m: Node) -> void:
	runner.get_tree().paused = false
	runner.remove_child(m)
	m.queue_free()

func test_esc_closes_panel() -> void:
	var r: Array = await _main()
	var hud: Hud = r[1]
	for id in ["gear", "gongfa", "map", "break"]:
		hud.open_panel(id)
		check(hud.is_panel_open() and runner.get_tree().paused, "%s 打开" % id)
		var ev := InputEventAction.new(); ev.action = "ui_cancel"; ev.pressed = true
		hud._input(ev)
		check(not hud.is_panel_open() and not runner.get_tree().paused, "Esc 关闭 %s 并恢复战斗" % id)
	_end(r[0])

func test_bug015_telegraphs_readable_above_hud() -> void:
	var r: Array = await _main()
	var hud: Hud = r[1]
	var b: Battle = r[2]
	b.start_run(GameData.get_level("LV_3_4"), Battle.RunMode.CHALLENGE)
	var bs := b.debug_force_boss()
	bs.stun_t = 100.0
	b.start_boss_attack(bs, GameData.get_boss_attack("BA_YANMO_QUAKE"))
	b.start_boss_attack(bs, GameData.get_boss_attack("BA_YANMO_SKYFALL"))
	await runner.get_tree().process_frame
	var hud_layer := (hud as CanvasLayer).layer
	for tg: Telegraph in b.telegraphs:
		if tg.arena:
			check(tg.get_parent() == b.telegraph_root, "全场预警底色留在世界层（不染 HUD）")
		else:
			check(tg.get_parent() == b.telegraph_over_root and b.telegraph_over_layer.layer > hud_layer, "地面预警画在 HUD 之上")
	var safe := hud.safe_rect()
	var vs := hud.root.get_viewport_rect().size
	check(safe.position.y > 40.0 and safe.end.y < vs.y - 100.0, "可见战场区避开顶栏与底栏（%s）" % str(safe))
	var sv := b.safe_view_rect()
	var vr := b.view_rect()
	near(sv.position.y - vr.position.y, safe.position.y, 0.5, "全场描边上沿 = 顶栏下沿")
	near(vr.end.y - sv.end.y, vs.y - safe.end.y, 0.5, "全场描边下沿 = 底栏上沿")
	hud.open_panel("gear")
	check(not b.telegraph_over_layer.visible, "打开面板时隐藏 HUD 之上的预警层")
	hud.close_panel()
	check(b.telegraph_over_layer.visible, "关闭面板后恢复")
	_end(r[0])

func test_bug016_white_toggle_hidden_by_default() -> void:
	var r: Array = await _main()
	var hud: Hud = r[1]
	check(not Hud.telegraph_white_toggle_enabled(), "默认不显示统一预警白开关")
	hud.open_panel("map")
	check(hud.panel_body.find_children("*", "CheckButton", true, false).is_empty(), "地图面板里没有设置开关")
	ProjectSettings.set_setting(Hud.TELEGRAPH_WHITE_TOGGLE_SETTING, true)
	hud.open_panel("map")
	var cbs := hud.panel_body.find_children("*", "CheckButton", true, false)
	check(cbs.size() == 1, "打开开关后地图面板出现“统一预警白”")
	if cbs.size() == 1:
		(cbs[0] as CheckButton).button_pressed = true
		check(PlayerState.telegraph_alt, "切换后 PlayerState.telegraph_alt=true")
	ProjectSettings.set_setting(Hud.TELEGRAPH_WHITE_TOGGLE_SETTING, false)
	PlayerState.telegraph_alt = false
	hud.close_panel()
	_end(r[0])

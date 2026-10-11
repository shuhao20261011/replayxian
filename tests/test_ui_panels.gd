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
	hud.open_panel("装备")
	check(runner.get_tree().paused, "打开装备面板暂停战斗")
	check(hud.gear_panel.visible and hud.is_panel_open(), "装备面板可见")
	eq(hud.gear_panel.process_mode, Node.PROCESS_MODE_INHERIT, "面板继承 HUD 的 ALWAYS")
	check(hud.gear_panel.can_process(), "暂停中面板仍可处理输入")
	var t0 := battle.sim_time
	await runner.get_tree().physics_frame
	await runner.get_tree().physics_frame
	near(battle.sim_time, t0, 0.0001, "暂停期间战斗不推进")
	hud.gear_panel.select(g.uid)
	var eb := _find_button(hud.gear_panel, "装备")
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
	hud.open_panel("功法")
	check(runner.get_tree().paused and hud.gongfa_panel.visible, "功法面板打开并暂停")
	hud.gongfa_panel.select_gongfa("GF_SWORD")
	hud.gongfa_panel.select_skill("SK_SWORD_COMBO")
	var lb := _find_button(hud.gongfa_panel, "学习")
	check(lb != null, "有【学习】按钮")
	if lb:
		lb.pressed.emit()
	eq(PlayerState.skill_level("SK_SWORD_COMBO"), 1, "面板学习")
	hud.gongfa_panel.refresh()
	var ub := _find_button(hud.gongfa_panel, "升级")
	if ub:
		ub.pressed.emit()
	eq(PlayerState.skill_level("SK_SWORD_COMBO"), 2, "面板升级")
	hud.gongfa_panel.refresh()
	var e4 := _find_button(hud.gongfa_panel, "装到4")
	if e4:
		e4.pressed.emit()
	eq(PlayerState.active_slots[3], "SK_SWORD_COMBO", "面板装配到第4格")
	hud.close_panel()
	check(not runner.get_tree().paused, "关闭恢复")
	runner.remove_child(m); m.queue_free()

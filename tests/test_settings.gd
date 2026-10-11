extends TestCase
## 阶段6 UI：【存】圆章进设置页、存档状态文字、统一预警白开关（常显 + 落盘）、重置两步确认（第二步延迟可点）、
## 导入失败提示、闭关收益页领取流程、启动提示（损坏 / 恢复）。全部在 user://test_saves/ui_* 下，不碰真实存档。

const MAIN := preload("res://scenes/main.tscn")
const T0 := 1_800_000_000

func _dir(tag: String) -> String:
	var d := "user://test_saves/ui_%s" % tag
	var da := DirAccess.open(d)
	if da:
		for f in da.get_files():
			da.remove(f)
	DirAccess.make_dir_recursive_absolute(d)
	return d

func _on(d: String) -> void:
	SaveSystem.dir = d
	SaveSystem.clock_override = T0
	SaveSystem.enabled = true
	SaveSystem.write_blocked = false
	SaveSystem._web_mirror_override = null
	SaveSystem._pending_reasons.clear()
	SaveSystem.save_count = 0

func _off() -> void:
	SaveSystem.enabled = false
	SaveSystem.write_blocked = false
	SaveSystem.booted = false
	SaveSystem.dir = "user://"
	SaveSystem.clock_override = -1
	SaveSystem._pending_reasons.clear()
	SaveSystem._flush_queued = false
	SaveSystem._set_status("off")

func _main() -> Array:
	var m: Node = MAIN.instantiate()
	runner.add_child(m)
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	return [m, m.get_node("HUD"), m.get_node("Battle")]

func _end(m: Node) -> void:
	_off()
	runner.get_tree().paused = false
	runner.remove_child(m)
	m.queue_free()

func _frames(n: int) -> void:
	for i in n:
		await runner.get_tree().process_frame

func test_badge_opens_settings_and_status_text() -> void:
	var r: Array = await _main()
	var hud: Hud = r[1]
	eq(hud.save_label.text, UiText.t("HUD_SAVE_PENDING"), "测试 / 无头运行：存档未启用")
	eq(hud.save_badge.mouse_filter, Control.MOUSE_FILTER_STOP, "【存】圆章可点")
	eq(hud.save_badge.tooltip_text, UiText.t("TIP_SAVE_BADGE"), "圆章悬停：设置与存档")
	var ev := InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = true
	hud.save_badge.gui_input.emit(ev)
	check(hud.settings_panel.visible and hud.is_panel_open() and runner.get_tree().paused, "点击圆章打开设置页并暂停")
	_on(_dir("badge"))
	SaveSystem.save_now("test")
	eq(hud.save_label.text, UiText.t("HUD_SAVE_OK"), "保存后：已保存")
	eq(hud.settings_panel.state_value.text, UiText.t("HUD_SAVE_OK"), "设置页同步显示状态")
	check(hud.save_label.tooltip_text.begins_with(UiText.t("TIP_SAVE_LAST", {"time": ""})), "悬停显示上次保存时间")
	PlayerState.lingshi += 1
	PlayerState.important_change.emit("equip")
	eq(hud.save_label.text, UiText.t("HUD_SAVE_DIRTY"), "重要操作后、本帧末保存前：待保存")
	await _frames(2)
	eq(hud.save_label.text, UiText.t("HUD_SAVE_OK"), "防抖保存完成：已保存")
	for st in ["error", "blocked"]:
		check(Hud.save_status_text(st) != Hud.save_status_text("saved"), "%s 有独立文字" % st)
	var ue := InputEventAction.new(); ue.action = "ui_cancel"; ue.pressed = true
	hud._input(ue)
	check(not hud.settings_panel.visible and not runner.get_tree().paused, "Esc 关闭设置页并恢复")
	_end(r[0])

func test_telegraph_toggle_persists() -> void:
	var r: Array = await _main()
	var hud: Hud = r[1]
	var d := _dir("tele")
	_on(d)
	PlayerState.set_telegraph_alt(false)
	await _frames(2)
	hud.open_settings()
	var cb := hud.settings_panel.telegraph_toggle
	check(cb.is_visible_in_tree() and not cb.button_pressed, "开关常显、初始关")
	var n0 := SaveSystem.save_count
	cb.button_pressed = true
	await _frames(2)
	check(SaveSystem.save_count > n0, "切换设置后自动保存")
	var dec := SaveCodec.decode(FileAccess.get_file_as_string(d.path_join(SaveSystem.FILE)), T0, false)
	check(dec.ok and bool(dec.data.telegraph_alt), "存档里 telegraph_alt=true")
	PlayerState.set_telegraph_alt(false)
	_end(r[0])

func test_reset_two_step_confirm_with_arming() -> void:
	var r: Array = await _main()
	var hud: Hud = r[1]
	var d := _dir("reset")
	_on(d)
	PlayerState.lingshi = 999
	SaveSystem.save_now("test")
	hud.open_settings()
	var dlg := hud.confirm_dialog
	hud.settings_panel.reset_btn.pressed.emit()
	check(dlg.visible and dlg.step == 1, "第一次确认")
	eq(dlg.text_label.text, UiText.t("CONFIRM_RESET_1"), "第一步文案")
	var ue := InputEventAction.new(); ue.action = "ui_cancel"; ue.pressed = true
	hud._input(ue)
	check(not dlg.visible and hud.settings_panel.visible, "Esc 只关确认框，设置页仍开")
	eq(PlayerState.lingshi, 999, "取消不重置")
	hud.settings_panel.reset_btn.pressed.emit()
	dlg.confirm()
	check(dlg.visible and dlg.step == 2, "进入第二次确认")
	eq(dlg.text_label.text, UiText.t("CONFIRM_RESET_2"), "第二步文案")
	check(dlg.ok_btn.disabled, "第二步确认键先禁用（防连点穿透）")
	dlg.confirm()
	eq(PlayerState.lingshi, 999, "未解锁时点确认无效")
	dlg._process(ConfirmDialog.ARM_SEC + 0.01)
	check(not dlg.ok_btn.disabled, "延迟后可点")
	eq(dlg.ok_btn.text, UiText.t("BTN_CONFIRM_RESET"), "第二步按钮：确认重置")
	dlg.ok_btn.pressed.emit()
	check(PlayerState.lingshi != 999, "两次确认后重置")
	check(FileAccess.file_exists(d.path_join("save.before_reset.json")), "重置前已备份")
	check(not dlg.visible or dlg.step == 0, "确认框流程结束")
	_end(r[0])

func test_import_fail_message_keeps_progress() -> void:
	var r: Array = await _main()
	var hud: Hud = r[1]
	_on(_dir("imp"))
	PlayerState.lingshi = 4321
	hud.open_settings()
	hud.settings_panel.import_text("{not json")
	var want := UiText.t("MSG_IMPORT_FAIL", {"reason": UiText.t("IMPORT_ERR_PARSE")})
	eq(hud.settings_panel.msg_label.text, want, "设置页显示失败原因")
	check(hud.confirm_dialog.visible and hud.confirm_dialog.text_label.text == want, "弹出存档提示")
	eq(PlayerState.lingshi, 4321, "进度不变")
	hud.confirm_dialog.confirm()
	hud.settings_panel.import_text("   ")
	eq(hud.settings_panel.msg_label.text, UiText.t("MSG_IMPORT_FAIL", {"reason": UiText.t("IMPORT_ERR_EMPTY")}), "空内容")
	hud.confirm_dialog.confirm()
	for code in ["too_big", "parse", "fields", "too_new", "checksum", "migrate", "range", "ids", "rules"]:
		check(UiText.has(SettingsPanel.import_error_key(code)), "错误码 %s 有文案" % code)
	_end(r[0])

func test_import_success_via_ui_two_steps() -> void:
	var r: Array = await _main()
	var hud: Hud = r[1]
	_on(_dir("imp_ok"))
	PlayerState.lingshi = 777
	var text := SaveSystem.export_string()
	PlayerState.lingshi = 1
	hud.open_settings()
	hud.settings_panel.import_text(text)
	var dlg := hud.confirm_dialog
	check(dlg.visible and dlg.step == 1, "预检通过 → 第一次确认")
	dlg.confirm()
	dlg._process(ConfirmDialog.ARM_SEC + 0.01)
	dlg.confirm()
	eq(PlayerState.lingshi, 777, "两次确认后导入")
	eq(hud.settings_panel.msg_label.text, UiText.t("MSG_IMPORT_DONE"), "提示导入完成")
	_end(r[0])

func test_offline_panel_claim_flow() -> void:
	var r: Array = await _main()
	var hud: Hud = r[1]
	_on(_dir("off"))
	for l in GameData.levels_ordered:
		PlayerState.cleared_levels[l.id] = true
		if l.id == "LV_1_3":
			break
	PlayerState.last_settle_at = T0 - 3600; PlayerState.max_seen_at = T0 - 3600
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var s := OfflineSystem.settle(T0, rng)
	eq(s.code, "ok", "结算 60 分钟")
	var ls0 := PlayerState.lingshi
	var pend: Dictionary = PlayerState.pending_offline.duplicate(true)
	check(hud.open_offline(), "有待领收益 → 打开闭关页")
	check(hud.offline_panel.visible and runner.get_tree().paused, "闭关页模态、暂停")
	eq(hud.offline_panel.title_label.text, UiText.t("OFFLINE_TITLE", {"minutes": int(pend.minutes)}), "标题：闭关N分钟")
	check(hud.offline_panel.items_box.get_child_count() > 0, "列出收益")
	var ue := InputEventAction.new(); ue.action = "ui_cancel"; ue.pressed = true
	hud._input(ue)
	check(hud.offline_panel.visible, "Esc 不能跳过领取")
	var n0 := SaveSystem.save_count
	hud.offline_panel.claim_btn.pressed.emit()
	eq(PlayerState.lingshi, ls0 + int(pend.lingshi), "灵石到账")
	check(PlayerState.pending_offline.is_empty(), "领取后清空")
	check(not hud.offline_panel.visible and not runner.get_tree().paused, "关闭并恢复")
	await _frames(2)
	check(SaveSystem.save_count > n0, "领取后立即存档")
	check(not hud.open_offline(), "已领取 → 不再弹出（防重复领取）")
	eq(OfflineSystem.claim().code, "none", "再次领取无效")
	_end(r[0])

func test_boot_notices_corrupt_and_recovered() -> void:
	var r: Array = await _main()
	var hud: Hud = r[1]
	hud._show_boot_notices({"code": "corrupt", "corrupt_files": ["save.corrupt.20270115_080000.json"], "dropped": [], "offline": {}})
	check(hud.confirm_dialog.visible, "损坏：弹出提示")
	check(hud.confirm_dialog.text_label.text.contains("save.corrupt.20270115_080000.json"), "提示里带损坏文件名")
	check(not hud.confirm_dialog.cancel_btn.visible, "提示框只有“知道了”")
	hud.confirm_dialog.confirm()
	hud._show_boot_notices({"code": "recovered", "corrupt_files": [], "dropped": ["X", "Y"], "offline": {"code": "rollback"}})
	eq(hud.confirm_dialog.text_label.text, UiText.t("SAVE_MSG_RECOVERED"), "已从备份恢复")
	hud.confirm_dialog.confirm()
	eq(hud.confirm_dialog.text_label.text, UiText.t("SAVE_MSG_DROPPED", {"count": 2}), "排队显示：未知内容被移除")
	hud.confirm_dialog.confirm()
	check(not hud.confirm_dialog.visible, "提示全部关闭")
	_end(r[0])

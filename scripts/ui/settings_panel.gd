class_name SettingsPanel
extends PanelContainer
## 设置页（阶段6，v2 宣纸水墨风格，与装备 / 功法 / 破面板同一外壳）。入口：右上【存】圆章（点击；悬停“设置与存档”）。
## 左“存档”：状态 / 上次保存 / 存放位置 / 存档格式版本 / 自动保存说明；导出、导入、（桌面）复制 / 粘贴存档码、重置（两次确认）。
## 右“显示”：统一预警白（BUG-016，阶段6 起常显）。打开时战斗暂停（HUD 负责）。
## 导出：Web = 浏览器下载（JavaScriptBridge.download_buffer）；桌面 = 文件对话框另存为，另有“复制存档码”（剪贴板）。
## 导入：Web = 浏览器选择文件（隐藏 <input type=file> + FileReader，经 JavaScriptBridge 回调）；桌面 = 文件对话框，另有“粘贴存档码”。
## 导入先 SaveSystem.check_import 预检（失败立即提示，进度不变），通过后两次确认才替换；替换 / 重置前 SaveSystem 自动备份。

signal closed
signal progress_replaced(kind: String)   # import / reset：HUD 重开战斗、刷新界面

var dialog: ConfirmDialog       # HUD 注入（最上层）
var state_value: Label
var last_value: Label
var where_value: Label
var msg_label: Label
var telegraph_toggle: CheckButton
var export_btn: Button
var import_btn: Button
var copy_btn: Button
var paste_btn: Button
var reset_btn: Button
var file_dialog: FileDialog
var last_export_text := ""      # 测试 / 调试：最近一次导出的文本
var _js_cb: Variant = null
var _msg := ""

func _ready() -> void:
	name = "SettingsPanel"
	var k := PanelKit.shell(self, UiText.t("TITLE_SETTINGS"), UiText.t("PANEL_SUB_SETTINGS"))
	(k.close as Button).pressed.connect(func() -> void: closed.emit())
	var body: VBoxContainer = k.body
	var cols := HBoxContainer.new(); cols.add_theme_constant_override("separation", 12); cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	# ---- 存档 ----
	var sv := PanelKit.section(cols, UiText.t("LABEL_SAVE_SECTION"), 0, true)
	state_value = _kv(sv, UiText.t("LABEL_SAVE_STATE"))
	last_value = _kv(sv, UiText.t("TIP_SAVE_LAST", {"time": ""}))
	where_value = _kv(sv, UiText.t("LABEL_SAVE_WHERE"))
	where_value.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY; where_value.custom_minimum_size = Vector2(380, 0)
	_kv(sv, UiText.t("LABEL_SAVE_FORMAT")).text = UiText.t("LABEL_SAVE_FORMAT_VALUE", {"version": SaveCodec.SAVE_VERSION})
	var auto := UiStyle.label(UiText.t("LABEL_SAVE_AUTO", {"sec": int(SaveSystem.autosave_interval())}), 14, Color(UiStyle.GOLD_TEXT, 0.7))
	sv.add_child(auto)
	sv.add_child(UiStyle.hsep(0.3))
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12); sv.add_child(row)
	export_btn = _btn(row, "BTN_EXPORT_SAVE", "TIP_EXPORT_SAVE", do_export, true)
	import_btn = _btn(row, "BTN_IMPORT_SAVE", "TIP_IMPORT_SAVE", do_import, true)
	var row2 := HBoxContainer.new(); row2.add_theme_constant_override("separation", 12); sv.add_child(row2)
	copy_btn = _btn(row2, "BTN_COPY_SAVE", "", do_copy, false)
	paste_btn = _btn(row2, "BTN_PASTE_SAVE", "", do_paste, false)
	row2.visible = not SaveSystem.is_web()   # 剪贴板兜底只在桌面版显示（Web 剪贴板需权限，用文件即可）
	sv.add_child(UiStyle.spacer())
	reset_btn = UiStyle.button(UiText.t("BTN_RESET_SAVE"), 18); reset_btn.name = "ResetSave"
	reset_btn.tooltip_text = UiText.t("TIP_RESET_SAVE")
	reset_btn.add_theme_color_override("font_color", UiStyle.BAD); reset_btn.add_theme_color_override("font_hover_color", UiStyle.BAD.lightened(0.2))
	reset_btn.custom_minimum_size = Vector2(160, 40); reset_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset_btn.pressed.connect(do_reset)
	sv.add_child(reset_btn)
	# ---- 显示 ----
	var dv := PanelKit.section(cols, UiText.t("LABEL_DISPLAY_SECTION"), 380)
	telegraph_toggle = CheckButton.new(); telegraph_toggle.name = "TelegraphWhite"
	telegraph_toggle.text = UiText.t("SETTING_TELEGRAPH_WHITE")
	telegraph_toggle.add_theme_font_size_override("font_size", 18)
	telegraph_toggle.add_theme_color_override("font_color", UiStyle.GOLD_TEXT)
	telegraph_toggle.tooltip_text = UiText.t("TIP_TELEGRAPH_WHITE")
	telegraph_toggle.toggled.connect(func(on: bool) -> void: PlayerState.set_telegraph_alt(on))
	dv.add_child(telegraph_toggle)
	var tip := UiStyle.label(UiText.t("TIP_TELEGRAPH_WHITE"), 14, Color(UiStyle.MIST, 0.75)); tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(tip)
	dv.add_child(UiStyle.spacer())
	var ver := UiStyle.label(BuildInfo.label_text(), 13, Color(UiStyle.GOLD_TEXT, 0.55)); ver.name = "BuildVersion"
	dv.add_child(ver)
	msg_label = UiStyle.label("", 16, UiStyle.GOLD_TEXT); msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; msg_label.name = "Msg"
	body.add_child(msg_label)
	SaveSystem.status_changed.connect(func(_s: String) -> void: if visible: refresh())

func _kv(parent: Control, k: String) -> Label:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); parent.add_child(h)
	var kl := UiStyle.label(k, 16, Color(UiStyle.GOLD_TEXT, 0.8)); kl.custom_minimum_size = Vector2(150, 0); h.add_child(kl)
	var v := UiStyle.label("", 16, UiStyle.MIST); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(v)
	return v

func _btn(parent: Control, key: String, tip: String, cb: Callable, primary: bool) -> Button:
	var b := UiStyle.accent_button(UiText.t(key), 18) if primary else UiStyle.button(UiText.t(key), 17)
	b.name = key
	b.custom_minimum_size = Vector2(170, 42)
	if tip != "":
		b.tooltip_text = UiText.t(tip)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func open() -> void:
	_msg = ""
	visible = true
	refresh()

func refresh() -> void:
	state_value.text = Hud.save_status_text(SaveSystem.status)
	last_value.text = Hud.clock_text(SaveSystem.last_saved_at) if SaveSystem.last_saved_at > 0 else "—"
	where_value.text = UiText.t("LABEL_SAVE_WHERE_WEB") if SaveSystem.is_web() else SaveSystem.location_text()
	telegraph_toggle.set_pressed_no_signal(PlayerState.telegraph_alt)
	var can_write := not SaveSystem.write_blocked
	import_btn.disabled = not can_write; paste_btn.disabled = not can_write; reset_btn.disabled = not can_write
	msg_label.text = _msg

func _say(text: String) -> void:
	_msg = text
	if msg_label:
		msg_label.text = text

# ---------- 导出 ----------
func do_export() -> void:
	last_export_text = SaveSystem.export_string()
	if SaveSystem.is_web():
		JavaScriptBridge.download_buffer(last_export_text.to_utf8_buffer(), SaveSystem.export_file_name(), "application/json")
		_say(UiText.t("MSG_EXPORT_DONE"))
		return
	_file_dialog(FileDialog.FILE_MODE_SAVE_FILE, func(p: String) -> void:
		if export_to_path(p):
			_say(UiText.t("MSG_EXPORT_DONE")))

func export_to_path(p: String) -> bool:
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(last_export_text if last_export_text != "" else SaveSystem.export_string())
	f.close()
	return true

func do_copy() -> void:
	last_export_text = SaveSystem.export_string()
	DisplayServer.clipboard_set(last_export_text)
	_say(UiText.t("MSG_COPY_DONE"))

# ---------- 导入 ----------
func do_import() -> void:
	if SaveSystem.is_web():
		_web_pick_file()
		return
	_file_dialog(FileDialog.FILE_MODE_OPEN_FILE, func(p: String) -> void:
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			import_text(""); return
		if f.get_length() > SaveCodec.MAX_BYTES:
			import_text("x".repeat(SaveCodec.MAX_BYTES + 1)); return
		import_text(f.get_as_text()))

func do_paste() -> void:
	import_text(DisplayServer.clipboard_get())

## 所有导入入口汇总到这里：预检 → 两次确认 → 替换
func import_text(text: String) -> void:
	if text.strip_edges() == "":
		_fail("IMPORT_ERR_EMPTY"); return
	var pre := SaveSystem.check_import(text)
	if not pre.ok:
		_fail(import_error_key(str(pre.code))); return
	dialog.ask({"title": UiText.t("TITLE_CONFIRM"), "text": UiText.t("CONFIRM_IMPORT_1"), "ok": UiText.t("BTN_CONFIRM")},
		func() -> void:
			var r := SaveSystem.import_string(text)
			if r.ok:
				_say(UiText.t("MSG_IMPORT_DONE"))
				progress_replaced.emit("import")
				dialog.info(UiText.t("TITLE_SAVE_NOTICE"), UiText.t("MSG_IMPORT_DONE"))
			else:
				_fail(import_error_key(str(r.code)))
			refresh(),
		{"title": UiText.t("TITLE_CONFIRM_AGAIN"), "text": UiText.t("CONFIRM_IMPORT_2"), "ok": UiText.t("BTN_CONFIRM_IMPORT")})

static func import_error_key(code: String) -> String:
	var k := "IMPORT_ERR_" + code.to_upper()
	return k if UiText.has(k) else "IMPORT_ERR_PARSE"

func _fail(err_key: String) -> void:
	var t := UiText.t("MSG_IMPORT_FAIL", {"reason": UiText.t(err_key)})
	_say(t)
	if dialog:
		dialog.info(UiText.t("TITLE_SAVE_NOTICE"), t)

# ---------- 重置 ----------
func do_reset() -> void:
	dialog.ask({"title": UiText.t("TITLE_CONFIRM"), "text": UiText.t("CONFIRM_RESET_1"), "ok": UiText.t("BTN_CONFIRM")},
		func() -> void:
			SaveSystem.reset_game()
			_say(UiText.t("MSG_RESET_DONE"))
			progress_replaced.emit("reset")
			refresh(),
		{"title": UiText.t("TITLE_CONFIRM_AGAIN"), "text": UiText.t("CONFIRM_RESET_2"), "ok": UiText.t("BTN_CONFIRM_RESET")})

# ---------- 平台 ----------
func _file_dialog(mode: int, cb: Callable) -> void:
	if file_dialog:
		file_dialog.queue_free()
	file_dialog = FileDialog.new()
	file_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = mode
	file_dialog.use_native_dialog = true
	file_dialog.filters = PackedStringArray(["*.json"])
	file_dialog.title = UiText.t("BTN_EXPORT_SAVE" if mode == FileDialog.FILE_MODE_SAVE_FILE else "BTN_IMPORT_SAVE")
	if mode == FileDialog.FILE_MODE_SAVE_FILE:
		file_dialog.current_file = SaveSystem.export_file_name()
	file_dialog.file_selected.connect(cb)
	add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(900, 600))

## Web：隐藏 <input type=file>（需在用户点击后的瞬时激活窗口内调用），读成文本经回调交回
func _web_pick_file() -> void:
	JavaScriptBridge.eval("""
window.__rxPickSave = window.__rxPickSave || function (cb) {
  var i = document.createElement('input'); i.type = 'file'; i.accept = '.json,application/json,text/plain';
  i.style.display = 'none'; document.body.appendChild(i);
  i.onchange = function () {
    var f = i.files && i.files[0]; i.remove();
    if (!f) { cb(''); return; }
    if (f.size > %d) { cb('__TOO_BIG__'); return; }
    var r = new FileReader(); r.onload = function () { cb(String(r.result)); }; r.onerror = function () { cb(''); };
    r.readAsText(f);
  };
  i.click();
};""" % SaveCodec.MAX_BYTES, true)
	_js_cb = JavaScriptBridge.create_callback(func(args: Array) -> void:
		var t := str(args[0]) if args.size() > 0 else ""
		import_text("x".repeat(SaveCodec.MAX_BYTES + 1) if t == "__TOO_BIG__" else t))
	JavaScriptBridge.get_interface("window").__rxPickSave(_js_cb)

class_name ConfirmDialog
extends Control
## 确认 / 提示框（阶段6，v2 宣纸水墨风格）：全屏压暗 + 居中小面板（标题、正文、按钮），最上层，暂停中照常响应。
## ask()：可两步确认（second 非空时第一步“确定”后进入第二步；第二步确认键延迟 ARM_SEC 秒才可点，防连点穿透）。
## info()：单按钮提示（存档损坏 / 恢复 / 导入结果等）。Esc / 取消 = 不执行。

signal finished(confirmed: bool)

const ARM_SEC := 0.8

var title_label: Label
var text_label: Label
var ok_btn: Button
var cancel_btn: Button
var step := 0
var arm_t := 0.0
var _second := {}
var _on_ok := Callable()
var _box: PanelContainer
var _queue: Array = []   # 排队的 info（启动时可能有多条提示）

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	name = "ConfirmDialog"

func _ready() -> void:
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.55); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new(); cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(cc)
	_box = PanelContainer.new(); _box.add_theme_stylebox_override("panel", UiStyle.big_panel())
	_box.custom_minimum_size = Vector2(520, 0)
	cc.add_child(_box)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 14); _box.add_child(v)
	title_label = UiStyle.title("", 32); title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(title_label)
	v.add_child(UiStyle.hsep(0.6))
	text_label = UiStyle.label("", 18, UiStyle.MIST); text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; text_label.custom_minimum_size = Vector2(470, 0)
	v.add_child(text_label)
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 18); v.add_child(row)
	cancel_btn = UiStyle.button(UiText.t("BTN_CANCEL"), 18); cancel_btn.custom_minimum_size = Vector2(140, 42); cancel_btn.name = "Cancel"
	cancel_btn.pressed.connect(cancel)
	row.add_child(cancel_btn)
	ok_btn = UiStyle.accent_button(UiText.t("BTN_CONFIRM"), 18); ok_btn.custom_minimum_size = Vector2(160, 42); ok_btn.name = "Ok"
	ok_btn.pressed.connect(confirm)
	row.add_child(ok_btn)
	_box.add_child(InkFrame.new())

## 两步确认：first = {title, text, ok}；second 同结构（空 = 一步）
func ask(first: Dictionary, on_ok: Callable, second: Dictionary = {}) -> void:
	_on_ok = on_ok
	_second = second
	step = 1
	_show(first, true)

func info(title: String, text: String) -> void:
	if visible:
		_queue.append([title, text])
		return
	_on_ok = Callable()
	_second = {}
	step = 0
	_show({"title": title, "text": text, "ok": UiText.t("BTN_OK")}, false)

func _show(d: Dictionary, with_cancel: bool) -> void:
	title_label.text = str(d.get("title", UiText.t("TITLE_CONFIRM")))
	text_label.text = str(d.get("text", ""))
	ok_btn.text = str(d.get("ok", UiText.t("BTN_CONFIRM")))
	cancel_btn.visible = with_cancel
	arm_t = ARM_SEC if step == 2 else 0.0
	ok_btn.disabled = arm_t > 0.0
	visible = true
	UiStyle.pop_in(_box)

func confirm() -> void:
	if not visible or ok_btn.disabled:
		return
	if step == 1 and not _second.is_empty():
		step = 2
		_show(_second, true)
		return
	var cb := _on_ok
	_close(true)
	if cb.is_valid():
		cb.call()

func cancel() -> void:
	if visible:
		_close(false)

func _close(ok: bool) -> void:
	visible = false
	step = 0
	_on_ok = Callable()
	finished.emit(ok)
	if not _queue.is_empty():
		var q: Array = _queue.pop_front()
		info(q[0], q[1])

func _process(delta: float) -> void:
	if visible and arm_t > 0.0:
		arm_t -= delta
		if arm_t <= 0.0:
			ok_btn.disabled = false

## Esc：有“取消”则取消，否则等同“知道了”（HUD._input 调用）
func escape() -> void:
	if cancel_btn.visible:
		cancel()
	elif not ok_btn.disabled:
		confirm()

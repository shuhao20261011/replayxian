class_name FirstClearCard
extends PanelContainer
## 首通奖励卡片（阶段5）：首通结算时在横幅下方弹出，列出本次首通的全部奖励
## （图标 + 品质框 + 名称，名称颜色 = 品质色；数据为 LootSystem.apply 的显示条目）。不暂停战斗，
## SHOW_TIME 秒后淡出，点击立即收起。

const SHOW_TIME := 6.0
const SLOT := 64.0

var title_label: Label
var items_box: HBoxContainer
var _t := 0.0

func _ready() -> void:
	name = "FirstClearCard"
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UiStyle.big_panel())
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); add_child(v)
	title_label = UiStyle.title("", 30, Color("#E9C46A")); title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title_label)
	v.add_child(UiStyle.hsep(0.5))
	items_box = HBoxContainer.new(); items_box.alignment = BoxContainer.ALIGNMENT_CENTER; items_box.add_theme_constant_override("separation", 14)
	v.add_child(items_box)
	add_child(InkFrame.new())
	visible = false

## entries：[{text, color, icon, quality}]
func show_rewards(level_name: String, entries: Array) -> void:
	title_label.text = "%s　%s" % [UiText.t("TITLE_FIRST_CLEAR"), level_name]
	for c in items_box.get_children():
		items_box.remove_child(c); c.queue_free()
	for e in entries:
		items_box.add_child(_item(e))
	visible = true
	modulate.a = 1.0
	_t = SHOW_TIME
	reset_size()
	UiStyle.pop_in(self)

func _item(e: Dictionary) -> Control:
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 2)
	v.custom_minimum_size = Vector2(96, 0)
	var holder := Control.new(); holder.custom_minimum_size = Vector2(SLOT, SLOT); holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(holder)
	var q := int(e.get("quality", 0))
	var bg := Panel.new(); bg.add_theme_stylebox_override("panel", ArtUi.box("ui_slot_9p")); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(bg)
	var ic := TextureRect.new(); ic.texture = ArtUi.item_icon(str(e.get("icon", "")))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ic.offset_left = 8; ic.offset_top = 8; ic.offset_right = -8; ic.offset_bottom = -8
	holder.add_child(ic)
	if q > 0:
		var fr := TextureRect.new(); fr.texture = ArtUi.quality_frame(q)
		fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; fr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(fr)
	var l := UiStyle.label(str(e.get("text", "")), 13, e.get("color", UiStyle.GOLD_TEXT))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(96, 0)
	v.add_child(l)
	return v

func _process(delta: float) -> void:
	if not visible:
		return
	_t -= delta
	if _t < 0.6:
		modulate.a = clampf(_t / 0.6, 0.0, 1.0)
	if _t <= 0.0:
		visible = false

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		_t = minf(_t, 0.6)
		accept_event()

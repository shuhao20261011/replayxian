class_name OrangeRewardCard
extends PanelContainer
## 终关首通核心橙装三选一 —— 自动挂机版（阶段5 制作人决定）：
## 自动战斗开启时不暂停挂机，弹出这张非阻塞卡片（三件橙装图标 + 名称、倒计时、“现在选择”“稍后再选”）。
## 倒计时结束自动按“稍后再选”收起：待选保留在 PlayerState.pending_orange_choices，【装】按钮红点一直亮到选完。
## “现在选择”交给 HUD 打开原来的模态三选一（暂停）。手动模式不走这里，直接弹模态（HUD 负责）。
## 时长：常量 ORANGE_CHOICE_AUTO_LATER_SEC（代码默认 AUTO_LATER_SEC_DEFAULT）。

signal choose_now
signal later(auto: bool)   # auto=true：倒计时到点自动收起；false：玩家点了“稍后再选”

const AUTO_LATER_SEC_DEFAULT := 8.0
const SLOT := 64.0

var title_label: Label
var items_box: HBoxContainer
var countdown_label: Label
var now_btn: Button
var later_btn: Button
var time_left := 0.0

static func auto_later_sec() -> float:
	return maxf(GameData.const_f("ORANGE_CHOICE_AUTO_LATER_SEC", AUTO_LATER_SEC_DEFAULT), 1.0)

func _ready() -> void:
	name = "OrangeRewardCard"
	process_mode = Node.PROCESS_MODE_PAUSABLE   # 暂停（打开面板）时倒计时也停
	add_theme_stylebox_override("panel", UiStyle.big_panel())
	mouse_filter = Control.MOUSE_FILTER_STOP
	var top: QualityDef = GameData.qualities_ordered().back()
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); add_child(v)
	title_label = UiStyle.title(UiText.t("TITLE_ORANGE_CHOICE"), 30, top.color.lightened(0.15)); title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title_label)
	v.add_child(UiStyle.hsep(0.5))
	items_box = HBoxContainer.new(); items_box.alignment = BoxContainer.ALIGNMENT_CENTER; items_box.add_theme_constant_override("separation", 14)
	v.add_child(items_box)
	countdown_label = UiStyle.label("", 14, Color(UiStyle.MIST, 0.8)); countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(countdown_label)
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	now_btn = UiStyle.accent_button(UiText.t("BTN_CHOOSE_NOW"), 18); now_btn.name = "ChooseNow"; now_btn.custom_minimum_size = Vector2(130, 38)
	now_btn.pressed.connect(func() -> void: visible = false; choose_now.emit())
	row.add_child(now_btn)
	later_btn = UiStyle.button(UiText.t("BTN_CHOOSE_LATER"), 18); later_btn.name = "Later"; later_btn.custom_minimum_size = Vector2(130, 38)
	later_btn.pressed.connect(func() -> void: resolve_later(false))
	row.add_child(later_btn)
	add_child(InkFrame.new())
	visible = false

## 显示第 gi 组待选；没有则返回 false
func open(gi: int = 0) -> bool:
	if gi < 0 or gi >= PlayerState.pending_orange_choices.size():
		return false
	var top: QualityDef = GameData.qualities_ordered().back()
	for c in items_box.get_children():
		items_box.remove_child(c); c.queue_free()
	for bid in PlayerState.pending_orange_choices[gi]:
		items_box.add_child(_item(str(bid), top))
	time_left = auto_later_sec()
	_update_countdown()
	visible = true
	modulate.a = 1.0
	reset_size()
	UiStyle.pop_in(self)
	return true

func resolve_later(auto: bool) -> void:
	if not visible:
		return
	visible = false
	later.emit(auto)

func _update_countdown() -> void:
	countdown_label.text = UiText.t("HINT_ORANGE_AUTO_LATER", {"sec": int(ceil(maxf(time_left, 0.0)))})

func _item(base_id: String, top: QualityDef) -> Control:
	var base := GameData.get_base(base_id)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 2); v.name = "Item_" + base_id
	v.custom_minimum_size = Vector2(96, 0)
	var holder := Control.new(); holder.custom_minimum_size = Vector2(SLOT, SLOT); holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(holder)
	var bg := Panel.new(); bg.add_theme_stylebox_override("panel", ArtUi.box("ui_slot_9p")); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(bg)
	var ic := TextureRect.new(); ic.texture = ArtUi.item_icon(base_id)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ic.offset_left = 8; ic.offset_top = 8; ic.offset_right = -8; ic.offset_bottom = -8
	holder.add_child(ic)
	var fr := TextureRect.new(); fr.texture = ArtUi.quality_frame(top.order)
	fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; fr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(fr)
	var l := UiStyle.label(base.name if base else base_id, 13, top.color.lightened(0.15))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(96, 0)
	v.add_child(l)
	return v

func _process(delta: float) -> void:
	if not visible:
		return
	time_left -= delta
	_update_countdown()
	if time_left <= 0.0:
		resolve_later(true)

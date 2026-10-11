class_name OrangeChoiceDialog
extends Control
## 终关首通：核心橙装三选一（阶段5）。全屏遮罩 + 居中对话框，三张卡片：
## 橙框图标、名称（橙色）、所属功法与部位、橙色品质下的基础属性、随机词条数、核心特效名与说明、“择此件”。
## “稍后再选”关闭对话框，选择仍保留在装备面板（PlayerState.pending_orange_choices）。
## 数据：equip_bases（核心底子）/ orange_effects / qualities（最高品质）/ gongfa / equip_slots / affixes（属性名）。打开时暂停（HUD 负责）。

signal closed
signal chosen(base_id: String)

var group_index := 0
var cards: HBoxContainer

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.6); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

func open(gi: int = 0) -> bool:
	if gi < 0 or gi >= PlayerState.pending_orange_choices.size():
		return false
	group_index = gi
	for c in get_children():
		if c is PanelContainer:
			remove_child(c); c.queue_free()
	var top: QualityDef = GameData.qualities_ordered().back()
	var pc := PanelContainer.new(); pc.name = "Dialog"
	pc.add_theme_stylebox_override("panel", UiStyle.big_panel())
	pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pc.grow_horizontal = Control.GROW_DIRECTION_BOTH; pc.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(pc)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); pc.add_child(v)
	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 14); v.add_child(head)
	head.add_child(UiStyle.title(UiText.t("TITLE_ORANGE_CHOICE"), 38, top.color.lightened(0.15)))
	var sub := UiStyle.subtitle(UiText.t("SUB_ORANGE_CHOICE"), 20, Color(UiStyle.GOLD_TEXT, 0.75)); sub.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(sub)
	v.add_child(UiStyle.hsep(0.6))
	cards = HBoxContainer.new(); cards.add_theme_constant_override("separation", 14); v.add_child(cards)
	for bid in PlayerState.pending_orange_choices[gi]:
		cards.add_child(_card(str(bid), top))
	var later := UiStyle.button(UiText.t("BTN_CHOOSE_LATER"), 18); later.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	later.custom_minimum_size = Vector2(160, 40)
	later.pressed.connect(func() -> void: visible = false; closed.emit())
	v.add_child(later)
	pc.add_child(InkFrame.new())
	visible = true
	UiStyle.pop_in(pc)
	return true

func _card(base_id: String, top: QualityDef) -> Control:
	var base := GameData.get_base(base_id)
	var preview := GearItem.new(); preview.base_id = base_id; preview.quality_id = top.id
	var oe := preview.orange_effect()
	var pc := PanelContainer.new(); pc.name = "Card_" + base_id
	var sb := UiStyle.section(); sb.border_color = Color(top.color, 0.85); sb.set_border_width_all(2)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(300, 400)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); pc.add_child(v)
	var icon_holder := Control.new(); icon_holder.custom_minimum_size = Vector2(0, 112); v.add_child(icon_holder)
	var frame := TextureRect.new(); frame.texture = ArtUi.quality_frame(top.order)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER); frame.custom_minimum_size = Vector2(108, 108)
	frame.offset_left = -54; frame.offset_right = 54; frame.offset_top = -54; frame.offset_bottom = 54
	icon_holder.add_child(frame)
	var ic := TextureRect.new(); ic.texture = ArtUi.item_icon(base_id)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ic.offset_left = -44; ic.offset_right = 44; ic.offset_top = -44; ic.offset_bottom = 44
	icon_holder.add_child(ic)
	icon_holder.move_child(ic, 0)
	var n := UiStyle.title(base.name if base else base_id, 30, top.color.lightened(0.15)); n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var gf: GongfaDef = GameData.gongfa.get(base.gongfa_id) if base else null
	var slot_name := ""
	for s in GameData.equip_slots:
		if base and s.slot_id == base.slot_id:
			slot_name = str(s.name)
	var meta := UiStyle.label("%s　%s" % [gf.name if gf else "", slot_name], 14, Color(UiStyle.GOLD_TEXT, 0.8))
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(meta)
	v.add_child(UiStyle.hsep(0.3))
	var bs := preview.base_stats()
	for k in ["atk", "hp", "def"]:
		if float(bs.get(k, 0.0)) > 0.0:
			PanelKit.kv(v, GameData.stat_name(k), UiStyle.num(float(bs[k])))
	if top.affix_count > 0:
		v.add_child(UiStyle.label(UiText.t("LABEL_ORANGE_AFFIX", {"count": top.affix_count}), 14, Color(UiStyle.MIST, 0.75)))
	v.add_child(UiStyle.hsep(0.3))
	if oe:
		v.add_child(UiStyle.subtitle(oe.name, 20, top.color.lightened(0.2)))
		var d := UiStyle.label(oe.desc, 14, UiStyle.MIST); d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(268, 0)
		v.add_child(d)
	v.add_child(UiStyle.spacer())
	var b := UiStyle.accent_button(UiText.t("BTN_CHOOSE"), 20); b.name = "Choose"
	b.custom_minimum_size = Vector2(150, 44); b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: choose(base_id))
	v.add_child(b)
	return pc

func choose(base_id: String) -> String:
	var code := PlayerState.choose_orange(group_index, base_id)
	if code == "ok":
		visible = false
		chosen.emit(base_id)
		closed.emit()
	return code

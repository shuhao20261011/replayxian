class_name OfflinePanel
extends Control
## 闭关（离线）收益领取页（阶段6，v2 宣纸水墨风格）：启动结算出 PlayerState.pending_offline 时由 HUD 弹出（暂停）。
## 标题 OFFLINE_TITLE（闭关N分钟）、副标题 OFFLINE_SUB（按最近已通关关卡结算），逐项图标：灵石 / 修为 / 材料 / 技能书 / 装备（按品质汇总）；
## 达到上限显示 OFFLINE_CAPPED；背包放不下时预告 OFFLINE_BAG_OVERFLOW（溢出转炼器材料）。只有“收下”一个出口（Esc 不关），领取后立即存档。

signal claimed(result: Dictionary)

const SLOT := 64.0

var title_label: Label
var sub_label: Label
var items_box: HFlowContainer
var note_label: Label
var claim_btn: Button
var _box: PanelContainer

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	name = "OfflinePanel"

func _ready() -> void:
	var dim := ColorRect.new(); dim.color = Color(0.03, 0.04, 0.03, 0.6); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new(); cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(cc)
	_box = PanelContainer.new(); _box.add_theme_stylebox_override("panel", UiStyle.big_panel())
	_box.custom_minimum_size = Vector2(640, 0)
	cc.add_child(_box)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12); _box.add_child(v)
	var seal := UiStyle.medallion(UiText.t("OFFLINE_TITLE", {"minutes": 0}).left(1), 72, 34)   # 圆章单字取标题首字
	seal.disabled = true; seal.focus_mode = Control.FOCUS_NONE; seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(seal)
	title_label = UiStyle.title("", 38, Color("#E9C46A")); title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title_label)
	sub_label = UiStyle.subtitle("", 18, Color(UiStyle.GOLD_TEXT, 0.75)); sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub_label)
	v.add_child(UiStyle.hsep(0.6))
	items_box = HFlowContainer.new(); items_box.alignment = FlowContainer.ALIGNMENT_CENTER
	items_box.add_theme_constant_override("h_separation", 14); items_box.add_theme_constant_override("v_separation", 10)
	items_box.custom_minimum_size = Vector2(600, 0)
	v.add_child(items_box)
	note_label = UiStyle.label("", 15, Color(UiStyle.MIST, 0.85)); note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; note_label.custom_minimum_size = Vector2(600, 0)
	v.add_child(note_label)
	claim_btn = UiStyle.accent_button(UiText.t("OFFLINE_BTN_CLAIM"), 26); claim_btn.name = "Claim"
	claim_btn.add_theme_font_override("font", UiStyle.TITLE_FONT)
	claim_btn.custom_minimum_size = Vector2(200, 52); claim_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	claim_btn.pressed.connect(do_claim)
	v.add_child(claim_btn)
	_box.add_child(InkFrame.new())

## 显示当前 pending；没有则返回 false
func open() -> bool:
	var p: Dictionary = PlayerState.pending_offline
	if p.is_empty() or int(p.get("minutes", 0)) <= 0:
		return false
	title_label.text = UiText.t("OFFLINE_TITLE", {"minutes": int(p.minutes)})
	var l := GameData.get_level(str(p.level_id))
	sub_label.text = UiText.t("OFFLINE_SUB", {"level_name": l.name if l else ""})
	for c in items_box.get_children():
		items_box.remove_child(c); c.queue_free()
	if int(p.lingshi) > 0:
		items_box.add_child(_item("CUR_LINGSHI", UiText.t("FLOAT_LINGSHI", {"value": int(p.lingshi)}), Color(1, 0.86, 0.4), 0))
	if int(p.xiuwei) > 0:
		items_box.add_child(_item("CUR_XIUWEI", UiText.t("FLOAT_XIUWEI", {"value": int(p.xiuwei)}), Color(0.6, 0.85, 1), 0))
	for k in p.items:
		items_box.add_child(_item(str(k), UiText.t("LOOT_ITEM_COUNT", {"item_name": GameData.material_name(str(k)), "count": int(p.items[k])}), Color(0.8, 0.9, 0.8), 0))
	for k in p.books:
		var bk := GameData.get_book(str(k))
		var t := (bk.name if bk else str(k)) + ("×%d" % int(p.books[k]) if int(p.books[k]) > 1 else "")
		items_box.add_child(_item(str(k), t, Color(0.75, 0.6, 1), 4))
	# 装备：按品质汇总，图标用该品质里第一件
	var by_q := {}
	for gd in p.gear:
		var q := str(gd.quality_id)
		if not by_q.has(q):
			by_q[q] = [gd, 0]
		by_q[q][1] += 1
	for q: QualityDef in GameData.qualities_ordered():
		if by_q.has(q.id):
			var first: Dictionary = by_q[q.id][0]
			items_box.add_child(_item(str(first.base_id), "%s　%s" % [q.name, UiText.t("OFFLINE_GEAR_COUNT", {"count": int(by_q[q.id][1])})], q.color, q.order))
	var notes: Array[String] = []
	if bool(p.get("capped", false)):
		notes.append(UiText.t("OFFLINE_CAPPED", {"hours": int(OfflineSystem.cap_minutes() / 60)}))
	var of := OfflineSystem.overflow_preview(p)
	if of > 0:
		notes.append(UiText.t("OFFLINE_BAG_OVERFLOW", {"count": of, "item_name": GameData.material_name("MAT_REFINE")}))
	note_label.text = "\n".join(notes)
	note_label.visible = not notes.is_empty()
	claim_btn.disabled = false
	visible = true
	UiStyle.pop_in(_box)
	return true

func do_claim() -> Dictionary:
	claim_btn.disabled = true   # 防连点
	var r := OfflineSystem.claim()
	visible = false
	claimed.emit(r)
	return r

func _item(icon_id: String, text: String, color: Color, quality: int) -> Control:
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 2)
	v.custom_minimum_size = Vector2(104, 0)
	var holder := Control.new(); holder.custom_minimum_size = Vector2(SLOT, SLOT); holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(holder)
	var bg := Panel.new(); bg.add_theme_stylebox_override("panel", ArtUi.box("ui_slot_9p")); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(bg)
	var ic := TextureRect.new(); ic.texture = ArtUi.item_icon(icon_id)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ic.offset_left = 8; ic.offset_top = 8; ic.offset_right = -8; ic.offset_bottom = -8
	holder.add_child(ic)
	if quality > 0:
		var fr := TextureRect.new(); fr.texture = ArtUi.quality_frame(quality)
		fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; fr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(fr)
	var l := UiStyle.label(text, 13, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(104, 0)
	v.add_child(l)
	return v

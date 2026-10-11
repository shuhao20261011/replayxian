class_name GearPanel
extends PanelContainer
## 装备面板（阶段4，v2 宣纸水墨风格）：已装备 6 槽 + 角色属性 / 背包（品质排序、推荐箭头）/
## 详情（基础属性与当前装备对比、核心特效、逐条重铸、装备/分解）/ 批量分解与按品质自动分解 / 终关核心橙装三选一。
## 数值与文案全部来自表（qualities / affixes / gear_tiers / equip_bases / orange_effects / materials / ui_texts）。打开时战斗暂停（HUD 负责）。

signal closed

## 详情与左栏显示的基础属性（属性名取 affixes 表；移动速度取待收编文案）
const BASE_STATS := ["atk", "hp", "def", "crit_rate", "move_speed"]
const PCT_STATS := ["crit_rate", "crit_dmg", "reflect_pct"]

var selected_uid := 0
var _msg := ""
var slots_box: VBoxContainer
var stats_box: VBoxContainer
var bag_box: VBoxContainer
var bag_cap: Label
var detail_box: VBoxContainer
var footer: HBoxContainer
var res_box: HBoxContainer
var msg_label: Label

func _ready() -> void:
	var k := PanelKit.shell(self, Hud.panel_title_text("gear"), UiText.t("PANEL_SUB_GEAR"))
	(k.close as Button).pressed.connect(func() -> void: closed.emit())
	res_box = HBoxContainer.new(); res_box.add_theme_constant_override("separation", 14)
	(k.head as HBoxContainer).add_child(res_box)
	(k.head as HBoxContainer).move_child(res_box, 3)
	var body: VBoxContainer = k.body
	var cols := HBoxContainer.new(); cols.size_flags_vertical = Control.SIZE_EXPAND_FILL; cols.add_theme_constant_override("separation", 12)
	body.add_child(cols)
	var left := PanelKit.section(cols, UiText.t("LABEL_EQUIPPED"), 300)
	slots_box = VBoxContainer.new(); slots_box.add_theme_constant_override("separation", 4); left.add_child(slots_box)
	left.add_child(UiStyle.hsep(0.3))
	left.add_child(UiStyle.subtitle(UiText.t("LABEL_STATS"), 20))
	stats_box = VBoxContainer.new(); stats_box.add_theme_constant_override("separation", 2); left.add_child(stats_box)
	var mid := PanelKit.section(cols, "", 330)
	var mh := HBoxContainer.new(); mid.add_child(mh)
	mh.add_child(UiStyle.subtitle(UiText.t("LABEL_BAG"), 22)); mh.add_child(UiStyle.spacer())
	bag_cap = UiStyle.label("", 14, Color(UiStyle.GOLD_TEXT, 0.75)); bag_cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER; mh.add_child(bag_cap)
	bag_box = PanelKit.scroll(mid)
	var right := PanelKit.section(cols, UiText.t("LABEL_DETAIL"), 0, true)
	detail_box = PanelKit.scroll(right)
	var fpc := PanelContainer.new(); fpc.add_theme_stylebox_override("panel", UiStyle.section()); body.add_child(fpc)
	footer = HBoxContainer.new(); footer.add_theme_constant_override("separation", 8); fpc.add_child(footer)
	msg_label = UiStyle.label("", 16, UiStyle.GOLD_TEXT)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(msg_label)
	PlayerState.inventory_changed.connect(_refresh_if_visible)
	PlayerState.currencies_changed.connect(_refresh_if_visible)

func open() -> void:
	_msg = ""
	visible = true
	refresh()

func _refresh_if_visible() -> void:
	if visible:
		refresh.call_deferred()

func select(uid: int) -> void:
	selected_uid = uid
	refresh()

func _say(result: String, ok_text: String) -> void:
	_msg = PanelKit.result_text(result, ok_text)
	refresh()
	msg_label.modulate = Color(1.6, 1.4, 1.0)
	var tw := msg_label.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(msg_label, "modulate", Color.WHITE, 0.5)

func _sorted_bag() -> Array[GearItem]:
	var out: Array[GearItem] = []
	out.assign(PlayerState.bag)
	out.sort_custom(func(a: GearItem, b: GearItem) -> bool:
		if a.quality().order != b.quality().order:
			return a.quality().order > b.quality().order
		if a.tier() != b.tier():
			return a.tier() > b.tier()
		return a.uid > b.uid)
	return out

func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c); c.queue_free()

func _res_pill(kind: String, text: String) -> PanelContainer:
	var pc := PanelContainer.new(); pc.add_theme_stylebox_override("panel", UiStyle.pill_box(32))
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 6); pc.add_child(h)
	if kind != "":
		h.add_child(GlyphIcon.new(kind, 24))
	h.add_child(UiStyle.label(text, 16, UiStyle.GOLD_TEXT))
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return pc

static func stat_value_text(stat: String, v: float) -> String:
	return UiText.fmt(v, "pct") if stat in PCT_STATS else UiStyle.num(v)

func refresh() -> void:
	for box in [slots_box, stats_box, bag_box, detail_box, footer, res_box]:
		_clear(box)
	res_box.add_child(_res_pill("jade", UiText.t("HUD_LINGSHI", {"value": PlayerState.lingshi})))
	res_box.add_child(_res_pill("", "%s　%s" % [GameData.material_name("MAT_REFINE"), UiStyle.num(PlayerState.item_count("MAT_REFINE"))]))
	bag_cap.text = "%d / %d" % [PlayerState.bag.size(), PlayerState.bag_capacity()]
	msg_label.text = _msg
	# 已装备
	for sl in GameData.equip_slots:
		var g: GearItem = PlayerState.equipped.get(sl.slot_id)
		var b := PanelKit.row("%s　%s" % [sl.name, g.display_name() if g else "—"], g.color() if g else Color(0.4, 0.4, 0.4), g != null and g.uid == selected_uid, 15, g.color() if g else Color(0.6, 0.6, 0.55))
		if g:
			var uid := g.uid
			b.pressed.connect(func() -> void: select(uid))
		else:
			b.disabled = true
		slots_box.add_child(b)
	var st := PlayerState.combat_stats()
	for k in [["atk", st.atk], ["hp", st.max_hp], ["def", st.def], ["crit_rate", st.crit_rate], ["crit_dmg", st.crit_dmg]]:
		PanelKit.kv(stats_box, GameData.stat_name(k[0]), stat_value_text(k[0], float(k[1])))
	if float(st.reflect) > 0.0:
		PanelKit.kv(stats_box, GameData.stat_name("reflect_pct"), stat_value_text("reflect_pct", float(st.reflect)))
	# 终关首通：核心橙装三选一
	for gi in PlayerState.pending_orange_choices.size():
		var top: QualityDef = GameData.qualities_ordered().back()
		stats_box.add_child(UiStyle.hsep(0.3))
		stats_box.add_child(UiStyle.subtitle(UiText.t("LOOT_ORANGE_CHOICE"), 18, top.color))
		for bid in PlayerState.pending_orange_choices[gi]:
			var base := GameData.get_base(bid)
			var oe := GameData.orange_effects.get(base.orange_effect_id) as OrangeEffectDef if base else null
			var cb := PanelKit.row(UiText.t("BTN_CHOOSE_ORANGE", {"equip_name": base.name if base else "", "effect_name": oe.name if oe else ""}), top.color, false, 14, top.color.lightened(0.2))
			cb.tooltip_text = oe.desc if oe else ""
			var idx := gi; var b_id: String = bid
			cb.pressed.connect(func() -> void: _say(PlayerState.choose_orange(idx, b_id), UiText.t("TOAST_ORANGE_GOT", {"equip_name": base.name if base else ""})))
			stats_box.add_child(cb)
	# 背包
	if PlayerState.bag.is_empty():
		var e := UiStyle.label(UiText.t("LABEL_BAG_EMPTY"), 15, Color(UiStyle.GOLD_TEXT, 0.55))
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bag_box.add_child(e)
	for g in _sorted_bag():
		var cmp := PlayerState.compare_gear(g)
		var b := PanelKit.row(g.display_name(), g.color(), g.uid == selected_uid, 15, g.color().lightened(0.15))
		var sl := UiStyle.label(GameData.slot_name(g.slot_id()), 13, Color(UiStyle.GOLD_TEXT, 0.6))
		sl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		sl.grow_horizontal = Control.GROW_DIRECTION_BEGIN; sl.grow_vertical = Control.GROW_DIRECTION_BOTH
		sl.offset_right = -34; sl.offset_left = -34
		b.add_child(sl)
		if cmp.recommended:
			var ar := GlyphIcon.new("arrow_up", 18)
			ar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
			ar.offset_left = -26; ar.offset_right = -8; ar.offset_top = -9; ar.offset_bottom = 9
			ar.tooltip_text = UiText.t("TIP_RECOMMENDED")
			b.add_child(ar)
		var uid := g.uid
		b.pressed.connect(func() -> void: select(uid))
		bag_box.add_child(b)
	if PlayerState.find_gear(selected_uid) == null:
		var sb := _sorted_bag()
		selected_uid = sb[0].uid if not sb.is_empty() else 0
		if selected_uid != 0:
			refresh.call_deferred()
	_build_detail()
	_build_footer()

func _build_detail() -> void:
	var g := PlayerState.find_gear(selected_uid)
	if g == null:
		detail_box.add_child(UiStyle.label(UiText.t("LABEL_SELECT_GEAR"), 15, Color(UiStyle.GOLD_TEXT, 0.55)))
		return
	var equipped := PlayerState.is_equipped(g)
	var name_row := HBoxContainer.new(); name_row.add_theme_constant_override("separation", 14); detail_box.add_child(name_row)
	name_row.add_child(UiStyle.title(g.base().name if g.base() else "", 32, g.color()))
	var tag := UiStyle.label(UiText.t("LABEL_GEAR_TAG", {"quality_name": g.quality().name, "slot_name": GameData.slot_name(g.slot_id()), "tier": g.tier()}), 14, Color(UiStyle.GOLD_TEXT, 0.75))
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(tag)
	if equipped:
		var el := UiStyle.plaque(UiText.t("LABEL_EQUIPPED"), 13); el.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_row.add_child(el)
	if g.base() and g.base().desc != "":
		detail_box.add_child(UiStyle.label(g.base().desc, 14, Color(UiStyle.MIST, 0.7)))
	detail_box.add_child(UiStyle.hsep(0.3))
	var bs := g.base_stats()
	var cmp := PlayerState.compare_gear(g)
	for k: String in BASE_STATS:
		var val := float(bs.get(k, 0.0))
		var dv := float(cmp.get(k, 0.0))
		if val == 0.0 and dv == 0.0:
			continue
		var dt := ""
		if not equipped and absf(dv) > 0.0001:
			dt = ("↑" if dv > 0 else "↓") + (UiText.fmt(absf(dv), "pct") if k in PCT_STATS else str(int(round(absf(dv)))))
		PanelKit.kv(detail_box, GameData.stat_name(k), stat_value_text(k, val), UiStyle.MIST, dt, UiStyle.GOOD if dv > 0 else UiStyle.BAD)
	var oe := g.orange_effect()
	if oe:
		var op := PanelContainer.new()
		var osb := UiStyle.panel(6, g.color(), 0.6); osb.bg_color = Color(g.color().darkened(0.75), 0.75)
		op.add_theme_stylebox_override("panel", osb)
		var ov := VBoxContainer.new(); op.add_child(ov)
		ov.add_child(UiStyle.subtitle(oe.name, 20, g.color().lightened(0.25)))
		var ol := UiStyle.label(oe.desc, 14, g.color().lightened(0.35))
		ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; ol.custom_minimum_size = Vector2(380, 0)
		ov.add_child(ol)
		detail_box.add_child(op)
	var cost := GearSystem.reroll_cost(g)
	var ah := HBoxContainer.new(); ah.add_theme_constant_override("separation", 10); detail_box.add_child(ah)
	ah.add_child(UiStyle.subtitle(UiText.t("LABEL_AFFIXES"), 20))
	if not cost.is_empty():
		var cl := UiStyle.label(UiText.t("LABEL_REROLL_COST", {"refine_name": GameData.material_name("MAT_REFINE"), "refine": cost.refine, "lingshi": cost.lingshi}), 13, Color(UiStyle.GOLD_TEXT, 0.7))
		cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ah.add_child(cl)
	for i in g.affixes.size():
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); detail_box.add_child(row)
		var al := UiStyle.label("◆ " + GearItem.affix_text(g.affixes[i]), 16, Color("#CFE6D6"))
		al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(al)
		if not cost.is_empty():
			var rb := UiStyle.button(UiText.t("BTN_REROLL"), 14)
			rb.custom_minimum_size = Vector2(64, 28)
			rb.disabled = PlayerState.item_count("MAT_REFINE") < int(cost.refine) or PlayerState.lingshi < int(cost.lingshi)
			var idx := i; var uid := g.uid
			rb.pressed.connect(func() -> void:
				var r := PlayerState.reroll_affix(uid, idx)
				var ng := PlayerState.find_gear(uid)
				_say(r, UiText.t("TOAST_REROLLED", {"affix": GearItem.affix_text(ng.affixes[idx])}) if ng and r == "ok" else ""))
			row.add_child(rb)
	if g.affixes.is_empty():
		detail_box.add_child(UiStyle.label(UiText.t("LABEL_NO_AFFIX"), 14, Color(0.6, 0.6, 0.55)))
	detail_box.add_child(UiStyle.hsep(0.3))
	var ar := HBoxContainer.new(); ar.add_theme_constant_override("separation", 12); detail_box.add_child(ar)
	if not equipped:
		var eb := UiStyle.accent_button(UiText.t("BTN_EQUIP_GEAR"), 18)
		eb.custom_minimum_size = Vector2(120, 40)
		eb.pressed.connect(func() -> void: _say(PlayerState.equip_gear(g.uid), UiText.t("TOAST_GEAR_EQUIPPED", {"equip_name": g.display_name()})))
		ar.add_child(eb)
		var db := UiStyle.button(UiText.t("BTN_DECOMPOSE_GEAR"), 16)
		db.custom_minimum_size = Vector2(96, 40)
		var v := GearSystem.decompose_value(g)
		db.pressed.connect(func() -> void:
			selected_uid = 0
			_say(PlayerState.decompose_gear(g.uid), UiText.t("TOAST_GEAR_DECOMPOSED", {"item_name": GameData.material_name("MAT_REFINE"), "count": v})))
		ar.add_child(db)
		var gl := UiStyle.label(UiText.t("LABEL_DECOMPOSE_GAIN", {"item_name": GameData.material_name("MAT_REFINE"), "count": v}), 14, Color(UiStyle.GOLD_TEXT, 0.7))
		gl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ar.add_child(gl)
	else:
		ar.add_child(UiStyle.label(UiText.t("LABEL_EQUIPPED_HINT"), 14, Color(UiStyle.GOLD_TEXT, 0.6)))

func _build_footer() -> void:
	footer.add_child(UiStyle.subtitle(UiText.t("LABEL_BATCH_DECOMPOSE"), 18))
	for q in GameData.qualities_ordered():
		if not q.auto_decompose_allowed:
			continue
		var b := UiStyle.button(UiText.t("BTN_DECOMPOSE_UPTO", {"quality_name": q.name}), 14)
		b.add_theme_color_override("font_color", q.color)
		var order := q.order
		b.pressed.connect(func() -> void:
			var n := PlayerState.decompose_up_to(order)
			_say("ok", UiText.t("TOAST_BATCH_DECOMPOSED", {"count": n})))
		footer.add_child(b)
	footer.add_child(UiStyle.spacer())
	footer.add_child(UiStyle.subtitle(UiText.t("LABEL_AUTO_DECOMPOSE"), 18))
	var never := ""
	for q in GameData.qualities_ordered():
		if not q.auto_decompose_allowed:
			never = q.name
			continue
		var cb := CheckBox.new()
		cb.text = q.name
		cb.focus_mode = Control.FOCUS_NONE
		cb.add_theme_color_override("font_color", q.color)
		cb.add_theme_color_override("font_pressed_color", q.color.lightened(0.2))
		cb.add_theme_color_override("font_hover_color", q.color.lightened(0.3))
		cb.button_pressed = bool(PlayerState.auto_decompose.get(q.id, false))
		var qid := q.id
		cb.toggled.connect(func(on: bool) -> void: PlayerState.set_auto_decompose(qid, on))
		footer.add_child(cb)
	if never != "":
		var note := UiStyle.label(UiText.t("LABEL_NEVER_AUTO", {"quality_name": never}), 12, Color(UiStyle.GOLD_TEXT, 0.5)); note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		footer.add_child(note)

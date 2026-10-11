class_name GearPanel
extends PanelContainer
## 装备面板（阶段4，v2 宣纸水墨风格）：已装备 6 槽 + 角色属性 / 背包（品质排序、推荐箭头）/
## 详情（基础属性与当前装备对比、核心特效、逐条重铸、装备/分解）/ 批量分解与按品质自动分解 / 终关核心橙装三选一。
## 数值全部来自表（qualities / affixes / gear_tiers / equip_bases / orange_effects）。打开时战斗暂停（HUD 负责）。

signal closed

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
	var k := PanelKit.shell(self, "装备", "炼器 · 重铸 · 分解")
	(k.close as Button).pressed.connect(func() -> void: closed.emit())
	res_box = HBoxContainer.new(); res_box.add_theme_constant_override("separation", 14)
	(k.head as HBoxContainer).add_child(res_box)
	(k.head as HBoxContainer).move_child(res_box, 3)
	var body: VBoxContainer = k.body
	var cols := HBoxContainer.new(); cols.size_flags_vertical = Control.SIZE_EXPAND_FILL; cols.add_theme_constant_override("separation", 12)
	body.add_child(cols)
	var left := PanelKit.section(cols, "已装备", 300)
	slots_box = VBoxContainer.new(); slots_box.add_theme_constant_override("separation", 4); left.add_child(slots_box)
	left.add_child(UiStyle.hsep(0.3))
	stats_box = VBoxContainer.new(); stats_box.add_theme_constant_override("separation", 2); left.add_child(stats_box)
	var mid := PanelKit.section(cols, "", 330)
	var mh := HBoxContainer.new(); mid.add_child(mh)
	mh.add_child(UiStyle.subtitle("背包", 22)); mh.add_child(UiStyle.spacer())
	bag_cap = UiStyle.label("", 14, Color(UiStyle.GOLD_TEXT, 0.75)); bag_cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER; mh.add_child(bag_cap)
	bag_box = PanelKit.scroll(mid)
	var right := PanelKit.section(cols, "详情", 0, true)
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
	const TEXT := {"no_refine": "炼器材料不足", "no_lingshi": "灵石不足", "cannot_reroll": "该品质不可重铸", "not_in_bag": "只能操作背包中的装备（先替换下来）", "no_pool": "没有可重铸的词条"}
	_msg = ok_text if result == "ok" else str(TEXT.get(result, result))
	refresh()
	msg_label.modulate = Color(1.6, 1.4, 1.0)
	var tw := msg_label.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(msg_label, "modulate", Color.WHITE, 0.5)

func _sorted_bag() -> Array[GearItem]:
	var out: Array[GearItem] = PlayerState.bag.duplicate()
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

func refresh() -> void:
	for box in [slots_box, stats_box, bag_box, detail_box, footer, res_box]:
		_clear(box)
	res_box.add_child(_res_pill("jade", "灵石 " + UiStyle.num(PlayerState.lingshi)))
	res_box.add_child(_res_pill("", "炼器材料 " + UiStyle.num(PlayerState.item_count("MAT_REFINE"))))
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
	PanelKit.kv(stats_box, "攻击", UiStyle.num(st.atk))
	PanelKit.kv(stats_box, "生命", UiStyle.num(st.max_hp))
	PanelKit.kv(stats_box, "防御", UiStyle.num(st.def))
	PanelKit.kv(stats_box, "暴击", "%.1f%%　暴伤 %.0f%%" % [st.crit_rate * 100.0, st.crit_dmg * 100.0])
	if float(st.reflect) > 0.0:
		PanelKit.kv(stats_box, "反伤", "%.0f%%" % (st.reflect * 100.0))
	# 三选一
	for gi in PlayerState.pending_orange_choices.size():
		var top := GameData.qualities_ordered().back()
		stats_box.add_child(UiStyle.hsep(0.3))
		stats_box.add_child(UiStyle.subtitle("终关首通 · 核心橙装三选一", 18, top.color))
		for bid in PlayerState.pending_orange_choices[gi]:
			var base := GameData.get_base(bid)
			var oe := GameData.orange_effects.get(base.orange_effect_id) as OrangeEffectDef if base else null
			var cb := PanelKit.row("选择 %s · %s" % [base.name if base else bid, oe.name if oe else ""], top.color, false, 14, top.color.lightened(0.2))
			cb.tooltip_text = oe.desc if oe else ""
			var idx := gi; var b_id: String = bid
			cb.pressed.connect(func() -> void: _say(PlayerState.choose_orange(idx, b_id), "获得核心橙装 %s" % (base.name if base else b_id)))
			stats_box.add_child(cb)
	# 背包
	if PlayerState.bag.is_empty():
		var e := UiStyle.label("背包空空如也\n击杀怪物、首领与首通奖励可获得装备", 15, Color(UiStyle.GOLD_TEXT, 0.55))
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bag_box.add_child(e)
	for g in _sorted_bag():
		var cmp := PlayerState.compare_gear(g)
		var b := PanelKit.row("%s  ·  %s" % [g.display_name(), GameData.slot_name(g.slot_id())], g.color(), g.uid == selected_uid, 15, g.color().lightened(0.15))
		if cmp.recommended:
			var ar := GlyphIcon.new("arrow_up", 18)
			ar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
			ar.offset_left = -26; ar.offset_right = -8; ar.offset_top = -9; ar.offset_bottom = 9
			ar.tooltip_text = "基础属性优于当前装备"
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
		detail_box.add_child(UiStyle.label("选择一件装备查看详情", 15, Color(UiStyle.GOLD_TEXT, 0.55)))
		return
	var equipped := PlayerState.is_equipped(g)
	var name_row := HBoxContainer.new(); detail_box.add_child(name_row)
	name_row.add_child(UiStyle.title(g.base().name if g.base() else g.base_id, 32, g.color()))
	var tag := UiStyle.label("　%s · %s · 第%d档%s" % [g.quality().name, GameData.slot_name(g.slot_id()), g.tier(), "　已装备" if equipped else ""], 14, Color(UiStyle.GOLD_TEXT, 0.75))
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(tag)
	detail_box.add_child(UiStyle.hsep(0.3))
	var bs := g.base_stats()
	var cmp := PlayerState.compare_gear(g)
	for k in [["atk", "攻击"], ["hp", "生命"], ["def", "防御"], ["crit_rate", "暴击率"], ["move_speed", "移速"]]:
		var val := float(bs.get(k[0], 0.0))
		var dv := float(cmp.get(k[0], 0.0))
		if val == 0.0 and dv == 0.0:
			continue
		var is_pct: bool = k[0] == "crit_rate"
		var txt := ("%.1f%%" % (val * 100.0)) if is_pct else UiStyle.num(val)
		var dt := ""
		if not equipped and absf(dv) > 0.0001:
			dt = ("↑ " if dv > 0 else "↓ ") + (("%+.1f%%" % (dv * 100.0)) if is_pct else ("%+d" % int(round(dv))))
		PanelKit.kv(detail_box, k[1], txt, UiStyle.MIST, dt, UiStyle.GOOD if dv > 0 else UiStyle.BAD)
	var oe := g.orange_effect()
	if oe:
		var op := PanelContainer.new()
		var osb := UiStyle.panel(6, g.color(), 0.6); osb.bg_color = Color(g.color().darkened(0.75), 0.75)
		op.add_theme_stylebox_override("panel", osb)
		var ol := UiStyle.label("【%s】%s" % [oe.name, oe.desc], 14, g.color().lightened(0.25))
		ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; ol.custom_minimum_size = Vector2(380, 0)
		op.add_child(ol)
		detail_box.add_child(op)
	var cost := GearSystem.reroll_cost(g)
	var ah := HBoxContainer.new(); detail_box.add_child(ah)
	ah.add_child(UiStyle.subtitle("词条", 20))
	if not cost.is_empty():
		var cl := UiStyle.label("　重铸每条：炼器材料 %d · 灵石 %s" % [cost.refine, UiStyle.num(cost.lingshi)], 13, Color(UiStyle.GOLD_TEXT, 0.7))
		cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ah.add_child(cl)
	for i in g.affixes.size():
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); detail_box.add_child(row)
		var al := UiStyle.label("◆ " + GearItem.affix_text(g.affixes[i]), 16, Color("#CFE6D6"))
		al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(al)
		if not cost.is_empty():
			var rb := UiStyle.button("重铸", 14)
			rb.custom_minimum_size = Vector2(64, 28)
			rb.disabled = PlayerState.item_count("MAT_REFINE") < int(cost.refine) or PlayerState.lingshi < int(cost.lingshi)
			var idx := i; var uid := g.uid
			rb.pressed.connect(func() -> void: _say(PlayerState.reroll_affix(uid, idx), "重铸完成：%s" % GearItem.affix_text(PlayerState.find_gear(uid).affixes[idx])))
			row.add_child(rb)
	if g.affixes.is_empty():
		detail_box.add_child(UiStyle.label("（白装无词条）", 14, Color(0.6, 0.6, 0.55)))
	detail_box.add_child(UiStyle.hsep(0.3))
	var ar := HBoxContainer.new(); ar.add_theme_constant_override("separation", 12); detail_box.add_child(ar)
	if not equipped:
		var eb := UiStyle.accent_button("装备", 18)
		eb.custom_minimum_size = Vector2(120, 40)
		eb.pressed.connect(func() -> void: _say(PlayerState.equip_gear(g.uid), "已装备 %s" % g.display_name()))
		ar.add_child(eb)
		var db := UiStyle.button("分解 · 炼器材料 +%d" % GearSystem.decompose_value(g), 16)
		db.custom_minimum_size = Vector2(0, 40)
		db.pressed.connect(func() -> void:
			var v := GearSystem.decompose_value(g)
			selected_uid = 0
			_say(PlayerState.decompose_gear(g.uid), "已分解，炼器材料 +%d" % v))
		ar.add_child(db)
	else:
		ar.add_child(UiStyle.label("已装备中；从背包选择同部位装备即可替换", 14, Color(UiStyle.GOLD_TEXT, 0.6)))

func _build_footer() -> void:
	footer.add_child(UiStyle.subtitle("批量分解", 18))
	for q in GameData.qualities_ordered():
		if not q.auto_decompose_allowed:
			continue
		var b := UiStyle.button("%s及以下" % q.name, 14)
		b.add_theme_color_override("font_color", q.color)
		var order := q.order
		b.pressed.connect(func() -> void:
			var n := PlayerState.decompose_up_to(order)
			_say("ok", "分解了 %d 件装备" % n))
		footer.add_child(b)
	footer.add_child(UiStyle.spacer())
	footer.add_child(UiStyle.subtitle("自动分解", 18))
	for q in GameData.qualities_ordered():
		if not q.auto_decompose_allowed:
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
	var note := UiStyle.label("橙装永不自动分解", 12, Color(UiStyle.GOLD_TEXT, 0.5)); note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(note)

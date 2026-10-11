class_name GearPanel
extends PanelContainer
## 装备面板（阶段4）：已装备槽位 / 背包（品质排序、推荐箭头）/ 详情（属性对比、装备、分解、逐条重铸）
## / 批量分解与按品质自动分解开关 / 终关核心橙装三选一。数值全部来自表（qualities / affixes / gear_tiers / equip_bases / orange_effects）。

signal closed

var selected_uid := 0
var _msg := ""
var slots_box: VBoxContainer
var bag_box: VBoxContainer
var detail_box: VBoxContainer
var footer: HBoxContainer
var res_label: Label
var msg_label: Label
var bag_label: Label

func _ready() -> void:
	var sb := UiStyle.panel(8); sb.bg_color = Color(UiStyle.PANEL, 0.95)
	add_theme_stylebox_override("panel", sb)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 40; offset_right = -40; offset_top = 52; offset_bottom = -146
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); add_child(v)
	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 16); v.add_child(head)
	head.add_child(UiStyle.label("装备（战斗已暂停）", 24, UiStyle.GOLD))
	bag_label = UiStyle.label("", 16); head.add_child(bag_label)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(sp)
	res_label = UiStyle.label("", 16); head.add_child(res_label)
	var close := UiStyle.button("关闭", 16); close.pressed.connect(func() -> void: closed.emit()); head.add_child(close)
	var body := HBoxContainer.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation", 10); v.add_child(body)
	slots_box = VBoxContainer.new(); slots_box.custom_minimum_size = Vector2(300, 0); slots_box.add_theme_constant_override("separation", 3); body.add_child(slots_box)
	var bs := ScrollContainer.new(); bs.custom_minimum_size = Vector2(330, 0); bs.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_child(bs)
	bag_box = VBoxContainer.new(); bag_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bag_box.add_theme_constant_override("separation", 2); bs.add_child(bag_box)
	var ds := ScrollContainer.new(); ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ds.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_child(ds)
	detail_box = VBoxContainer.new(); detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; detail_box.add_theme_constant_override("separation", 4); ds.add_child(detail_box)
	footer = HBoxContainer.new(); footer.add_theme_constant_override("separation", 8); v.add_child(footer)
	msg_label = UiStyle.label("", 15, UiStyle.GOLD); v.add_child(msg_label)
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
	const TEXT := {"no_refine": "炼器材料不足", "no_lingshi": "灵石不足", "cannot_reroll": "该品质不可重铸", "not_in_bag": "只能操作背包中的装备（先卸下/替换）", "no_pool": "没有可重铸的词条"}
	_msg = ok_text if result == "ok" else str(TEXT.get(result, result))
	refresh()

func _sorted_bag() -> Array[GearItem]:
	var out: Array[GearItem] = PlayerState.bag.duplicate()
	out.sort_custom(func(a: GearItem, b: GearItem) -> bool:
		if a.quality().order != b.quality().order:
			return a.quality().order > b.quality().order
		if a.tier() != b.tier():
			return a.tier() > b.tier()
		return a.uid > b.uid)
	return out

func refresh() -> void:
	for box in [slots_box, bag_box, detail_box, footer]:
		for c in box.get_children():
			box.remove_child(c); c.queue_free()
	res_label.text = "灵石 %d　　炼器材料 %d" % [PlayerState.lingshi, PlayerState.item_count("MAT_REFINE")]
	bag_label.text = "背包 %d/%d" % [PlayerState.bag.size(), PlayerState.bag_capacity()]
	msg_label.text = _msg
	# 已装备
	slots_box.add_child(UiStyle.label("已装备", 17, UiStyle.GOLD))
	for sl in GameData.equip_slots:
		var g: GearItem = PlayerState.equipped.get(sl.slot_id)
		var b := UiStyle.button("%s：%s" % [sl.name, g.display_name() if g else "空"], 15)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if g:
			b.add_theme_color_override("font_color", g.color())
			var uid := g.uid
			b.pressed.connect(func() -> void: select(uid))
		else:
			b.disabled = true
		slots_box.add_child(b)
	var st := PlayerState.combat_stats()
	var sl2 := UiStyle.label("攻击 %d　生命 %d　防御 %d\n暴击 %.1f%%　暴伤 %.0f%%　反伤 %.0f%%" % [st.atk, st.max_hp, st.def, st.crit_rate * 100.0, st.crit_dmg * 100.0, st.reflect * 100.0], 14, Color(0.85, 0.9, 0.85))
	slots_box.add_child(sl2)
	# 三选一
	for gi in PlayerState.pending_orange_choices.size():
		slots_box.add_child(UiStyle.label("终关首通：核心橙装三选一", 16, GameData.qualities_ordered().back().color))
		for bid in PlayerState.pending_orange_choices[gi]:
			var base := GameData.get_base(bid)
			var oe := GameData.orange_effects.get(base.orange_effect_id) as OrangeEffectDef if base else null
			var cb := UiStyle.button("选择 %s（%s）" % [base.name if base else bid, oe.name if oe else ""], 14)
			cb.tooltip_text = oe.desc if oe else ""
			var idx := gi; var b_id: String = bid
			cb.pressed.connect(func() -> void: _say(PlayerState.choose_orange(idx, b_id), "获得核心橙装 %s" % (base.name if base else b_id)))
			slots_box.add_child(cb)
	# 背包
	if PlayerState.bag.is_empty():
		bag_box.add_child(UiStyle.label("背包空空如也（击杀怪物/首领、首通奖励可获得装备）", 14, Color(0.7, 0.7, 0.7)))
	for g in _sorted_bag():
		var cmp := PlayerState.compare_gear(g)
		var b := UiStyle.button("%s%s %s" % ["▶" if g.uid == selected_uid else "  ", g.display_name(), "↑推荐" if cmp.recommended else ""], 15)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", g.color())
		var uid := g.uid
		b.pressed.connect(func() -> void: select(uid))
		bag_box.add_child(b)
	if PlayerState.find_gear(selected_uid) == null:
		selected_uid = _sorted_bag()[0].uid if not PlayerState.bag.is_empty() else 0
	_build_detail()
	_build_footer()

func _build_detail() -> void:
	var g := PlayerState.find_gear(selected_uid)
	if g == null:
		detail_box.add_child(UiStyle.label("选择一件装备查看详情", 15, Color(0.7, 0.7, 0.7)))
		return
	var equipped := PlayerState.is_equipped(g)
	detail_box.add_child(UiStyle.label(g.display_name() + ("（已装备）" if equipped else ""), 20, g.color()))
	detail_box.add_child(UiStyle.label("%s · 第%d档" % [GameData.slot_name(g.slot_id()), g.tier()], 14, Color(0.75, 0.75, 0.7)))
	var bs := g.base_stats()
	var cmp := PlayerState.compare_gear(g)
	for k in [["atk", "攻击"], ["hp", "生命"], ["def", "防御"], ["crit_rate", "暴击率"], ["move_speed", "移速"]]:
		var val := float(bs.get(k[0], 0.0))
		var dv := float(cmp.get(k[0], 0.0))
		if val == 0.0 and dv == 0.0:
			continue
		var is_pct: bool = k[0] == "crit_rate"
		var txt := ("%s %.1f%%" % [k[1], val * 100.0]) if is_pct else ("%s %d" % [k[1], int(round(val))])
		var row := HBoxContainer.new(); detail_box.add_child(row)
		row.add_child(UiStyle.label(txt, 15))
		if not equipped and absf(dv) > 0.0001:
			var dt := ("%+.1f%%" % (dv * 100.0)) if is_pct else ("%+d" % int(round(dv)))
			row.add_child(UiStyle.label(("↑" if dv > 0 else "↓") + dt, 15, Color("#7CCB6B") if dv > 0 else UiStyle.BLOOD))
	var oe := g.orange_effect()
	if oe:
		var ol := UiStyle.label("【%s】%s" % [oe.name, oe.desc], 14, g.color()); ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; ol.custom_minimum_size = Vector2(440, 0)
		detail_box.add_child(ol)
	var cost := GearSystem.reroll_cost(g)
	detail_box.add_child(UiStyle.label("词条" + ("（重铸：炼器材料%d + 灵石%d / 条）" % [cost.refine, cost.lingshi] if not cost.is_empty() else ""), 15, UiStyle.GOLD))
	for i in g.affixes.size():
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); detail_box.add_child(row)
		var al := UiStyle.label("· " + GearItem.affix_text(g.affixes[i]), 15, Color(0.9, 0.9, 0.85)); al.custom_minimum_size = Vector2(220, 0)
		row.add_child(al)
		if not cost.is_empty():
			var rb := UiStyle.button("重铸", 14)
			rb.disabled = PlayerState.item_count("MAT_REFINE") < int(cost.refine) or PlayerState.lingshi < int(cost.lingshi)
			var idx := i; var uid := g.uid
			rb.pressed.connect(func() -> void: _say(PlayerState.reroll_affix(uid, idx), "重铸完成：%s" % GearItem.affix_text(PlayerState.find_gear(uid).affixes[idx])))
			row.add_child(rb)
	if g.affixes.is_empty():
		detail_box.add_child(UiStyle.label("（无词条）", 14, Color(0.6, 0.6, 0.6)))
	var ar := HBoxContainer.new(); ar.add_theme_constant_override("separation", 10); detail_box.add_child(ar)
	if not equipped:
		var eb := UiStyle.button("装备", 17)
		eb.pressed.connect(func() -> void: _say(PlayerState.equip_gear(g.uid), "已装备 %s" % g.display_name()))
		ar.add_child(eb)
		var db := UiStyle.button("分解（炼器材料+%d）" % GearSystem.decompose_value(g), 17)
		db.pressed.connect(func() -> void:
			var v := GearSystem.decompose_value(g)
			selected_uid = 0
			_say(PlayerState.decompose_gear(g.uid), "已分解，炼器材料+%d" % v))
		ar.add_child(db)

func _build_footer() -> void:
	footer.add_child(UiStyle.label("批量分解：", 15))
	for q in GameData.qualities_ordered():
		if not q.auto_decompose_allowed:
			continue
		var b := UiStyle.button("%s及以下" % q.name, 14)
		var order := q.order
		b.pressed.connect(func() -> void:
			var n := PlayerState.decompose_up_to(order)
			_say("ok", "分解了 %d 件" % n))
		footer.add_child(b)
	footer.add_child(UiStyle.label("　自动分解：", 15))
	for q in GameData.qualities_ordered():
		if not q.auto_decompose_allowed:
			continue
		var cb := CheckBox.new()
		cb.text = q.name
		cb.focus_mode = Control.FOCUS_NONE
		cb.add_theme_color_override("font_color", q.color)
		cb.button_pressed = bool(PlayerState.auto_decompose.get(q.id, false))
		var qid := q.id
		cb.toggled.connect(func(on: bool) -> void: PlayerState.set_auto_decompose(qid, on))
		footer.add_child(cb)
	footer.add_child(UiStyle.label("（橙装永不自动分解）", 13, Color(0.7, 0.7, 0.7)))

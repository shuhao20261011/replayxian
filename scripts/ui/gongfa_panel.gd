class_name GongfaPanel
extends PanelContainer
## 功法面板（阶段3，v2 宣纸水墨风格）：功法页签 + 当前技能栏 / 技能列表（类别、等级、持书）/
## 技能详情（图标、按当前等级渲染的说明、下一级预览、学习/升级/装配/设为被动、分解重复书、残页兑换、获取途径）。
## 数值与文案全部读表：gongfa / skills / skill_levels / skill_books / materials / ui_texts。
## 由 HUD 打开；打开期间战斗暂停（HUD 处理），本面板 process_mode 继承 ALWAYS，可正常交互。

signal closed

var gongfa_id := ""
var skill_id := ""
var _msg := ""
var tabs_box: HBoxContainer
var bar_box: HBoxContainer
var gf_desc: Label
var list_box: VBoxContainer
var detail_box: VBoxContainer
var res_box: HBoxContainer
var msg_label: Label

func _ready() -> void:
	var k := PanelKit.shell(self, Hud.panel_title_text("gongfa"), UiText.t("PANEL_SUB_GONGFA"))
	(k.close as Button).pressed.connect(func() -> void: closed.emit())
	res_box = HBoxContainer.new(); res_box.add_theme_constant_override("separation", 14)
	(k.head as HBoxContainer).add_child(res_box)
	(k.head as HBoxContainer).move_child(res_box, 3)
	var body: VBoxContainer = k.body
	# 页签 + 技能栏
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 10); body.add_child(top)
	tabs_box = HBoxContainer.new(); tabs_box.add_theme_constant_override("separation", 8); top.add_child(tabs_box)
	top.add_child(UiStyle.spacer())
	var barp := PanelContainer.new(); barp.add_theme_stylebox_override("panel", UiStyle.section()); top.add_child(barp)
	var barh := HBoxContainer.new(); barh.add_theme_constant_override("separation", 8); barp.add_child(barh)
	var bl := UiStyle.subtitle(UiText.t("LABEL_SKILL_BAR"), 20); bl.size_flags_vertical = Control.SIZE_SHRINK_CENTER; barh.add_child(bl)
	bar_box = HBoxContainer.new(); bar_box.add_theme_constant_override("separation", 6); barh.add_child(bar_box)
	# 主体：左技能列表、右详情
	var cols := HBoxContainer.new(); cols.size_flags_vertical = Control.SIZE_EXPAND_FILL; cols.add_theme_constant_override("separation", 12)
	body.add_child(cols)
	var left := PanelKit.section(cols, "", 420)
	gf_desc = UiStyle.label("", 14, Color(UiStyle.MIST, 0.75)); gf_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(gf_desc)
	left.add_child(UiStyle.hsep(0.3))
	list_box = PanelKit.scroll(left)
	var right := PanelKit.section(cols, UiText.t("LABEL_DETAIL"), 0, true)
	detail_box = PanelKit.scroll(right)
	msg_label = UiStyle.label("", 16, UiStyle.GOLD_TEXT)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(msg_label)
	PlayerState.inventory_changed.connect(_refresh_if_visible)
	PlayerState.skill_bar_changed.connect(_refresh_if_visible)
	PlayerState.currencies_changed.connect(_refresh_if_visible)

func open() -> void:
	if gongfa_id == "":
		gongfa_id = GameData.gongfa_ordered()[0].id
	_msg = ""
	visible = true
	refresh()

func _refresh_if_visible() -> void:
	if visible:
		refresh.call_deferred()

func select_gongfa(id: String) -> void:
	gongfa_id = id
	skill_id = ""
	refresh()

func select_skill(id: String) -> void:
	skill_id = id
	refresh()

func _say(result: String, ok_text: String) -> void:
	_msg = PanelKit.result_text(result, ok_text)
	refresh()
	msg_label.modulate = Color(1.6, 1.4, 1.0)
	var tw := msg_label.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(msg_label, "modulate", Color.WHITE, 0.5)

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

static func _chip(text: String, color: Color, size: int = 13) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := UiStyle.panel(4, color, 0.75); sb.content_margin_top = 0; sb.content_margin_bottom = 0; sb.content_margin_left = 7; sb.content_margin_right = 7
	pc.add_theme_stylebox_override("panel", sb)
	pc.add_child(UiStyle.label(text, size, color))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pc

static func _icon(s: SkillDef, dim: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(dim, dim)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if s and ResourceLoader.exists(s.icon_path()):
		tr.texture = load(s.icon_path())
	return tr

static func kind_text(s: SkillDef) -> String:
	if not s.is_active():
		return UiText.t("SKILL_KIND_PASSIVE")
	return UiText.t("SKILL_KIND_ULTIMATE" if s.tier == "ultimate" else "SKILL_KIND_ACTIVE")

func refresh() -> void:
	for box in [tabs_box, bar_box, list_box, detail_box, res_box]:
		_clear(box)
	res_box.add_child(_res_pill("jade", UiText.t("HUD_LINGSHI", {"value": PlayerState.lingshi})))
	res_box.add_child(_res_pill("", "%s　%s" % [GameData.material_name(PlayerState.PAGE_ID), UiStyle.num(PlayerState.item_count(PlayerState.PAGE_ID))]))
	msg_label.text = _msg
	# 页签（功法名；未入门加小签）
	for g in GameData.gongfa_ordered():
		var v := VBoxContainer.new(); v.add_theme_constant_override("separation", -4)
		var b := PanelKit.tab(g.name, g.color, g.id == gongfa_id)
		var gid := g.id
		b.pressed.connect(func() -> void: select_gongfa(gid))
		v.add_child(b)
		if not PlayerState.gongfa_entered(g.id):
			var c := _chip(UiText.t("LABEL_NOT_ENTERED"), Color(0.7, 0.68, 0.6), 11); c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; c.z_index = 1
			v.add_child(c)
		tabs_box.add_child(v)
	# 技能栏（4 格 + 被动）：点格子卸下
	for i in PlayerState.slot_count():
		var s := GameData.get_skill(PlayerState.active_slots[i])
		var b := UiStyle.button("", 14)
		b.custom_minimum_size = Vector2(54, 54)
		b.tooltip_text = ("%s\n%s" % [s.name, UiText.t("TIP_UNEQUIP")]) if s else UiText.t("TIP_EMPTY_SLOT")
		if s:
			var ic := _icon(s, 44); ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER); ic.position -= Vector2(22, 22)
			b.add_child(ic)
		else:
			b.text = UiText.t("LABEL_EMPTY_SLOT")
		var num := UiStyle.label(str(i + 1), 11, UiStyle.GOLD_TEXT); num.position = Vector2(4, 0); b.add_child(num)
		var slot := i
		b.pressed.connect(func() -> void:
			PlayerState.unequip_skill(slot)
			_say("ok", UiText.t("TOAST_SKILL_UNEQUIPPED", {"slot": slot + 1})))
		b.disabled = s == null
		bar_box.add_child(b)
	var ps := GameData.get_skill(PlayerState.passive_skill)
	var pl := UiStyle.label(UiText.t("LABEL_PASSIVE", {"skill_name": ps.name if ps else UiText.t("LABEL_EMPTY_SLOT")}), 15, UiStyle.JADE.lightened(0.4))
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_box.add_child(pl)
	# 技能列表
	var g := GameData.gongfa.get(gongfa_id) as GongfaDef
	gf_desc.text = g.desc if g else ""
	var first := ""
	for s in GameData.skills_of_gongfa(gongfa_id):
		if first == "":
			first = s.id
		list_box.add_child(_skill_row(s, g))
	if skill_id == "" or GameData.get_skill(skill_id) == null or GameData.get_skill(skill_id).gongfa_id != gongfa_id:
		skill_id = first
		if skill_id != "":
			refresh.call_deferred()
	_build_detail()

func _skill_row(s: SkillDef, g: GongfaDef) -> Button:
	var lv := PlayerState.skill_level(s.id)
	var bk := GameData.get_book(s.book_id)
	var cnt := PlayerState.book_count(bk.id) if bk else 0
	var accent := g.color if g else UiStyle.GOLD_LINE
	var b := PanelKit.row(s.name, accent if lv > 0 else Color(accent, 0.45), s.id == skill_id, 17, UiStyle.GOLD_TEXT if lv > 0 else (Color("#E6CF9A") if cnt > 0 else Color(0.62, 0.6, 0.55)))
	b.custom_minimum_size = Vector2(0, 46)
	var sb := b.get_theme_stylebox("normal") as StyleBoxFlat
	if sb:
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			var x := (b.get_theme_stylebox(st) as StyleBoxFlat)
			if x:
				x.content_margin_left = 58
	var ic := _icon(s, 36)
	ic.position = Vector2(14, 5)
	if lv <= 0:
		ic.modulate = Color(0.55, 0.55, 0.55, 0.8)
	b.add_child(ic)
	var tags := HBoxContainer.new(); tags.add_theme_constant_override("separation", 6)
	tags.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	tags.grow_horizontal = Control.GROW_DIRECTION_BEGIN; tags.grow_vertical = Control.GROW_DIRECTION_BOTH
	tags.offset_right = -10; tags.offset_left = -10
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tags)
	if cnt > 0:
		tags.add_child(_chip(UiText.t("LABEL_BOOK_COUNT", {"count": cnt}), Color("#C9B6F2")))
	tags.add_child(_chip(kind_text(s), accent.lightened(0.2)))
	var st_text := UiText.t("LABEL_LEVEL", {"level": lv}) if lv > 0 else UiText.t("LABEL_LEARNABLE" if cnt > 0 else "LABEL_UNLEARNED")
	tags.add_child(_chip(st_text, UiStyle.GOLD_TEXT if lv > 0 else (Color("#E6CF9A") if cnt > 0 else Color(0.62, 0.6, 0.55))))
	var sid := s.id
	b.pressed.connect(func() -> void: select_skill(sid))
	return b

func _build_detail() -> void:
	var s := GameData.get_skill(skill_id)
	if s == null:
		return
	var g := GameData.gongfa.get(s.gongfa_id) as GongfaDef
	var lv := PlayerState.skill_level(s.id)
	var max_lv := GameData.const_i("SKILL_MAX_LEVEL", 10)
	var bk := GameData.get_book(s.book_id)
	# 抬头：图标 + 名称 + 类别/等级
	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 14); detail_box.add_child(head)
	var frame := PanelContainer.new()
	var fsb := UiStyle._btn_box(Color(UiStyle.INK_DARK, 0.9), UiStyle.GOLD_LINE, 4, 2); fsb.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.add_child(_icon(s, 72))
	head.add_child(frame)
	var hv := VBoxContainer.new(); hv.add_theme_constant_override("separation", 2); hv.alignment = BoxContainer.ALIGNMENT_CENTER; head.add_child(hv)
	hv.add_child(UiStyle.title(s.name, 34, g.color.lightened(0.15) if g else UiStyle.GOLD_TEXT))
	var tagrow := HBoxContainer.new(); tagrow.add_theme_constant_override("separation", 6); hv.add_child(tagrow)
	tagrow.add_child(_chip(kind_text(s), (g.color if g else UiStyle.GOLD_LINE).lightened(0.2), 14))
	tagrow.add_child(_chip(UiText.t("LABEL_LEVEL_MAX", {"level": lv, "max": max_lv}) if lv > 0 else UiText.t("LABEL_UNLEARNED"), UiStyle.GOLD_TEXT if lv > 0 else Color(0.62, 0.6, 0.55), 14))
	if s.is_active():
		tagrow.add_child(_chip(UiText.t("LABEL_SKILL_CD", {"cd": snappedf(s.level_def(maxi(lv, 1)).cd_s, 0.01)}), UiStyle.MIST, 14))
	detail_box.add_child(UiStyle.hsep(0.3))
	# 说明：按当前等级渲染（未学按 1 级）；下一级预览
	var d := UiStyle.label(UiText.skill_desc(s.id, maxi(lv, 1)), 16, UiStyle.MIST)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; d.custom_minimum_size = Vector2(440, 0)
	detail_box.add_child(d)
	if lv > 0 and lv < max_lv:
		var np := PanelContainer.new()
		var nsb := UiStyle.panel(6, UiStyle.GOLD_LINE, 0.35); nsb.bg_color = Color(UiStyle.INK_DARK, 0.45)
		np.add_theme_stylebox_override("panel", nsb)
		var nv := VBoxContainer.new(); np.add_child(nv)
		nv.add_child(UiStyle.subtitle(UiText.t("LABEL_NEXT_LEVEL"), 18, UiStyle.GOOD))
		var nl := UiStyle.label(UiText.skill_desc(s.id, lv + 1), 14, Color("#CFE6D6"))
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; nl.custom_minimum_size = Vector2(420, 0)
		nv.add_child(nl)
		detail_box.add_child(np)
	# 主操作
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); detail_box.add_child(row)
	if lv <= 0:
		var b := UiStyle.accent_button(UiText.t("BTN_LEARN", {"book_name": bk.name if bk else ""}), 17)
		b.custom_minimum_size = Vector2(0, 40)
		b.disabled = bk == null or PlayerState.book_count(bk.id) <= 0
		b.pressed.connect(func() -> void: _say(PlayerState.learn_book(bk.id), UiText.t("TOAST_LEARNED", {"skill_name": s.name})))
		row.add_child(b)
		if bk:
			var hl := UiStyle.label(UiText.t("LABEL_BOOK_COUNT", {"count": PlayerState.book_count(bk.id)}), 14, Color(UiStyle.GOLD_TEXT, 0.7))
			hl.size_flags_vertical = Control.SIZE_SHRINK_CENTER; row.add_child(hl)
	else:
		var cost := PlayerState.upgrade_cost(s.id)
		var ub := UiStyle.accent_button(UiText.t("BTN_UPGRADE", {"cost": cost}) if cost >= 0 else UiText.t("BTN_UPGRADE_MAX"), 17)
		ub.custom_minimum_size = Vector2(0, 40)
		ub.disabled = cost < 0 or PlayerState.lingshi < cost
		ub.pressed.connect(func() -> void: _say(PlayerState.upgrade_skill(s.id), UiText.t("TOAST_UPGRADED", {"skill_name": s.name, "level": PlayerState.skill_level(s.id)})))
		row.add_child(ub)
		if s.is_active():
			for i in PlayerState.slot_count():
				var eb := UiStyle.button(UiText.t("BTN_EQUIP_TO_SLOT", {"slot": i + 1}), 16)
				eb.custom_minimum_size = Vector2(0, 40)
				var slot := i
				eb.disabled = PlayerState.active_slots[i] == s.id
				eb.pressed.connect(func() -> void:
					PlayerState.place_skill(slot, s.id)
					_say("ok", UiText.t("TOAST_SKILL_EQUIPPED", {"skill_name": s.name, "slot": slot + 1})))
				row.add_child(eb)
		else:
			var cur := PlayerState.passive_skill == s.id
			var pb := UiStyle.button(UiText.t("LABEL_CURRENT_PASSIVE" if cur else "BTN_SET_PASSIVE"), 16)
			pb.custom_minimum_size = Vector2(0, 40)
			pb.disabled = cur
			pb.pressed.connect(func() -> void:
				PlayerState.equip_passive(s.id)
				_say("ok", UiText.t("TOAST_PASSIVE_SET", {"skill_name": s.name})))
			row.add_child(pb)
	# 技能书：分解重复书 / 残页兑换 / 获取途径
	if bk:
		detail_box.add_child(UiStyle.hsep(0.3))
		var row2 := HBoxContainer.new(); row2.add_theme_constant_override("separation", 8); detail_box.add_child(row2)
		var bn := UiStyle.subtitle(bk.name, 20, Color("#C9B6F2")); bn.size_flags_vertical = Control.SIZE_SHRINK_CENTER; row2.add_child(bn)
		row2.add_child(_chip(UiText.t("LABEL_BOOK_COUNT", {"count": PlayerState.book_count(bk.id)}), Color("#C9B6F2"), 13))
		row2.add_child(UiStyle.spacer())
		var db := UiStyle.button(UiText.t("BTN_DECOMPOSE_BOOK"), 15)
		db.disabled = lv <= 0 or PlayerState.book_count(bk.id) <= 0
		db.tooltip_text = UiText.t("TOAST_BOOK_DECOMPOSED", {"book_name": bk.name, "pages": bk.decompose_pages})
		db.pressed.connect(func() -> void: _say(PlayerState.decompose_book(bk.id), UiText.t("TOAST_BOOK_DECOMPOSED", {"book_name": bk.name, "pages": bk.decompose_pages})))
		row2.add_child(db)
		var unlocked := PlayerState.map_unlocked(bk.region_map_id)
		var xb := UiStyle.button(UiText.t("BTN_EXCHANGE_BOOK"), 15)
		xb.disabled = not unlocked or PlayerState.item_count(PlayerState.PAGE_ID) < bk.exchange_pages
		xb.pressed.connect(func() -> void: _say(PlayerState.exchange_book(bk.id), UiText.t("TOAST_BOOK_EXCHANGED", {"book_name": bk.name})))
		row2.add_child(xb)
		var m := GameData.get_map(bk.region_map_id)
		var cost_text := UiText.t("LABEL_EXCHANGE_COST", {"item_name": GameData.material_name(PlayerState.PAGE_ID), "count": bk.exchange_pages}) if unlocked else UiText.t("LABEL_REGION_LOCKED", {"map_name": m.name if m else ""})
		var cl := UiStyle.label(cost_text, 13, Color(UiStyle.GOLD_TEXT, 0.65) if unlocked else UiStyle.BAD)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		detail_box.add_child(cl)
		var src := UiStyle.label(UiText.t("LABEL_SOURCE", {"source_desc": bk.source_desc}), 14, Color(UiStyle.MIST, 0.7))
		src.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; src.custom_minimum_size = Vector2(440, 0)
		detail_box.add_child(src)

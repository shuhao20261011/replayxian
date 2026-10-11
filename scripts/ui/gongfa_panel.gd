class_name GongfaPanel
extends PanelContainer
## 功法面板（阶段3）：功法页签 → 技能列表 → 技能详情（学习/升级/装配/设为被动/分解重复书/残页兑换）。
## 所有数值与文案读表：gongfa / skills / skill_levels / skill_books / constants。
## 由 HUD 打开；打开期间战斗暂停（HUD 处理），本面板 process_mode 继承 ALWAYS，可正常交互。

signal closed

var gongfa_id := ""
var skill_id := ""
var _msg := ""
var tabs_box: HBoxContainer
var bar_box: HBoxContainer
var list_box: VBoxContainer
var detail_box: VBoxContainer
var res_label: Label
var msg_label: Label

func _ready() -> void:
	var sb := UiStyle.panel(8); sb.bg_color = Color(UiStyle.PANEL, 0.95)
	add_theme_stylebox_override("panel", sb)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 70; offset_right = -70; offset_top = 52; offset_bottom = -146
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); add_child(v)
	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 16); v.add_child(head)
	head.add_child(UiStyle.label("功法（战斗已暂停）", 24, UiStyle.GOLD))
	tabs_box = HBoxContainer.new(); tabs_box.add_theme_constant_override("separation", 6); head.add_child(tabs_box)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(sp)
	res_label = UiStyle.label("", 16); head.add_child(res_label)
	var close := UiStyle.button("关闭", 16); close.pressed.connect(func() -> void: closed.emit()); head.add_child(close)
	# 技能栏
	var bar_row := HBoxContainer.new(); bar_row.add_theme_constant_override("separation", 8); v.add_child(bar_row)
	bar_row.add_child(UiStyle.label("技能栏", 16, UiStyle.GOLD))
	bar_box = HBoxContainer.new(); bar_box.add_theme_constant_override("separation", 8); bar_row.add_child(bar_box)
	# 主体：左列表 右详情
	var body := HBoxContainer.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation", 12); v.add_child(body)
	var ls := ScrollContainer.new(); ls.custom_minimum_size = Vector2(430, 0); ls.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_child(ls)
	list_box = VBoxContainer.new(); list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list_box.add_theme_constant_override("separation", 4); ls.add_child(list_box)
	var ds := ScrollContainer.new(); ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ds.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_child(ds)
	detail_box = VBoxContainer.new(); detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; detail_box.add_theme_constant_override("separation", 6); ds.add_child(detail_box)
	msg_label = UiStyle.label("", 16, UiStyle.GOLD); v.add_child(msg_label)
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
	const TEXT := {
		"no_book": "没有这本技能书", "already_learned": "已学会该技能（重复的书可分解为残页）", "not_learned": "尚未学习该技能",
		"max_level": "已满级", "no_lingshi": "灵石不足", "no_pages": "悟道残页不足", "locked_region": "该区域尚未解锁，无法兑换",
	}
	_msg = ok_text if result == "ok" else str(TEXT.get(result, result))
	refresh()

func refresh() -> void:
	for box in [tabs_box, bar_box, list_box, detail_box]:
		for c in box.get_children():
			box.remove_child(c); c.queue_free()
	res_label.text = "灵石 %d　　悟道残页 %d" % [PlayerState.lingshi, PlayerState.item_count(PlayerState.PAGE_ID)]
	msg_label.text = _msg
	# 页签
	for g in GameData.gongfa_ordered():
		var b := UiStyle.button("%s%s" % [g.name, "" if PlayerState.gongfa_entered(g.id) else "（未入门）"], 16)
		b.add_theme_color_override("font_color", g.color.lightened(0.3) if g.id == gongfa_id else Color(0.75, 0.75, 0.75))
		if g.id == gongfa_id:
			b.add_theme_stylebox_override("normal", UiStyle.panel(6, g.color))
		var gid := g.id
		b.pressed.connect(func() -> void: select_gongfa(gid))
		tabs_box.add_child(b)
	# 技能栏（4格 + 被动）
	for i in PlayerState.slot_count():
		var s := GameData.get_skill(PlayerState.active_slots[i])
		var t := "%d：%s" % [i + 1, ("%s Lv%d" % [s.name, PlayerState.skill_level(s.id)]) if s else "空"]
		var b := UiStyle.button(t, 15); b.custom_minimum_size = Vector2(150, 34)
		var slot := i
		b.tooltip_text = "点击卸下"
		b.pressed.connect(func() -> void:
			PlayerState.unequip_skill(slot)
			_say("ok", "已卸下第%d格" % (slot + 1)))
		b.disabled = s == null
		bar_box.add_child(b)
	var ps := GameData.get_skill(PlayerState.passive_skill)
	bar_box.add_child(UiStyle.label("被动：%s" % (ps.name if ps else "空"), 15, UiStyle.JADE.lightened(0.4)))
	# 技能列表
	var g := GameData.gongfa.get(gongfa_id) as GongfaDef
	if g:
		var d := UiStyle.label(g.desc, 14, Color(0.8, 0.8, 0.75)); d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; d.custom_minimum_size = Vector2(420, 0)
		list_box.add_child(d)
	var first := ""
	for s in GameData.skills_of_gongfa(gongfa_id):
		if first == "":
			first = s.id
		var lv := PlayerState.skill_level(s.id)
		var bk := GameData.get_book(s.book_id)
		var cnt := PlayerState.book_count(bk.id) if bk else 0
		var state := ("Lv%d" % lv) if lv > 0 else ("可学习" if cnt > 0 else "未学习")
		var kind := "被动" if not s.is_active() else ("终极" if s.tier == "ultimate" else "主动")
		var b := UiStyle.button("%s【%s】%s　%s%s" % ["▶" if s.id == skill_id else "  ", kind, s.name, state, ("　书×%d" % cnt) if cnt > 0 else ""], 16)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if lv <= 0:
			b.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5) if cnt > 0 else Color(0.6, 0.6, 0.6))
		var sid := s.id
		b.pressed.connect(func() -> void: select_skill(sid))
		list_box.add_child(b)
	if skill_id == "" or GameData.get_skill(skill_id) == null or GameData.get_skill(skill_id).gongfa_id != gongfa_id:
		skill_id = first
	_build_detail()

func _build_detail() -> void:
	var s := GameData.get_skill(skill_id)
	if s == null:
		return
	var lv := PlayerState.skill_level(s.id)
	var bk := GameData.get_book(s.book_id)
	detail_box.add_child(UiStyle.label("%s　%s" % [s.name, ("Lv%d / %d" % [lv, GameData.const_i("SKILL_MAX_LEVEL", 10)]) if lv > 0 else "未学习"], 22, UiStyle.GOLD))
	var d := UiStyle.label(s.desc, 15); d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; d.custom_minimum_size = Vector2(520, 0)
	detail_box.add_child(d)
	var cur := s.level_def(maxi(lv, 1))
	var info := "冷却 %.1f 秒　伤害系数 %.2f" % [cur.cd_s, cur.damage_coef] if s.is_active() else "效果值 %s" % _fmt(cur.effect_value)
	if s.effect_type != "none" and s.is_active():
		info += "　效果 %s" % _fmt(cur.effect_value)
	detail_box.add_child(UiStyle.label(info, 15, Color(0.85, 0.9, 0.85)))
	if lv > 0 and lv < GameData.const_i("SKILL_MAX_LEVEL", 10):
		var nx := s.level_def(lv + 1)
		var nt := "下一级：冷却 %.1f　系数 %.2f" % [nx.cd_s, nx.damage_coef] if s.is_active() else "下一级：效果值 %s" % _fmt(nx.effect_value)
		if s.is_active() and s.effect_type != "none":
			nt += "　效果 %s" % _fmt(nx.effect_value)
		detail_box.add_child(UiStyle.label(nt, 14, Color(0.7, 0.85, 0.7)))
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); detail_box.add_child(row)
	if lv <= 0:
		var b := UiStyle.button("学习（消耗1本%s，持有%d）" % [bk.name if bk else "?", PlayerState.book_count(bk.id) if bk else 0], 16)
		b.disabled = bk == null or PlayerState.book_count(bk.id) <= 0
		b.pressed.connect(func() -> void: _say(PlayerState.learn_book(bk.id), "学会了 %s" % s.name))
		row.add_child(b)
	else:
		var cost := PlayerState.upgrade_cost(s.id)
		var ub := UiStyle.button("升级（灵石 %d）" % cost if cost >= 0 else "已满级", 16)
		ub.disabled = cost < 0 or PlayerState.lingshi < cost
		ub.pressed.connect(func() -> void: _say(PlayerState.upgrade_skill(s.id), "%s 升到 Lv%d" % [s.name, PlayerState.skill_level(s.id)]))
		row.add_child(ub)
		if s.is_active():
			for i in PlayerState.slot_count():
				var eb := UiStyle.button("装到%d" % (i + 1), 16)
				var slot := i
				eb.disabled = PlayerState.active_slots[i] == s.id
				eb.pressed.connect(func() -> void:
					PlayerState.place_skill(slot, s.id)
					_say("ok", "%s 已装配到第%d格" % [s.name, slot + 1]))
				row.add_child(eb)
		else:
			var pb := UiStyle.button("设为被动" if PlayerState.passive_skill != s.id else "当前被动", 16)
			pb.disabled = PlayerState.passive_skill == s.id
			pb.pressed.connect(func() -> void:
				PlayerState.equip_passive(s.id)
				_say("ok", "被动已设为 %s" % s.name))
			row.add_child(pb)
	if bk:
		var row2 := HBoxContainer.new(); row2.add_theme_constant_override("separation", 8); detail_box.add_child(row2)
		var db := UiStyle.button("分解重复书 +%d残页" % bk.decompose_pages, 15)
		db.disabled = lv <= 0 or PlayerState.book_count(bk.id) <= 0
		db.pressed.connect(func() -> void: _say(PlayerState.decompose_book(bk.id), "分解%s，悟道残页+%d" % [bk.name, bk.decompose_pages]))
		row2.add_child(db)
		var unlocked := PlayerState.map_unlocked(bk.region_map_id)
		var xb := UiStyle.button("残页兑换（%d张）%s" % [bk.exchange_pages, "" if unlocked else "·区域未解锁"], 15)
		xb.disabled = not unlocked or PlayerState.item_count(PlayerState.PAGE_ID) < bk.exchange_pages
		xb.pressed.connect(func() -> void: _say(PlayerState.exchange_book(bk.id), "兑换得到%s" % bk.name))
		row2.add_child(xb)
		var src := UiStyle.label("获取：" + bk.source_desc, 14, Color(0.75, 0.75, 0.7)); src.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; src.custom_minimum_size = Vector2(520, 0)
		detail_box.add_child(src)

func _fmt(v: float) -> String:
	return ("%.0f%%" % (v * 100.0)) if absf(v) < 5.0 and v != 0.0 else ("%.2f" % v)

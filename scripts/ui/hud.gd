class_name Hud
extends CanvasLayer
## 战斗界面（v2 宣纸水墨定调图 art/style/v2/07_battle_ui_mockup.png）。CanvasLayer + Control，随窗口缩放（canvas_items/expand）。
## 左上境界圆章与牌匾；顶部居中灵石/修为；右上关卡牌匾、存档圆章、挑战按钮；中上波次/首领血条/横幅；
## 屏幕中央情境引导；底部一行：生命/护盾框、4 格技能栏 + 闪避圆章、自动战斗开关 + 装备/功法/地图/突破圆章。
## 上屏文字全部来自 ui_texts（UiText.t）；打开养成面板时暂停战斗（get_tree().paused），HUD 本身 process_mode=ALWAYS 仍可操作。

const SLOT_SCENE := preload("res://scenes/ui/skill_slot.tscn")
## 面板：[内部 ID, 入口文案 key]。内部 ID 只用于代码，绝不上屏；标题一律用入口文案（NAV_*）。
const NAV := [["gear", "NAV_GEAR"], ["gongfa", "NAV_GONGFA"], ["map", "NAV_MAP"], ["break", "NAV_BREAK"]]

var battle: Battle
var root: Control
var realm_label: Label
var lingshi_label: Label
var xiuwei_label: Label
var level_label: Label
var save_label: Label
var wave_label: Label
var wave_box: PanelContainer
var mode_label: Label
var boss_box: VBoxContainer
var boss_name: Label
var boss_stun: Label
var boss_bar: ProgressBar
var banner_label: Label
var hint_label: Label
var hint_sub: Label
var hint_key: PanelContainer
var hp_bar: ProgressBar
var hp_text: Label
var shield_bar: ProgressBar
var shield_text: Label
var slots: Array[SkillSlotUI] = []
var dodge_btn: Button
var dodge_plaque: Control
var auto_btn: Button
var challenge_btn: Button
var bottom_row: HBoxContainer
var panel: PanelContainer
var panel_title: Label
var panel_body: VBoxContainer
var gear_panel: GearPanel
var gongfa_panel: GongfaPanel
var dim: ColorRect
var open_id := ""
var _banner_t := 0.0
var _hint_pulse := 0.0

func _ready() -> void:
	root = $Root
	_build()

func bind(b: Battle) -> void:
	battle = b
	b.run_started.connect(func(_l: LevelDef, _m: int) -> void: _refresh_top())
	b.wave_changed.connect(func(_i: int, _n: int) -> void: _refresh_top())
	b.boss_spawned.connect(func(_bs: Boss) -> void: _refresh_top())
	b.phase_changed.connect(func(_p: int) -> void: _refresh_top())
	b.banner.connect(show_banner)
	b.tutorial.hint_shown.connect(func(_id: String, text: String) -> void: _show_hint(text))
	b.tutorial.hint_hidden.connect(func(_id: String, _ok: bool) -> void: _show_hint(""))
	b.player.hp_changed.connect(_on_hp)
	b.player.shield_changed.connect(_on_shield)
	_on_hp(b.player.hp, b.player.max_hp)
	_on_shield(b.player.shield_total(), b.player.max_hp)
	PlayerState.currencies_changed.connect(_refresh_top)
	PlayerState.progress_changed.connect(_refresh_top)
	PlayerState.auto_battle_changed.connect(func(_e: bool) -> void: _refresh_auto())
	PlayerState.loot_notice.connect(show_banner)
	b.loot_dropped.connect(_on_loot)
	_refresh_top()
	_refresh_auto()

## 放到 root 上并按锚点定位：底部锚点向上长，右侧锚点向左长，居中锚点两侧对称长（BUG-008：不写死尺寸）
func _anchored(c: Control, preset: int, pos: Vector2) -> Control:
	root.add_child(c)
	c.set_anchors_preset(preset)
	var bottom := preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM, Control.PRESET_BOTTOM_WIDE]
	var right := preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT]
	var center := preset in [Control.PRESET_CENTER_TOP, Control.PRESET_CENTER_BOTTOM]
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH if center else (Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END)
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN if bottom else Control.GROW_DIRECTION_END
	c.offset_left = pos.x; c.offset_top = pos.y; c.offset_bottom = pos.y
	c.offset_right = -pos.x if preset == Control.PRESET_BOTTOM_WIDE else pos.x
	return c

func _framed(min_size: Vector2, sb: StyleBox = null, cloud := false) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", sb if sb else UiStyle.panel(10))
	pc.custom_minimum_size = min_size
	var fr := InkFrame.new(); fr.inset = 4; fr.corner = 12; fr.cloud = cloud
	pc.add_child(fr)
	return pc

## 顶部资源药丸：图标 + 文案（HUD_LINGSHI / HUD_XIUWEI 自带名称与数值）
func _pill(kind: String) -> Array:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiStyle.pill_box(38))
	pc.custom_minimum_size = Vector2(176, 38)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8); pc.add_child(h)
	h.add_child(GlyphIcon.new(kind, 28))
	var v := UiStyle.label("", 18, UiStyle.GOLD_TEXT); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(v)
	return [pc, v]

func _build() -> void:
	# ---- 左上：境界圆章 + 牌匾 ----
	var tl := HBoxContainer.new(); tl.add_theme_constant_override("separation", -10)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchored(tl, Control.PRESET_TOP_LEFT, Vector2(14, 10))
	var med := PanelContainer.new()
	var msb := UiStyle.panel(32, UiStyle.GOLD_LINE, 0.95); msb.set_border_width_all(2)
	msb.set_content_margin_all(8)
	med.add_theme_stylebox_override("panel", msb)
	med.add_child(GlyphIcon.new("taiji", 46))
	med.z_index = 1
	tl.add_child(med)
	var rp := _framed(Vector2(170, 50))
	var rsb := UiStyle.panel(4, UiStyle.GOLD_LINE, 0.85); rsb.content_margin_left = 24; rsb.content_margin_right = 18
	rp.add_theme_stylebox_override("panel", rsb)
	rp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	realm_label = UiStyle.title("", 28); realm_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rp.add_child(realm_label); rp.move_child(realm_label, 0)
	tl.add_child(rp)
	# ---- 顶部居中：灵石 / 修为 ----
	var tc := HBoxContainer.new(); tc.add_theme_constant_override("separation", 22)
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchored(tc, Control.PRESET_CENTER_TOP, Vector2(0, 16))
	var p1 := _pill("jade"); tc.add_child(p1[0]); lingshi_label = p1[1]
	var p2 := _pill("taiji"); tc.add_child(p2[0]); xiuwei_label = p2[1]
	# ---- 右上：关卡牌匾 + 存档圆章；挑战按钮 ----
	var tr := VBoxContainer.new(); tr.add_theme_constant_override("separation", 6)
	_anchored(tr, Control.PRESET_TOP_RIGHT, Vector2(-14, 8))
	var trh := HBoxContainer.new(); trh.add_theme_constant_override("separation", 10); tr.add_child(trh)
	var lp := _framed(Vector2(250, 62), UiStyle.panel(6, UiStyle.GOLD_LINE, 0.88), true)
	var lv := VBoxContainer.new(); lv.add_theme_constant_override("separation", -2); lv.alignment = BoxContainer.ALIGNMENT_CENTER
	level_label = UiStyle.title("", 21); level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lv.add_child(level_label)
	mode_label = UiStyle.label("", 13, Color(UiStyle.GOLD_TEXT, 0.8)); mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lv.add_child(mode_label)
	lp.add_child(lv); lp.move_child(lv, 0)
	trh.add_child(lp)
	var sv := VBoxContainer.new(); sv.add_theme_constant_override("separation", 2); sv.alignment = BoxContainer.ALIGNMENT_CENTER
	var sbtn := UiStyle.medallion("", 52, 18)
	sbtn.tooltip_text = UiText.t("HUD_SAVE_PENDING")
	var sg := GlyphIcon.new("save", 30); sg.set_anchors_and_offsets_preset(Control.PRESET_CENTER); sg.position -= Vector2(15, 15)
	sbtn.add_child(sg)
	sv.add_child(sbtn)
	save_label = UiStyle.label(UiText.t("HUD_SAVE_PENDING"), 12, Color(0.78, 0.75, 0.66)); save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(save_label)
	trh.add_child(sv)
	challenge_btn = UiStyle.accent_button(UiText.t("BTN_CHALLENGE_NONE"), 16)
	challenge_btn.custom_minimum_size = Vector2(250, 34)
	challenge_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	challenge_btn.pressed.connect(_on_challenge_next)
	tr.add_child(challenge_btn)
	# ---- 中上：波次 / 首领 / 横幅 ----
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 4)
	mid.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	mid.offset_top = 66; mid.offset_left = -280; mid.offset_right = 280
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mid)
	wave_box = PanelContainer.new()
	var wsb := UiStyle.pill_box(34); wsb.content_margin_left = 24; wsb.content_margin_right = 24
	wave_box.add_theme_stylebox_override("panel", wsb)
	wave_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wave_label = UiStyle.subtitle("", 24); wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; wave_box.add_child(wave_label)
	mid.add_child(wave_box)
	boss_box = VBoxContainer.new(); boss_box.add_theme_constant_override("separation", 2); mid.add_child(boss_box)
	var bnr := HBoxContainer.new(); bnr.alignment = BoxContainer.ALIGNMENT_CENTER; bnr.add_theme_constant_override("separation", 10); boss_box.add_child(bnr)
	boss_name = UiStyle.title("", 24, Color("#E8B0A0")); bnr.add_child(boss_name)
	boss_stun = UiStyle.label(UiText.t("FLOAT_STUN"), 15, Color("#FFE08A")); boss_stun.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	boss_stun.visible = false; bnr.add_child(boss_stun)
	boss_bar = UiStyle.bar(UiStyle.HP.lightened(0.15)); boss_bar.custom_minimum_size = Vector2(560, 14); boss_box.add_child(boss_bar)
	banner_label = UiStyle.label("", 18, UiStyle.GOLD_TEXT); banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; banner_label.custom_minimum_size = Vector2(560, 0); mid.add_child(banner_label)
	# ---- 屏幕中央：情境引导（主句 / 空格键图标 / 自动模式小字，BUG-004） ----
	hint_label = UiStyle.title("", 52, UiStyle.MIST)
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hint_label.offset_left = -440; hint_label.offset_right = 440; hint_label.offset_top = -150; hint_label.offset_bottom = -82
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_constant_override("outline_size", 10)
	root.add_child(hint_label)
	hint_key = PanelContainer.new()
	var ksb := UiStyle.panel(6, UiStyle.MIST, 0.8); ksb.set_border_width_all(2); ksb.border_width_bottom = 5
	ksb.content_margin_left = 40; ksb.content_margin_right = 40; ksb.content_margin_top = 2; ksb.content_margin_bottom = 2
	hint_key.add_theme_stylebox_override("panel", ksb)
	hint_key.add_child(UiStyle.label(UiText.t("HINT_KEY_SPACE"), 20, UiStyle.MIST))
	hint_key.set_anchors_preset(Control.PRESET_CENTER)
	hint_key.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_key.offset_left = 0; hint_key.offset_right = 0; hint_key.offset_top = -74; hint_key.offset_bottom = -74
	hint_key.visible = false
	hint_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint_key)
	hint_sub = UiStyle.label("", 19, UiStyle.MIST)
	hint_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hint_sub.offset_left = -440; hint_sub.offset_right = 440; hint_sub.offset_top = -30; hint_sub.offset_bottom = -2
	hint_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint_sub)
	# ---- 底部一行（BUG-008：整行按内容最小高度自底向上长；两侧等宽，技能栏居中） ----
	var bottom := MarginContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchored(bottom, Control.PRESET_BOTTOM_WIDE, Vector2(14, -10))
	bottom_row = HBoxContainer.new(); bottom_row.add_theme_constant_override("separation", 10)
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(bottom_row)
	# 左：生命 / 护盾框（hp_bar → bars → 框 → 底部一行）
	var bl := _framed(Vector2(330, 0), UiStyle.panel(10, UiStyle.GOLD_LINE, 0.84))
	var blsb := UiStyle.panel(10, UiStyle.GOLD_LINE, 0.84); blsb.content_margin_left = 66; blsb.content_margin_top = 10; blsb.content_margin_bottom = 10
	bl.add_theme_stylebox_override("panel", blsb)
	bl.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom_row.add_child(bl)
	var bars := VBoxContainer.new(); bars.add_theme_constant_override("separation", 6)
	bl.add_child(bars); bl.move_child(bars, 0)
	hp_bar = UiStyle.bar(UiStyle.HP.lightened(0.1)); hp_bar.custom_minimum_size = Vector2(250, 24); bars.add_child(hp_bar)
	hp_text = _bar_text(hp_bar, 15, UiStyle.GOLD_TEXT)
	shield_bar = UiStyle.bar(UiStyle.SHIELD_C); shield_bar.custom_minimum_size = Vector2(250, 20); bars.add_child(shield_bar)
	shield_text = _bar_text(shield_bar, 13, UiStyle.MIST)
	var emblem := GlyphIcon.new("shield", 46)
	hp_bar.add_child(emblem)   # 进度条不是容器：徽记可放在框左侧留白处，横跨两条
	emblem.position = Vector2(-56, 0)
	bars.add_child(UiStyle.label(UiText.t("HUD_CONTROLS"), 12, Color(UiStyle.GOLD_TEXT, 0.6)))
	bottom_row.add_child(UiStyle.spacer())
	# 中：4 格技能 + 闪避圆章
	var bc := HBoxContainer.new(); bc.add_theme_constant_override("separation", 12)
	bc.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom_row.add_child(bc)
	for i in PlayerState.slot_count():
		var s: SkillSlotUI = SLOT_SCENE.instantiate()
		s.slot = i
		bc.add_child(s)
		s.cast_requested.connect(func(slot: int) -> void:
			if battle and not get_tree().paused:
				battle.controller.request_skill(slot))
		s.auto_toggled.connect(func(slot: int) -> void: PlayerState.set_slot_auto(slot, not PlayerState.slot_auto[slot]))
		slots.append(s)
	var dv := VBoxContainer.new(); dv.add_theme_constant_override("separation", -8)
	dodge_btn = UiStyle.medallion(UiText.t("BTN_DODGE"), 84, 30)
	dodge_btn.pressed.connect(func() -> void:
		if battle and not get_tree().paused:
			battle.controller.request_dodge())
	dv.add_child(dodge_btn)
	dodge_plaque = UiStyle.plaque(UiText.t("HUD_KEY_SPACE"), 13); dodge_plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; dodge_plaque.z_index = 1
	dv.add_child(dodge_plaque)
	bc.add_child(dv)
	bottom_row.add_child(UiStyle.spacer())
	# 右：自动战斗开关 + 四个圆章入口（与左侧同宽，技能栏保持居中）
	var br := VBoxContainer.new(); br.add_theme_constant_override("separation", 8); br.alignment = BoxContainer.ALIGNMENT_END
	br.custom_minimum_size = Vector2(330, 0)
	br.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom_row.add_child(br)
	auto_btn = UiStyle.button(UiText.t("BTN_AUTO_ON"), 16)
	auto_btn.custom_minimum_size = Vector2(140, 32)
	auto_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	auto_btn.pressed.connect(func() -> void: PlayerState.set_auto_battle(not PlayerState.auto_battle))
	br.add_child(auto_btn)
	var meds := HBoxContainer.new(); meds.add_theme_constant_override("separation", 12); meds.alignment = BoxContainer.ALIGNMENT_END
	br.add_child(meds)
	for pair in NAV:
		var v := VBoxContainer.new(); v.add_theme_constant_override("separation", -6)
		var b := UiStyle.medallion(UiText.t(pair[1] + "_SHORT"), 60, 30)
		var id: String = pair[0]
		b.pressed.connect(func() -> void: open_panel(id))
		v.add_child(b)
		var pl := UiStyle.plaque(UiText.t(pair[1]), 13); pl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; pl.z_index = 1
		v.add_child(pl)
		meds.add_child(v)
	# ---- 面板遮罩（打开养成面板时压暗战斗画面） ----
	dim = ColorRect.new(); dim.color = Color(0.03, 0.04, 0.03, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	# ---- 地图 / 突破面板 ----
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.big_panel())
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -360; panel.offset_right = 360; panel.offset_top = -270; panel.offset_bottom = 250
	panel.visible = false
	root.add_child(panel)
	var pv := VBoxContainer.new(); pv.add_theme_constant_override("separation", 10); panel.add_child(pv)
	var ph := HBoxContainer.new(); pv.add_child(ph)
	panel_title = UiStyle.title("", 34); panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ph.add_child(panel_title)
	var close := UiStyle.button(UiText.t("BTN_CLOSE"), 16); close.pressed.connect(close_panel); ph.add_child(close)
	pv.add_child(UiStyle.hsep())
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pv.add_child(scroll)
	panel_body = VBoxContainer.new(); panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; panel_body.add_theme_constant_override("separation", 6); scroll.add_child(panel_body)
	panel.add_child(InkFrame.new())
	# ---- 正式养成面板：装备 / 功法 ----
	gear_panel = GearPanel.new(); gear_panel.visible = false; root.add_child(gear_panel)
	gear_panel.closed.connect(close_panel)
	gongfa_panel = GongfaPanel.new(); gongfa_panel.visible = false; root.add_child(gongfa_panel)
	gongfa_panel.closed.connect(close_panel)

func _bar_text(bar: ProgressBar, size: int, color: Color) -> Label:
	var l := UiStyle.label("", size, color)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	bar.add_child(l)
	return l

func _level_text(l: LevelDef) -> String:
	var m := GameData.get_map(l.map_id)
	return UiText.t("HUD_LEVEL", {"map_name": m.name if m else "", "level_index": l.index, "level_name": l.name})

## 面板入口文案 key：接受内部 ID（gear/gongfa/map/break）或入口显示文字（与 ui_texts 的 NAV_* 一致，兼容 QA 脚本）
static func nav_key(id: String) -> String:
	for pair in NAV:
		if id == pair[0] or id == UiText.t(pair[1]):
			return pair[1]
	return ""

static func nav_id(id: String) -> String:
	for pair in NAV:
		if id == pair[0] or id == UiText.t(pair[1]):
			return pair[0]
	return ""

## 面板标题：永远是入口文案（NAV_*）+“战斗暂停”，不会把内部 ID 显示出来
static func panel_title_text(id: String) -> String:
	var k := nav_key(id)
	return UiText.t("PANEL_TITLE_PAUSED", {"title": UiText.t(k)}) if k != "" else ""

func is_panel_open() -> bool:
	return panel.visible or gear_panel.visible or gongfa_panel.visible

func open_panel(id: String) -> void:
	var pid := nav_id(id)
	if pid == "":
		push_warning("Hud.open_panel: 未知面板 %s" % id)
		return
	panel.visible = false; gear_panel.visible = false; gongfa_panel.visible = false
	open_id = pid
	dim.visible = true
	get_tree().paused = true
	if pid == "gear" or pid == "gongfa":
		var pc: Control = gear_panel if pid == "gear" else gongfa_panel
		pc.call("open")
		UiStyle.pop_in(pc)
		return
	panel_title.text = panel_title_text(pid)
	for c in panel_body.get_children():
		panel_body.remove_child(c); c.queue_free()
	if pid == "map":
		for l in GameData.levels_ordered:
			panel_body.add_child(_map_row(l))
	else:
		var l := UiStyle.subtitle(UiText.t("PANEL_BREAK_SOON"), 26, UiStyle.GOLD_TEXT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(600, 120)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel_body.add_child(l)
	panel.visible = true
	UiStyle.pop_in(panel)

## 地图面板一行：按钮文字为关卡名（HUD_LEVEL），状态用右侧小签显示（不在代码里拼接文案）
func _map_row(l: LevelDef) -> Button:
	var cleared := PlayerState.is_cleared(l.id)
	var can := PlayerState.can_challenge(l.id)
	var b := PanelKit.row(_level_text(l), UiStyle.GOLD_LINE if can else Color(0.4, 0.4, 0.38), battle != null and battle.level == l, 17)
	b.disabled = not can
	var tags := HBoxContainer.new(); tags.add_theme_constant_override("separation", 6)
	tags.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	tags.grow_horizontal = Control.GROW_DIRECTION_BEGIN; tags.grow_vertical = Control.GROW_DIRECTION_BOTH
	tags.offset_right = -10; tags.offset_left = -10
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tags)
	var tk := "MAP_TAG_CLEARED" if cleared else ("MAP_TAG_OPEN" if can else "MAP_TAG_LOCKED")
	tags.add_child(_tag(UiText.t(tk), UiStyle.GOOD if cleared else (UiStyle.GOLD_TEXT if can else Color(0.6, 0.58, 0.52))))
	if PlayerState.is_unstable(l.id):
		tags.add_child(_tag(UiText.t("MAP_TAG_UNSTABLE"), UiStyle.BAD))
	var lid := l.id
	b.pressed.connect(func() -> void:
		close_panel()
		battle.challenge(lid))
	return b

func _tag(text: String, color: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := UiStyle.panel(4, color, 0.7); sb.content_margin_top = 0; sb.content_margin_bottom = 0; sb.content_margin_left = 8; sb.content_margin_right = 8
	pc.add_theme_stylebox_override("panel", sb)
	pc.add_child(UiStyle.label(text, 13, color))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pc

func close_panel() -> void:
	panel.visible = false
	gear_panel.visible = false
	gongfa_panel.visible = false
	dim.visible = false
	open_id = ""
	get_tree().paused = false
	if battle:
		battle.refresh_player_stats()   # 换装/升级/换被动立即生效（保持当前生命比例）

func _on_loot(entries: Array) -> void:
	var parts: Array[String] = []
	for e in entries:
		if not (str(e.beam) in ["", "none"]):
			parts.append(str(e.text))
	if not parts.is_empty():
		show_banner(UiText.t("BANNER_LOOT", {"items": "、".join(parts)}))

func _on_challenge_next() -> void:
	if is_panel_open():
		close_panel()   # QA 观测4：先关面板再开新一局
	var nxt := PlayerState.next_challenge_level()
	if nxt and battle:
		battle.challenge(nxt.id)
	else:
		show_banner(UiText.t("BANNER_NO_NEW_LEVEL"))

func show_banner(text: String) -> void:
	banner_label.text = text
	_banner_t = 5.0
	banner_label.modulate.a = 0.0
	var tw := banner_label.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(banner_label, "modulate:a", 1.0, 0.2)

## 引导文字：第一行主句；第二行（若有）为自动模式小字（tutorial_steps.sub_text）；有主句时显示空格键图标
func _show_hint(text: String) -> void:
	var parts := text.split("\n", true, 1)
	hint_label.text = parts[0]
	hint_sub.text = parts[1] if parts.size() > 1 else ""
	hint_key.visible = parts[0] != ""
	_hint_pulse = 0.0

func _on_hp(hp: float, max_hp: float) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_text.text = "%s　%s / %s" % [UiText.t("HUD_HP"), UiStyle.num(ceil(hp)), UiStyle.num(max_hp)]

func _on_shield(total: float, max_hp: float) -> void:
	shield_bar.max_value = maxf(max_hp * 0.3, 1.0)
	shield_bar.value = total
	shield_text.text = "%s　%s" % [UiText.t("HUD_SHIELD"), UiStyle.num(total)]

func _refresh_auto() -> void:
	var on := PlayerState.auto_battle
	auto_btn.text = UiText.t("BTN_AUTO_ON" if on else "BTN_AUTO_OFF")
	auto_btn.add_theme_stylebox_override("normal", UiStyle._btn_box(Color("#2F5A47") if on else Color(UiStyle.INK, 0.9), UiStyle.GOLD_TEXT if on else UiStyle.GOLD_LINE, 16, 2 if on else 1))
	auto_btn.add_theme_color_override("font_color", Color("#BFF0D8") if on else UiStyle.GOLD_TEXT)

func _refresh_top() -> void:
	if realm_label == null:
		return
	var rl := GameData.get_realm(PlayerState.realm_id)
	realm_label.text = UiText.t("HUD_REALM", {"realm_name": rl.name if rl else ""})
	lingshi_label.text = UiText.t("HUD_LINGSHI", {"value": PlayerState.lingshi})
	xiuwei_label.text = UiText.t("HUD_XIUWEI", {"value": PlayerState.xiuwei})
	var nxt := PlayerState.next_challenge_level()
	challenge_btn.disabled = nxt == null
	challenge_btn.text = UiText.t("BTN_CHALLENGE", {"level_name": nxt.name}) if nxt else UiText.t("BTN_CHALLENGE_NONE")
	if battle == null or battle.level == null:
		return
	level_label.text = _level_text(battle.level)
	mode_label.text = UiText.t(["HUD_MODE_CHALLENGE", "HUD_MODE_FARM", "HUD_MODE_FARM_NORMALS"][battle.mode])
	boss_box.visible = battle.phase == Battle.Phase.BOSS and battle.boss != null

func _process(delta: float) -> void:
	if battle == null:
		return
	var p := battle.phase
	if p == Battle.Phase.BOSS and battle.boss:
		wave_label.text = UiText.t("HUD_BOSS_FIGHT", {"timer": UiText.t("HUD_BOSS_TIMER", {"sec": int(ceil(maxf(battle.boss_time_left, 0.0)))})})
		boss_name.text = battle.boss.def.name
		boss_bar.max_value = battle.boss.max_hp
		boss_bar.value = battle.boss.hp
		boss_stun.visible = battle.boss.stun_t > 0.0
	elif p == Battle.Phase.BOSS_INTRO:
		wave_label.text = UiText.t("HUD_BOSS_INCOMING")
	elif p == Battle.Phase.VICTORY:
		wave_label.text = UiText.t("HUD_RESULT_CLEAR")
	elif p == Battle.Phase.DEFEAT:
		wave_label.text = UiText.t("HUD_RESULT_FAIL")
	elif battle.level:
		# BUG-011：新一轮行进阶段（wave_index=0）显示即将到来的第1波，不再残留上一轮的“第4/4波”
		var wi := battle.wave_index + (1 if p == Battle.Phase.WALK else 0)
		var wt := UiText.t("HUD_WAVE", {"wave": clampi(wi, 1, battle.level.wave_count), "wave_total": battle.level.wave_count})
		wave_label.text = UiText.t("HUD_WAVE_WALK", {"wave_text": wt}) if p == Battle.Phase.WALK else wt
	boss_box.visible = p == Battle.Phase.BOSS and battle.boss != null
	wave_box.visible = wave_label.text != ""
	for i in slots.size():
		var cdt := battle.skills.cd_totals[i] if i < battle.skills.cd_totals.size() else 0.0
		slots[i].refresh(battle.skills.skill_in_slot(i), PlayerState.slot_auto[i], battle.skills.cds[i], cdt)
	var pl := battle.player
	var on_cd := pl.dodge_cd > 0.0
	dodge_btn.text = ("%.1f" % pl.dodge_cd) if on_cd else UiText.t("BTN_DODGE")
	dodge_btn.add_theme_font_size_override("font_size", 26 if on_cd else 30)
	dodge_btn.disabled = on_cd
	if hint_label.text != "":
		_hint_pulse += delta
		var pulse := 0.6 + 0.4 * absf(sin(_hint_pulse * 6.0))
		hint_label.modulate.a = pulse
		dodge_btn.modulate = Color(1.0, 0.85 + 0.15 * pulse, 0.5 + 0.5 * pulse)
	else:
		dodge_btn.modulate = Color.WHITE
	if _banner_t > 0.0:
		_banner_t -= delta
		banner_label.modulate.a = minf(banner_label.modulate.a, clampf(_banner_t / 0.5, 0.0, 1.0))
		if _banner_t <= 0.0:
			banner_label.text = ""

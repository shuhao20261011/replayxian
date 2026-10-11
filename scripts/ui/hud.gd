class_name Hud
extends CanvasLayer
## 战斗界面（CanvasLayer + Control，随窗口缩放）。布局参考 docs/07_battle_ui_mockup.png：
## 顶部：境界/灵石/修为/区域关卡/存档状态；中上：波次、首领血条与限时、提示横幅；
## 底部：生命/护盾、4格技能栏、闪避、自动开关、挑战按钮、装备/功法/地图/突破入口。
## 打开养成面板时暂停战斗（get_tree().paused），HUD 本身 process_mode=ALWAYS 仍可操作。

const SLOT_SCENE := preload("res://scenes/ui/skill_slot.tscn")

var battle: Battle
var root: Control
var realm_label: Label
var lingshi_label: Label
var xiuwei_label: Label
var level_label: Label
var save_label: Label
var wave_label: Label
var mode_label: Label
var boss_box: VBoxContainer
var boss_name: Label
var boss_bar: ProgressBar
var banner_label: Label
var hint_label: Label
var hint_sub: Label
var hp_bar: ProgressBar
var hp_text: Label
var shield_bar: ProgressBar
var shield_text: Label
var slots: Array[SkillSlotUI] = []
var dodge_btn: Button
var auto_btn: Button
var challenge_btn: Button
var panel: PanelContainer
var panel_title: Label
var panel_body: VBoxContainer
var gear_panel: GearPanel
var realm_sub: Label
var wave_box: PanelContainer
var dodge_plaque: Control
var dim: ColorRect
var gongfa_panel: GongfaPanel
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

func _anchored(c: Control, preset: int, pos: Vector2) -> Control:
	root.add_child(c)
	c.set_anchors_preset(preset)
	# 锚点相对偏移；尺寸由内容最小尺寸决定（向右/向下生长）
	# pos = 到锚点边的偏移：底部锚点向上长，右侧锚点向左长，居中锚点两侧对称长
	var bottom := preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM]
	var right := preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT]
	var center := preset in [Control.PRESET_CENTER_TOP, Control.PRESET_CENTER_BOTTOM]
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH if center else (Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END)
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN if bottom else Control.GROW_DIRECTION_END
	c.offset_left = pos.x; c.offset_right = pos.x
	c.offset_top = pos.y; c.offset_bottom = pos.y
	return c

func _framed(min_size: Vector2, sb: StyleBox = null) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", sb if sb else UiStyle.panel(10))
	pc.custom_minimum_size = min_size
	var fr := InkFrame.new(); fr.inset = 4; fr.corner = 12; fr.cloud = false
	pc.add_child(fr)
	return pc

func _pill(kind: String, title: String) -> Array:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiStyle.pill_box(38))
	pc.custom_minimum_size = Vector2(176, 38)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8); pc.add_child(h)
	var ic := GlyphIcon.new(kind, 28); h.add_child(ic)
	h.add_child(UiStyle.label(title, 14, Color(UiStyle.GOLD_TEXT, 0.75)))
	var v := UiStyle.label("0", 20, UiStyle.GOLD_TEXT); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(v)
	return [pc, v]

func _build() -> void:
	# ---- 左上：境界圆章 + 牌匾 ----
	var tl := HBoxContainer.new(); tl.add_theme_constant_override("separation", -10)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchored(tl, Control.PRESET_TOP_LEFT, Vector2(14, 10))
	var med := PanelContainer.new()
	var msb := UiStyle.panel(32, UiStyle.GOLD_LINE, 0.95); msb.set_border_width_all(2)
	msb.content_margin_left = 8; msb.content_margin_right = 8; msb.content_margin_top = 8; msb.content_margin_bottom = 8
	med.add_theme_stylebox_override("panel", msb)
	med.add_child(GlyphIcon.new("taiji", 46))
	med.z_index = 1
	tl.add_child(med)
	var rp := _framed(Vector2(200, 50))
	var rsb := UiStyle.panel(4, UiStyle.GOLD_LINE, 0.85); rsb.content_margin_left = 22
	rp.add_theme_stylebox_override("panel", rsb)
	rp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rh := HBoxContainer.new(); rh.add_theme_constant_override("separation", 12); rp.add_child(rh)
	realm_label = UiStyle.title("", 30); rh.add_child(realm_label)
	realm_sub = UiStyle.label("", 13, Color(UiStyle.GOLD_TEXT, 0.75)); realm_sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER; rh.add_child(realm_sub)
	rp.move_child(rp.get_child(0), rp.get_child_count() - 1)
	tl.add_child(rp)
	# ---- 顶部居中：灵石 / 修为 ----
	var tc := HBoxContainer.new(); tc.add_theme_constant_override("separation", 22)
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchored(tc, Control.PRESET_CENTER_TOP, Vector2(0, 16))
	var p1 := _pill("jade", "灵石"); tc.add_child(p1[0]); lingshi_label = p1[1]
	var p2 := _pill("taiji", "修为"); tc.add_child(p2[0]); xiuwei_label = p2[1]
	# ---- 右上：关卡牌匾 + 存档 ----
	var tr := VBoxContainer.new(); tr.add_theme_constant_override("separation", 6)
	tr.alignment = BoxContainer.ALIGNMENT_BEGIN
	_anchored(tr, Control.PRESET_TOP_RIGHT, Vector2(-14, 8))
	tr.custom_minimum_size = Vector2(316, 0)
	var trh := HBoxContainer.new(); trh.add_theme_constant_override("separation", 10); tr.add_child(trh)
	var lp := _framed(Vector2(236, 62), UiStyle.panel(6, UiStyle.GOLD_LINE, 0.88))
	(lp.get_child(0) as InkFrame).cloud = true
	var lv := VBoxContainer.new(); lv.add_theme_constant_override("separation", -4); lv.alignment = BoxContainer.ALIGNMENT_CENTER
	level_label = UiStyle.title("", 26); level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lv.add_child(level_label)
	mode_label = UiStyle.label("", 13, Color(UiStyle.GOLD_TEXT, 0.75)); mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lv.add_child(mode_label)
	lp.add_child(lv); lp.move_child(lv, 0)
	trh.add_child(lp)
	var sv := VBoxContainer.new(); sv.add_theme_constant_override("separation", 2); sv.alignment = BoxContainer.ALIGNMENT_CENTER
	var sbtn := UiStyle.medallion("", 52, 18)
	sbtn.tooltip_text = "存档系统在阶段6接入"
	var sg := GlyphIcon.new("save", 30); sg.set_anchors_and_offsets_preset(Control.PRESET_CENTER); sg.position -= Vector2(15, 15)
	sbtn.add_child(sg)
	sv.add_child(sbtn)
	save_label = UiStyle.label("未存档", 12, Color(0.7, 0.68, 0.6)); save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(save_label)
	trh.add_child(sv)
	challenge_btn = UiStyle.accent_button("挑战下一关", 16)
	challenge_btn.custom_minimum_size = Vector2(236, 34)
	challenge_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	challenge_btn.pressed.connect(_on_challenge_next)
	tr.add_child(challenge_btn)
	# ---- 中上：波次 / 首领 / 横幅 ----
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 4)
	mid.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	mid.offset_top = 66; mid.offset_left = -270; mid.offset_right = 270
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mid)
	wave_box = PanelContainer.new()
	var wsb := UiStyle.pill_box(34); wsb.content_margin_left = 22; wsb.content_margin_right = 22
	wave_box.add_theme_stylebox_override("panel", wsb)
	wave_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wave_label = UiStyle.subtitle("", 24); wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; wave_box.add_child(wave_label)
	mid.add_child(wave_box)
	boss_box = VBoxContainer.new(); boss_box.add_theme_constant_override("separation", 2); mid.add_child(boss_box)
	boss_name = UiStyle.title("", 24, Color("#E8B0A0")); boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; boss_box.add_child(boss_name)
	boss_bar = UiStyle.bar(UiStyle.HP.lightened(0.15)); boss_bar.custom_minimum_size = Vector2(540, 14); boss_box.add_child(boss_bar)
	banner_label = UiStyle.label("", 18, UiStyle.GOLD_TEXT); banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; banner_label.custom_minimum_size = Vector2(540, 0); mid.add_child(banner_label)
	# ---- 屏幕中央：情境引导提示 ----
	hint_label = UiStyle.title("", 52, UiStyle.MIST)
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hint_label.offset_left = -420; hint_label.offset_right = 420; hint_label.offset_top = -130; hint_label.offset_bottom = -60
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_constant_override("outline_size", 10)
	root.add_child(hint_label)
	hint_sub = UiStyle.label("", 20, UiStyle.MIST)
	hint_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hint_sub.offset_left = -420; hint_sub.offset_right = 420; hint_sub.offset_top = -56; hint_sub.offset_bottom = -26
	hint_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint_sub)
	# ---- 左下：生命 / 护盾框 ----
	var bl := _framed(Vector2(330, 112), UiStyle.panel(10, UiStyle.GOLD_LINE, 0.84))
	_anchored(bl, Control.PRESET_BOTTOM_LEFT, Vector2(14, -14))
	var blh := HBoxContainer.new(); blh.add_theme_constant_override("separation", 10); bl.add_child(blh); bl.move_child(blh, 0)
	blh.add_child(GlyphIcon.new("shield", 44))
	var bars := VBoxContainer.new(); bars.add_theme_constant_override("separation", 6); bars.alignment = BoxContainer.ALIGNMENT_CENTER
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blh.add_child(bars)
	hp_bar = UiStyle.bar(UiStyle.HP.lightened(0.1)); hp_bar.custom_minimum_size = Vector2(250, 24); bars.add_child(hp_bar)
	hp_text = UiStyle.label("", 15, UiStyle.GOLD_TEXT); hp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; hp_bar.add_child(hp_text)
	shield_bar = UiStyle.bar(UiStyle.SHIELD_C); shield_bar.custom_minimum_size = Vector2(250, 20); bars.add_child(shield_bar)
	shield_text = UiStyle.label("", 13, UiStyle.MIST); shield_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shield_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; shield_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; shield_bar.add_child(shield_text)
	bars.add_child(UiStyle.label("A/D 移动 · 1-4 技能 · 空格 闪避 · Q 自动", 12, Color(UiStyle.GOLD_TEXT, 0.55)))
	# ---- 底部中：技能栏 + 闪避 ----
	var bc := HBoxContainer.new(); bc.add_theme_constant_override("separation", 12)
	_anchored(bc, Control.PRESET_CENTER_BOTTOM, Vector2(-20, -12))
	for i in PlayerState.slot_count():
		var s: SkillSlotUI = SLOT_SCENE.instantiate()
		s.slot = i
		bc.add_child(s)
		s.cast_requested.connect(func(slot: int) -> void:
			if battle and not get_tree().paused:
				battle.controller.request_skill(slot))
		s.auto_toggled.connect(func(slot: int) -> void: PlayerState.set_slot_auto(slot, not PlayerState.slot_auto[slot]))
		slots.append(s)
	var dv := VBoxContainer.new(); dv.add_theme_constant_override("separation", -8); dv.alignment = BoxContainer.ALIGNMENT_BEGIN
	dodge_btn = UiStyle.medallion("闪", 86, 40)
	dodge_btn.pressed.connect(func() -> void:
		if battle and not get_tree().paused:
			battle.controller.request_dodge())
	dv.add_child(dodge_btn)
	dodge_plaque = UiStyle.plaque("闪避 · 空格", 13); dodge_plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; dodge_plaque.z_index = 1
	dv.add_child(dodge_plaque)
	bc.add_child(dv)
	# ---- 右下：自动开关 + 四个圆章入口 ----
	var br := VBoxContainer.new(); br.add_theme_constant_override("separation", 8); br.alignment = BoxContainer.ALIGNMENT_END
	_anchored(br, Control.PRESET_BOTTOM_RIGHT, Vector2(-14, -10))
	br.custom_minimum_size = Vector2(286, 0)
	auto_btn = UiStyle.button("自动 · 开", 16)
	var ap := UiStyle._btn_box(Color(UiStyle.INK, 0.9), UiStyle.GOLD_LINE, 16)
	auto_btn.add_theme_stylebox_override("normal", ap)
	auto_btn.custom_minimum_size = Vector2(120, 32)
	auto_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	auto_btn.tooltip_text = "Q 切换；移动/闪避会切到手动"
	auto_btn.pressed.connect(func() -> void: PlayerState.set_auto_battle(not PlayerState.auto_battle))
	br.add_child(auto_btn)
	var meds := HBoxContainer.new(); meds.add_theme_constant_override("separation", 12); br.add_child(meds)
	for pair in [["装", "装备"], ["功", "功法"], ["图", "地图"], ["破", "突破"]]:
		var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_BEGIN; v.add_theme_constant_override("separation", -6)
		var b := UiStyle.medallion(pair[0], 60, 30)
		var title: String = pair[1]
		b.pressed.connect(func() -> void: open_panel(title))
		v.add_child(b)
		var pl := UiStyle.plaque(pair[1], 13); pl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; pl.z_index = 1
		v.add_child(pl)
		meds.add_child(v)
	# ---- 面板遮罩（打开养成面板时压暗战斗画面） ----
	dim = ColorRect.new(); dim.color = Color(0.03, 0.04, 0.03, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	# ---- 地图/突破面板 ----
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.big_panel())
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -330; panel.offset_right = 330; panel.offset_top = -250; panel.offset_bottom = 230
	panel.visible = false
	root.add_child(panel)
	var pv := VBoxContainer.new(); pv.add_theme_constant_override("separation", 10); panel.add_child(pv)
	var ph := HBoxContainer.new(); pv.add_child(ph)
	panel_title = UiStyle.title("", 34); panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ph.add_child(panel_title)
	var close := UiStyle.button("关闭", 16); close.pressed.connect(close_panel); ph.add_child(close)
	pv.add_child(UiStyle.hsep())
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; pv.add_child(scroll)
	panel_body = VBoxContainer.new(); panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; panel_body.add_theme_constant_override("separation", 6); scroll.add_child(panel_body)
	panel.add_child(InkFrame.new())
	# ---- 正式养成面板：装备 / 功法 ----
	gear_panel = GearPanel.new(); gear_panel.visible = false; root.add_child(gear_panel)
	gear_panel.closed.connect(close_panel)
	gongfa_panel = GongfaPanel.new(); gongfa_panel.visible = false; root.add_child(gongfa_panel)
	gongfa_panel.closed.connect(close_panel)

func is_panel_open() -> bool:
	return panel.visible or gear_panel.visible or gongfa_panel.visible

func open_panel(title: String) -> void:
	panel.visible = false; gear_panel.visible = false; gongfa_panel.visible = false
	dim.visible = true
	get_tree().paused = true
	if title == "装备" or title == "功法":
		var pc: Control = gear_panel if title == "装备" else gongfa_panel
		pc.call("open")
		UiStyle.pop_in(pc)
		return
	panel_title.text = title
	for c in panel_body.get_children():
		c.queue_free()
	if title == "地图":
		for l in GameData.levels_ordered:
			var m := GameData.get_map(l.map_id)
			var cleared := PlayerState.is_cleared(l.id)
			var tag := "已通关" if cleared else ("可挑战" if PlayerState.can_challenge(l.id) else "未解锁")
			if PlayerState.is_unstable(l.id):
				tag += " · 配置不稳定"
			var b := UiStyle.button("%s %d-%d  %s　　%s" % [m.name if m else l.map_id, m.order if m else 0, l.index, l.name, tag], 16)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.disabled = not PlayerState.can_challenge(l.id)
			var lid := l.id
			b.pressed.connect(func() -> void:
				close_panel()
				battle.challenge(lid))
			panel_body.add_child(b)
	else:
		var stage := {"突破": "阶段5（境界突破/地图解锁）"}
		var l := UiStyle.label("%s 实现（战斗已暂停，关闭后恢复）。" % stage.get(title, ""), 17, UiStyle.GOLD_TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(560, 0)
		panel_body.add_child(l)
	panel.visible = true
	UiStyle.pop_in(panel)

func close_panel() -> void:
	panel.visible = false
	gear_panel.visible = false
	gongfa_panel.visible = false
	dim.visible = false
	get_tree().paused = false
	if battle:
		battle.refresh_player_stats()   # 换装/升级/换被动立即生效（保持当前生命比例）

func _on_loot(entries: Array) -> void:
	var parts: Array[String] = []
	for e in entries:
		if not (str(e.beam) in ["", "none"]):
			parts.append(str(e.text))
	if not parts.is_empty():
		show_banner("获得：" + "，".join(parts))

func _on_challenge_next() -> void:
	var nxt := PlayerState.next_challenge_level()
	if nxt and battle:
		battle.challenge(nxt.id)
	else:
		show_banner("暂无可挑战的新关卡（境界/前置关卡未满足）")

func show_banner(text: String) -> void:
	banner_label.text = text
	_banner_t = 5.0
	banner_label.modulate.a = 0.0
	var tw := banner_label.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(banner_label, "modulate:a", 1.0, 0.2)

func _show_hint(text: String) -> void:
	var parts := text.split("\n", true, 1)
	hint_label.text = parts[0]
	hint_sub.text = parts[1] if parts.size() > 1 else ""
	_hint_pulse = 0.0

func _on_hp(hp: float, max_hp: float) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_text.text = "HP  %s / %s" % [UiStyle.num(ceil(hp)), UiStyle.num(max_hp)]

func _on_shield(total: float, max_hp: float) -> void:
	shield_bar.max_value = maxf(max_hp * 0.3, 1.0)
	shield_bar.value = total
	shield_text.text = "护盾  %s" % UiStyle.num(total)

func _refresh_auto() -> void:
	auto_btn.text = "自动 · 开" if PlayerState.auto_battle else "手动 · 关"
	var on := PlayerState.auto_battle
	auto_btn.add_theme_stylebox_override("normal", UiStyle._btn_box(Color("#2F5A47") if on else Color(UiStyle.INK, 0.9), UiStyle.GOLD_TEXT if on else UiStyle.GOLD_LINE, 16, 2 if on else 1))
	auto_btn.add_theme_color_override("font_color", Color("#BFF0D8") if on else UiStyle.GOLD_TEXT)

func _refresh_top() -> void:
	if realm_label == null:
		return
	var rl := GameData.get_realm(PlayerState.realm_id)
	realm_label.text = rl.name if rl else "?"
	realm_sub.text = "境界"
	lingshi_label.text = UiStyle.num(PlayerState.lingshi)
	xiuwei_label.text = UiStyle.num(PlayerState.xiuwei)
	if battle == null or battle.level == null:
		return
	var l := battle.level
	var m := GameData.get_map(l.map_id)
	level_label.text = "%s %d-%d" % [m.name if m else "", m.order if m else 0, l.index]
	var mode_txt: String = ["挑战中", "挂机中", "挂机 · 普通怪"][battle.mode]
	mode_label.text = "%s · %s" % [l.name, mode_txt]
	var nxt := PlayerState.next_challenge_level()
	challenge_btn.disabled = nxt == null
	challenge_btn.text = "挑战 %s" % nxt.name if nxt else "暂无新关卡"
	boss_box.visible = battle.phase == Battle.Phase.BOSS and battle.boss != null

func _process(delta: float) -> void:
	if battle == null:
		return
	var p := battle.phase
	if p == Battle.Phase.BOSS and battle.boss:
		wave_label.text = "首领战 · 剩余 %d 秒" % int(ceil(maxf(battle.boss_time_left, 0.0)))
		boss_name.text = battle.boss.def.name
		boss_bar.max_value = battle.boss.max_hp
		boss_bar.value = battle.boss.hp
	elif p == Battle.Phase.BOSS_INTRO:
		wave_label.text = "首领将至"
	elif battle.mode == Battle.RunMode.FARM_NORMALS or battle.wave_index > 0:
		wave_label.text = "第 %d / %d 波" % [maxi(battle.wave_index, 1), battle.level.wave_count if battle.level else 4]
	boss_box.visible = p == Battle.Phase.BOSS and battle.boss != null
	wave_box.visible = wave_label.text != ""
	for i in slots.size():
		var cdt := battle.skills.cd_totals[i] if i < battle.skills.cd_totals.size() else 0.0
		slots[i].refresh(battle.skills.skill_in_slot(i), PlayerState.slot_auto[i], battle.skills.cds[i], cdt)
	var pl := battle.player
	dodge_btn.text = ("%.1f" % pl.dodge_cd) if pl.dodge_cd > 0.0 else "闪"
	dodge_btn.add_theme_font_size_override("font_size", 26 if pl.dodge_cd > 0.0 else 40)
	dodge_btn.disabled = pl.dodge_cd > 0.0
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

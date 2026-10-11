class_name Hud
extends CanvasLayer

const NAV := [["装备", "NAV_GEAR"], ["功法", "NAV_GONGFA"], ["地图", "NAV_MAP"], ["突破", "NAV_BREAK"]]
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
var hint_key: PanelContainer
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
	PlayerState.currencies_changed.connect(_refresh_top)
	PlayerState.progress_changed.connect(_refresh_top)
	PlayerState.auto_battle_changed.connect(func(_e: bool) -> void: _refresh_auto())
	_refresh_top()
	_refresh_auto()

func _build() -> void:
	# ---- 顶部栏 ----
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UiStyle.panel(0))
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 44
	root.add_child(top)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 28)
	top.add_child(th)
	realm_label = UiStyle.label("", 20, UiStyle.GOLD); th.add_child(realm_label)
	lingshi_label = UiStyle.label("", 18); th.add_child(lingshi_label)
	xiuwei_label = UiStyle.label("", 18, UiStyle.JADE.lightened(0.3)); th.add_child(xiuwei_label)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; th.add_child(sp)
	level_label = UiStyle.label("", 20); th.add_child(level_label)
	var sp2 := Control.new(); sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; th.add_child(sp2)
	save_label = UiStyle.label(UiText.t("HUD_SAVE_PENDING"), 14, Color(0.7, 0.7, 0.7)); th.add_child(save_label)
	# ---- 中上：波次/首领 ----
	var mid := VBoxContainer.new()
	mid.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	mid.offset_top = 52; mid.offset_left = -260; mid.offset_right = 260
	mid.alignment = BoxContainer.ALIGNMENT_BEGIN
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mid)
	wave_label = UiStyle.label("", 20); wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; mid.add_child(wave_label)
	mode_label = UiStyle.label("", 14, Color(0.85, 0.85, 0.8)); mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; mid.add_child(mode_label)
	boss_box = VBoxContainer.new(); mid.add_child(boss_box)
	boss_name = UiStyle.label("", 18, UiStyle.CINNABAR.lightened(0.3)); boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; boss_box.add_child(boss_name)
	boss_bar = UiStyle.bar(UiStyle.BLOOD); boss_bar.custom_minimum_size = Vector2(520, 14); boss_box.add_child(boss_bar)
	banner_label = UiStyle.label("", 18, UiStyle.GOLD); banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; banner_label.custom_minimum_size = Vector2(520, 0); mid.add_child(banner_label)
	# ---- 屏幕中央：情境引导提示 ----
	hint_label = UiStyle.label("", 44, UiStyle.MIST)
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hint_label.offset_left = -400; hint_label.offset_right = 400; hint_label.offset_top = -120; hint_label.offset_bottom = -60
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_constant_override("outline_size", 8)
	root.add_child(hint_label)
	# BUG-004：空格键图标 + 自动模式小字（文案来自 tutorial_steps.ui_target）
	hint_key = PanelContainer.new()
	var ksb := UiStyle.panel(6, UiStyle.MIST); ksb.set_border_width_all(2); ksb.border_width_bottom = 5
	ksb.content_margin_left = 44; ksb.content_margin_right = 44; ksb.content_margin_top = 2; ksb.content_margin_bottom = 2
	hint_key.add_theme_stylebox_override("panel", ksb)
	hint_key.add_child(UiStyle.label(UiText.t("HINT_KEY_SPACE"), 20, UiStyle.MIST))
	hint_key.set_anchors_preset(Control.PRESET_CENTER)
	hint_key.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_key.offset_left = 0; hint_key.offset_right = 0; hint_key.offset_top = -54; hint_key.offset_bottom = -54
	hint_key.visible = false
	hint_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint_key)
	hint_sub = UiStyle.label("", 18, UiStyle.MIST)
	hint_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hint_sub.offset_left = -420; hint_sub.offset_right = 420; hint_sub.offset_top = -10; hint_sub.offset_bottom = 18
	hint_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint_sub)
	# ---- 底部栏 ----
	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", UiStyle.panel(0))
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	# BUG-008：底栏按内容最小高度向上生长（不再固定 -136 导致溢出）
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_top = 0; bottom.offset_bottom = 0
	root.add_child(bottom)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 10)
	bottom.add_child(bh)
	var bars := VBoxContainer.new()
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.add_child(bars)
	var hrow := HBoxContainer.new(); bars.add_child(hrow)
	hrow.add_child(UiStyle.label(UiText.t("HUD_HP"), 16)); hp_bar = UiStyle.bar(UiStyle.BLOOD); hp_bar.custom_minimum_size = Vector2(190, 16); hrow.add_child(hp_bar)
	hp_text = UiStyle.label("", 13); hp_text.custom_minimum_size = Vector2(112, 0); hp_text.clip_text = true; hrow.add_child(hp_text)
	var srow := HBoxContainer.new(); bars.add_child(srow)
	srow.add_child(UiStyle.label(UiText.t("HUD_SHIELD"), 16)); shield_bar = UiStyle.bar(UiStyle.SHIELD); shield_bar.custom_minimum_size = Vector2(190, 16); srow.add_child(shield_bar)
	shield_text = UiStyle.label("", 13); shield_text.custom_minimum_size = Vector2(112, 0); shield_text.clip_text = true; srow.add_child(shield_text)
	bars.add_child(UiStyle.label(UiText.t("HUD_CONTROLS"), 13, Color(0.75, 0.75, 0.7)))
	var sp3 := Control.new(); sp3.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bh.add_child(sp3)
	for i in PlayerState.slot_count():
		var s: SkillSlotUI = SLOT_SCENE.instantiate()
		s.slot = i
		bh.add_child(s)
		s.cast_requested.connect(func(slot: int) -> void:
			if battle and not get_tree().paused:
				battle.controller.request_skill(slot))
		s.auto_toggled.connect(func(slot: int) -> void: PlayerState.set_slot_auto(slot, not PlayerState.slot_auto[slot]))
		slots.append(s)
	dodge_btn = UiStyle.button(_dodge_idle_text(), 18)
	dodge_btn.custom_minimum_size = Vector2(84, 84)
	dodge_btn.pressed.connect(func() -> void:
		if battle and not get_tree().paused:
			battle.controller.request_dodge())
	bh.add_child(dodge_btn)
	var av := VBoxContainer.new(); av.alignment = BoxContainer.ALIGNMENT_CENTER; bh.add_child(av)
	auto_btn = UiStyle.button(UiText.t("BTN_AUTO_ON"), 16)
	auto_btn.custom_minimum_size = Vector2(130, 40)
	auto_btn.pressed.connect(func() -> void: PlayerState.set_auto_battle(not PlayerState.auto_battle))
	av.add_child(auto_btn)
	challenge_btn = UiStyle.button(UiText.t("BTN_CHALLENGE_NONE"), 16)
	challenge_btn.custom_minimum_size = Vector2(130, 36)
	challenge_btn.pressed.connect(_on_challenge_next)
	av.add_child(challenge_btn)
	var sp4 := Control.new(); sp4.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bh.add_child(sp4)
	# [面板ID（内部标识）, 文案key]：显示文字来自 ui_texts
	for pair in NAV:
		var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER
		var b := UiStyle.button(UiText.t(pair[1] + "_SHORT"), 26)
		b.custom_minimum_size = Vector2(56, 56)
		var title: String = pair[0]
		b.pressed.connect(func() -> void: open_panel(title))
		v.add_child(b)
		var l := UiStyle.label(UiText.t(pair[1]), 13); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(l)
		bh.add_child(v)
	# ---- 养成面板（占位，打开时暂停战斗） ----
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel(8))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -300; panel.offset_right = 300; panel.offset_top = -220; panel.offset_bottom = 200
	panel.visible = false
	root.add_child(panel)
	var pv := VBoxContainer.new(); pv.add_theme_constant_override("separation", 8); panel.add_child(pv)
	var ph := HBoxContainer.new(); pv.add_child(ph)
	panel_title = UiStyle.label("", 24, UiStyle.GOLD); panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ph.add_child(panel_title)
	var close := UiStyle.button(UiText.t("BTN_CLOSE"), 16); close.pressed.connect(close_panel); ph.add_child(close)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; pv.add_child(scroll)
	panel_body = VBoxContainer.new(); panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(panel_body)

func _dodge_idle_text() -> String:
	return UiText.t("BTN_DODGE") + "\n" + UiText.t("HUD_KEY_SPACE")

func _level_text(l: LevelDef) -> String:
	var m := GameData.get_map(l.map_id)
	return UiText.t("HUD_LEVEL", {"map_name": m.name if m else "", "level_index": l.index, "level_name": l.name})

func is_panel_open() -> bool:
	return panel.visible

func open_panel(title: String) -> void:
	var nav_key := ""
	for pair in NAV:
		if pair[0] == title:
			nav_key = pair[1]
	panel_title.text = UiText.t("PANEL_TITLE_PAUSED", {"title": UiText.t(nav_key) if nav_key != "" else title})
	for c in panel_body.get_children():
		c.queue_free()
	if title == "地图":
		for l in GameData.levels_ordered:
			var m := GameData.get_map(l.map_id)
			var cleared := PlayerState.is_cleared(l.id)
			var tag := UiText.t("MAP_TAG_CLEARED") if cleared else UiText.t("MAP_TAG_OPEN" if PlayerState.can_challenge(l.id) else "MAP_TAG_LOCKED")
			if PlayerState.is_unstable(l.id):
				tag += " · " + UiText.t("MAP_TAG_UNSTABLE")
			var b := UiStyle.button("%s  [%s]" % [_level_text(l), tag], 16)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.disabled = not PlayerState.can_challenge(l.id)
			var lid := l.id
			b.pressed.connect(func() -> void:
				close_panel()
				battle.challenge(lid))
			panel_body.add_child(b)
	else:
		var stage := {"装备": "阶段4（装备生成/词条/换装/分解/重铸）", "功法": "阶段3（功法/技能书/学习/升级/装配/残页）", "突破": "阶段5（境界突破/地图解锁）"}
		var l := UiStyle.label("占位面板：%s 实现。\n本阶段用于验证“打开养成面板暂停战斗、关闭后恢复”。" % stage.get(title, ""), 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(560, 0)
		panel_body.add_child(l)
		if title == "功法":
			var info := ""
			for i in PlayerState.slot_count():
				var s := GameData.get_skill(PlayerState.active_slots[i])
				info += "%d · %s（%s）\n" % [i + 1, s.name if s else UiText.t("LABEL_EMPTY_SLOT"), UiText.t("SLOT_AUTO" if PlayerState.slot_auto[i] else "SLOT_MANUAL")]
			panel_body.add_child(UiStyle.label(info, 16))
	panel.visible = true
	get_tree().paused = true

func close_panel() -> void:
	panel.visible = false
	get_tree().paused = false

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

func _show_hint(text: String) -> void:
	var parts := text.split("\n", true, 1)
	text = parts[0]
	hint_sub.text = parts[1] if parts.size() > 1 else ""
	hint_key.visible = text != ""
	hint_label.text = text
	_hint_pulse = 0.0

func _on_hp(hp: float, max_hp: float) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_text.text = "%d / %d" % [int(ceil(hp)), int(max_hp)]

func _on_shield(total: float, max_hp: float) -> void:
	shield_bar.max_value = maxf(max_hp * 0.3, 1.0)
	shield_bar.value = total
	shield_text.text = "%d" % int(total)

func _refresh_auto() -> void:
	auto_btn.text = UiText.t("BTN_AUTO_ON" if PlayerState.auto_battle else "BTN_AUTO_OFF")
	auto_btn.modulate = UiStyle.JADE.lightened(0.4) if PlayerState.auto_battle else Color.WHITE

func _refresh_top() -> void:
	if realm_label == null:
		return
	var rl := GameData.get_realm(PlayerState.realm_id)
	realm_label.text = UiText.t("HUD_REALM", {"realm_name": rl.name if rl else "?"})
	lingshi_label.text = UiText.t("HUD_LINGSHI", {"value": PlayerState.lingshi})
	xiuwei_label.text = UiText.t("HUD_XIUWEI", {"value": PlayerState.xiuwei})
	if battle == null or battle.level == null:
		return
	var l := battle.level
	var m := GameData.get_map(l.map_id)
	level_label.text = _level_text(l)
	var mode_txt: String = UiText.t(["HUD_MODE_CHALLENGE", "HUD_MODE_FARM", "HUD_MODE_FARM_NORMALS"][battle.mode])
	mode_label.text = mode_txt
	var nxt := PlayerState.next_challenge_level()
	challenge_btn.disabled = nxt == null
	challenge_btn.text = UiText.t("BTN_CHALLENGE", {"level_name": nxt.name}) if nxt else UiText.t("BTN_CHALLENGE_NONE")
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
	for i in slots.size():
		var cdt := battle.skills.cd_totals[i] if i < battle.skills.cd_totals.size() else 0.0
		slots[i].refresh(battle.skills.skill_in_slot(i), PlayerState.slot_auto[i], battle.skills.cds[i], cdt)
	var pl := battle.player
	dodge_btn.text = (UiText.t("BTN_DODGE") + "\n%.1f" % pl.dodge_cd) if pl.dodge_cd > 0.0 else _dodge_idle_text()
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
		if _banner_t <= 0.0:
			banner_label.text = ""

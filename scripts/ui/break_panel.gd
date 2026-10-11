class_name BreakPanel
extends PanelContainer
## 突破面板（阶段5，v2 宣纸水墨风格，与装备/功法面板同一套外壳）。
## 左：当前境界与属性；中：破字圆章；右：下一境界与属性增量；下：突破所需（修为 / 灵石 / 突破材料，持有／需要）、
## 突破后开放的地图（背景缩略图 + 地图简介）、突破按钮。成功后弹出“地图开放”卡片（前往 / 稍后）。
## 数值与文案全部来自表（realms / maps / materials / affixes / ui_texts）；打开时战斗暂停（HUD 负责）。

signal closed
signal go_map(map_id: String)

const STATS := ["hp", "atk", "def", "crit_rate", "crit_dmg"]
const PCT := ["crit_rate", "crit_dmg"]   # 与装备面板一致：暴击率 / 暴击伤害按百分比显示

var _msg := ""
var now_box: VBoxContainer
var next_box: VBoxContainer
var req_box: HBoxContainer
var unlock_box: VBoxContainer
var rule_label: Label
var break_btn: Button
var msg_label: Label
var unlock_card: PanelContainer   # 突破成功后的地图开放卡片（截图 / 测试可见）

func _ready() -> void:
	var k := PanelKit.shell(self, Hud.panel_title_text("break"), UiText.t("PANEL_SUB_BREAK"))
	(k.close as Button).pressed.connect(func() -> void: closed.emit())
	var body: VBoxContainer = k.body
	var cols := HBoxContainer.new(); cols.add_theme_constant_override("separation", 12); body.add_child(cols)
	now_box = PanelKit.section(cols, UiText.t("LABEL_REALM_NOW"), 0, true)
	var mid := VBoxContainer.new(); mid.alignment = BoxContainer.ALIGNMENT_CENTER; cols.add_child(mid)
	var seal := UiStyle.medallion(UiText.t("NAV_BREAK_SHORT"), 84, 40)
	seal.disabled = true; seal.focus_mode = Control.FOCUS_NONE; seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(seal)
	next_box = PanelKit.section(cols, UiText.t("LABEL_REALM_NEXT"), 0, true)
	var low := HBoxContainer.new(); low.add_theme_constant_override("separation", 12); low.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_child(low)
	var cost := PanelKit.section(low, UiText.t("LABEL_BREAK_COST"), 0, true)
	req_box = HBoxContainer.new(); req_box.add_theme_constant_override("separation", 18); cost.add_child(req_box)
	cost.add_child(UiStyle.spacer())
	rule_label = UiStyle.label(UiText.t("LABEL_BREAK_RULE"), 14, Color(UiStyle.GOLD_TEXT, 0.7)); cost.add_child(rule_label)
	break_btn = UiStyle.accent_button(UiText.t("BTN_BREAK"), 26)
	break_btn.custom_minimum_size = Vector2(220, 52); break_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	break_btn.add_theme_font_override("font", UiStyle.TITLE_FONT)
	break_btn.pressed.connect(do_breakthrough)
	cost.add_child(break_btn)
	unlock_box = PanelKit.section(low, UiText.t("LABEL_BREAK_UNLOCK"), 330)
	msg_label = UiStyle.label("", 16, UiStyle.GOLD_TEXT); msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(msg_label)
	PlayerState.currencies_changed.connect(_refresh_if_visible)
	PlayerState.inventory_changed.connect(_refresh_if_visible)
	PlayerState.progress_changed.connect(_refresh_if_visible)

func open() -> void:
	_msg = ""
	visible = true
	_close_unlock_card()
	refresh()

func _refresh_if_visible() -> void:
	if visible:
		refresh.call_deferred()

static func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c); c.queue_free()

static func stat_text(stat: String, v: float) -> String:
	return UiText.fmt(v, "pct") if stat in PCT else UiStyle.num(v)

static func realm_stat(rl: RealmDef, stat: String) -> float:
	return float(rl.get(stat)) if rl else 0.0

func refresh() -> void:
	for b in [now_box, next_box, req_box, unlock_box]:
		# 保留分区小标题（第一个子节点）
		var kids: Array = (b as Node).get_children()
		for i in kids.size():
			if b is VBoxContainer and i == 0:
				continue
			b.remove_child(kids[i]); kids[i].queue_free()
	msg_label.text = _msg
	var cur := GameData.get_realm(PlayerState.realm_id)
	var st := PlayerState.breakthrough_status()
	var nx: RealmDef = st.realm
	_realm_card(now_box, cur, null)
	if nx:
		_realm_card(next_box, nx, cur)
	else:
		var l := UiStyle.subtitle(UiText.t("LABEL_REALM_MAX"), 24, Color(UiStyle.GOLD_TEXT, 0.8))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		next_box.add_child(l)
	for r in st.reqs:
		req_box.add_child(_req_chip(r))
	rule_label.visible = nx != null
	break_btn.visible = nx != null
	break_btn.disabled = not st.ok
	if nx and nx.unlock_map_id != "":
		_map_preview(unlock_box, GameData.get_map(nx.unlock_map_id), 110)
	unlock_box.get_parent().visible = nx != null and nx.unlock_map_id != ""

func _realm_card(box: VBoxContainer, rl: RealmDef, prev: RealmDef) -> void:
	if rl == null:
		return
	var name_l := UiStyle.title(rl.name, 40, UiStyle.GOLD_TEXT if prev == null else Color("#E9C46A"))
	box.add_child(name_l)
	if rl.desc != "":
		var d := UiStyle.label(rl.desc, 14, Color(UiStyle.MIST, 0.85)); d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(240, 0)
		box.add_child(d)
	box.add_child(UiStyle.hsep(0.3))
	for s in STATS:
		var v := realm_stat(rl, s)
		var delta := ""
		if prev:
			var dv := v - realm_stat(prev, s)
			if absf(dv) > 0.0001:
				delta = ("+" if dv > 0 else "") + stat_text(s, dv)
		PanelKit.kv(box, GameData.stat_name(s), stat_text(s, v), UiStyle.MIST, delta)

## 一项突破条件：图标（槽位底） + 名称 + 持有／需要（未满足标红）
func _req_chip(r: Dictionary) -> Control:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8)
	h.name = "Req_" + str(r.id)
	var slot := PanelContainer.new(); slot.add_theme_stylebox_override("panel", ArtUi.box("ui_slot_9p"))
	slot.custom_minimum_size = Vector2(64, 64)
	var ic := TextureRect.new(); ic.texture = ArtUi.item_icon(str(r.id))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(48, 48)
	slot.add_child(ic); h.add_child(slot)
	var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_child(v)
	v.add_child(UiStyle.label(GameData.material_name(str(r.id)), 16, UiStyle.GOLD_TEXT))
	var hn := UiStyle.label(UiText.t("LABEL_HAVE_NEED", {"have": r.have, "need": r.need}), 15, UiStyle.GOOD if r.met else UiStyle.BAD)
	hn.name = "HaveNeed"
	v.add_child(hn)
	return h

## 地图预览：背景远景缩略图 + 地图名 + 简介
static func _map_preview(box: Control, m: MapDef, h: float) -> void:
	if m == null:
		return
	var thumb := TextureRect.new()
	var key := m.art_key()
	var p := "res://art/bg/%s/bg_%s_far.png" % [key, key]
	thumb.texture = load(p) as Texture2D if ResourceLoader.exists(p) else null
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.custom_minimum_size = Vector2(0, h); thumb.clip_contents = true
	box.add_child(thumb)
	box.add_child(UiStyle.subtitle(m.name, 24, Color("#E9C46A")))
	var d := UiStyle.label(m.desc, 14, Color(UiStyle.MIST, 0.85)); d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(300, 0)
	box.add_child(d)

func do_breakthrough() -> String:
	var before := PlayerState.realm_id
	var code := PlayerState.breakthrough()
	if code == "ok":
		var rl := GameData.get_realm(PlayerState.realm_id)
		_msg = UiText.t("BANNER_REALM_UP", {"realm_name": rl.name if rl else ""})
		refresh()
		_flash()
		var prev := GameData.get_realm(before)
		var nx := GameData.get_realm(PlayerState.realm_id)
		if nx and nx.unlock_map_id != "" and prev:
			show_unlock_card(nx.unlock_map_id)
	else:
		_msg = result_text(code)
		refresh()
	return code

static func result_text(code: String) -> String:
	var st := PlayerState.breakthrough_status()
	for r in st.reqs:
		if "no_" + str(r.kind) == code:
			return UiText.t("ERR_NOT_ENOUGH", {"item_name": GameData.material_name(str(r.id))})
	return UiText.t("LABEL_REALM_MAX") if code == "max_realm" else ""

func _flash() -> void:
	modulate = Color(1.5, 1.35, 1.1)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(self, "modulate", Color.WHITE, 0.6)

## 地图开放卡片：覆盖在面板中央
func show_unlock_card(map_id: String) -> void:
	_close_unlock_card()
	var m := GameData.get_map(map_id)
	if m == null:
		return
	# 面板（PanelContainer）会把子节点拉满：覆盖层 = 压暗底 + 居中容器
	var holder := Control.new()
	holder.name = "MapUnlockHolder"
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	var dimmer := ColorRect.new(); dimmer.color = Color(0, 0, 0, 0.5); dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(dimmer)
	var center := CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(center)
	var card := PanelContainer.new()
	card.name = "MapUnlockCard"
	card.add_theme_stylebox_override("panel", UiStyle.big_panel())
	card.custom_minimum_size = Vector2(560, 0)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); card.add_child(v)
	var t := UiStyle.title(UiText.t("BANNER_MAP_UNLOCK", {"map_name": m.name}), 36, Color("#E9C46A"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UiStyle.hsep(0.6))
	_map_preview(v, m, 180)
	var btns := HBoxContainer.new(); btns.alignment = BoxContainer.ALIGNMENT_CENTER; btns.add_theme_constant_override("separation", 16); v.add_child(btns)
	var go := UiStyle.accent_button(UiText.t("BTN_GO_MAP", {"map_name": m.name}), 20); go.custom_minimum_size = Vector2(180, 46)
	var mid := m.id
	go.pressed.connect(func() -> void: _close_unlock_card(); go_map.emit(mid))
	btns.add_child(go)
	var stay := UiStyle.button(UiText.t("BTN_STAY"), 20); stay.custom_minimum_size = Vector2(120, 46)
	stay.pressed.connect(_close_unlock_card)
	btns.add_child(stay)
	card.add_child(InkFrame.new())
	center.add_child(card)
	add_child(holder)
	unlock_card = card
	UiStyle.pop_in(card)

func _close_unlock_card() -> void:
	if unlock_card and is_instance_valid(unlock_card):
		unlock_card.get_parent().get_parent().queue_free()
	unlock_card = null

class_name SkillSlotUI
extends VBoxContainer
## 技能栏单格（v2 定调图样式）：古金方框 + 技能图标，冷却时墨色遮罩自下而上收起并显示“冷却”与剩余秒数，
## 下方圆形编号与自动/手动小签。左键 = 释放（与数字键相同，不退出自动模式）；右键或点小签 = 切换该格自动/手动。

signal cast_requested(slot: int)
signal auto_toggled(slot: int)

const SIZE := 100.0   # ui_slot_9p 显示 100×100；图标 72×72 叠在格子上方居中（§5.4：格子内腔不透明）
const ICON := 72.0
var slot := 0
var _btn: Button
var _icon: TextureRect
var _cd: Label
var _cd_cap: Label
var _shade: ColorRect
var _empty: Label
var _num: Label
var _key: TextureRect
var _auto: Button
var _ready_flash := 0.0
var _was_cd := false

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	alignment = BoxContainer.ALIGNMENT_BEGIN
	_btn = Button.new()
	_btn.custom_minimum_size = Vector2(SIZE, SIZE)
	_btn.focus_mode = Control.FOCUS_NONE
	var n := ArtUi.box("ui_slot_9p")
	var p := ArtUi.box("ui_slot_9p_pressed")
	if n:
		_btn.add_theme_stylebox_override("normal", n)
		_btn.add_theme_stylebox_override("hover", n)
		_btn.add_theme_stylebox_override("pressed", p if p else n)
		_btn.add_theme_stylebox_override("hover_pressed", p if p else n)
		_btn.add_theme_stylebox_override("disabled", n)
	_btn.gui_input.connect(_on_gui_input)
	_btn.pressed.connect(func() -> void: cast_requested.emit(slot))
	UiStyle.add_press_fx(_btn)
	add_child(_btn)
	var inset := (SIZE - ICON) / 2.0
	_icon = TextureRect.new()
	_icon.position = Vector2(inset, inset); _icon.size = Vector2(ICON, ICON)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn.add_child(_icon)
	_shade = ColorRect.new()
	_shade.color = Color(0.03, 0.04, 0.04, 0.62)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn.add_child(_shade)
	var cdv := VBoxContainer.new(); cdv.position = Vector2(inset, inset); cdv.size = Vector2(ICON, ICON)
	cdv.alignment = BoxContainer.ALIGNMENT_CENTER; cdv.add_theme_constant_override("separation", -2)
	cdv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn.add_child(cdv)
	_cd_cap = UiStyle.label(UiText.t("HUD_COOLDOWN"), 14, Color("#C8BA96")); _cd_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cdv.add_child(_cd_cap)
	_cd = UiStyle.label("", 22, UiStyle.GOLD_TEXT); _cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cdv.add_child(_cd)
	_empty = UiStyle.title(UiText.t("LABEL_EMPTY_SLOT"), 30, Color(UiStyle.GOLD_LINE, 0.45))
	_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_btn.add_child(_empty)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 2); row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	_key = TextureRect.new(); _key.texture = ArtUi.key_icon(str(slot + 1))
	_key.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; _key.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_key.custom_minimum_size = Vector2(30, 30)
	_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_key)
	_num = UiStyle.label(str(slot + 1), 12, UiStyle.GOLD_TEXT)   # 缺按键图标时的退路
	_num.visible = _key.texture == null
	row.add_child(_num)
	_auto = Button.new()
	_auto.focus_mode = Control.FOCUS_NONE
	_auto.add_theme_font_size_override("font_size", 11)
	_auto.custom_minimum_size = Vector2(40, 20)
	_auto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_auto.pressed.connect(func() -> void: auto_toggled.emit(slot))
	UiStyle.add_press_fx(_auto)
	row.add_child(_auto)

func _on_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		auto_toggled.emit(slot)

func _style_auto(on: bool) -> void:
	var sb := UiStyle._btn_box(Color("#2F5A47") if on else Color(UiStyle.INK, 0.9), Color(UiStyle.GOLD_LINE, 0.8), 10)
	sb.content_margin_left = 6; sb.content_margin_right = 6; sb.content_margin_top = 0; sb.content_margin_bottom = 0
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		_auto.add_theme_stylebox_override(st, sb)
	_auto.add_theme_color_override("font_color", Color("#BFF0D8") if on else UiStyle.GOLD_TEXT)
	_auto.add_theme_color_override("font_hover_color", Color("#FFFFFF"))

func refresh(skill: SkillDef, auto_on: bool, cd_left: float, cd_total: float) -> void:
	_num.text = str(slot + 1)
	var act := "skill_%d" % (slot + 1)
	var down := InputMap.has_action(act) and Input.is_action_pressed(act)
	var kt := ArtUi.key_icon(str(slot + 1), down)
	if kt and _key.texture != kt:
		_key.texture = kt
	if skill == null:
		_icon.texture = null
		_cd.text = ""; _cd_cap.visible = false
		_empty.visible = true
		_auto.visible = false
		_shade.size = Vector2.ZERO
		_btn.tooltip_text = UiText.t("TIP_EMPTY_SLOT")
		return
	_empty.visible = false
	if _icon.texture == null or _icon.texture.resource_path != skill.icon_path():
		_icon.texture = load(skill.icon_path()) if ResourceLoader.exists(skill.icon_path()) else null
	_btn.tooltip_text = skill.name
	_auto.visible = true
	var t := UiText.t("SLOT_AUTO" if auto_on else "SLOT_MANUAL")
	if _auto.text != t:
		_auto.text = t
		_style_auto(auto_on)
	var on_cd := cd_left > 0.0
	_cd_cap.visible = on_cd
	_cd.text = UiText.t("HUD_CD_SEC", {"sec": "%.1f" % cd_left}) if on_cd else ""
	var frac := clampf(cd_left / cd_total, 0.0, 1.0) if cd_total > 0.0 else 0.0
	var inset := (SIZE - ICON) / 2.0
	_shade.position = Vector2(inset, inset + ICON * (1.0 - frac))   # 墨色遮罩只盖图标区，自下而上收起
	_shade.size = Vector2(ICON, ICON * frac)
	# 冷却结束：金色闪一下
	if _was_cd and not on_cd:
		_ready_flash = 0.35
	_was_cd = on_cd
	if _ready_flash > 0.0:
		_ready_flash -= get_process_delta_time()
		_btn.self_modulate = Color(1.4, 1.3, 1.0).lerp(Color.WHITE, 1.0 - clampf(_ready_flash / 0.35, 0.0, 1.0))
	else:
		_btn.self_modulate = Color.WHITE

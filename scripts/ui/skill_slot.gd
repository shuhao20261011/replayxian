class_name SkillSlotUI
extends VBoxContainer
## 技能栏单格：图标、快捷键、冷却倒计时、自动/手动状态（计划4.3）。
## 左键点击 = 释放（与按数字键相同，不退出自动模式）；点下方标签或右键 = 切换该格自动/手动。

signal cast_requested(slot: int)
signal auto_toggled(slot: int)

var slot := 0
var _btn: Button
var _icon: TextureRect
var _key: Label
var _cd: Label
var _shade: ColorRect
var _auto: Button
var _name: Label

func _ready() -> void:
	add_theme_constant_override("separation", 2)
	_btn = Button.new()
	_btn.custom_minimum_size = Vector2(72, 72)
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.add_theme_stylebox_override("normal", UiStyle.panel(6))
	_btn.add_theme_stylebox_override("hover", UiStyle.panel(6, UiStyle.MIST))
	_btn.add_theme_stylebox_override("pressed", UiStyle.panel(6, UiStyle.JADE))
	_btn.gui_input.connect(_on_gui_input)
	_btn.pressed.connect(func() -> void: cast_requested.emit(slot))
	add_child(_btn)
	_icon = TextureRect.new()
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 4; _icon.offset_top = 4; _icon.offset_right = -4; _icon.offset_bottom = -4
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn.add_child(_icon)
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0.6)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn.add_child(_shade)
	_key = UiStyle.label(str(slot + 1), 14, UiStyle.GOLD)
	_key.position = Vector2(4, 0)
	_btn.add_child(_key)
	_cd = UiStyle.label("", 24)
	_cd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_btn.add_child(_cd)
	_auto = UiStyle.button(UiText.t("SLOT_AUTO"), 12)
	_auto.custom_minimum_size = Vector2(72, 18)
	_auto.pressed.connect(func() -> void: auto_toggled.emit(slot))
	add_child(_auto)
	_name = UiStyle.label("", 13)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name)

func _on_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		auto_toggled.emit(slot)

func refresh(skill: SkillDef, auto_on: bool, cd_left: float, cd_total: float) -> void:
	_key.text = str(slot + 1)
	if skill == null:
		_icon.texture = null
		_cd.text = "+"
		_name.text = UiText.t("LABEL_EMPTY_SLOT")
		_auto.visible = false
		_shade.size = Vector2.ZERO
		return
	if _icon.texture == null or _icon.texture.resource_path != skill.icon_path():
		_icon.texture = load(skill.icon_path()) if ResourceLoader.exists(skill.icon_path()) else null
	_name.text = skill.name
	_auto.visible = true
	_auto.text = UiText.t("SLOT_AUTO" if auto_on else "SLOT_MANUAL")
	_auto.modulate = UiStyle.JADE.lightened(0.3) if auto_on else UiStyle.GOLD
	_cd.text = ("%.1f" % cd_left) if cd_left > 0.0 else ""
	var frac := clampf(cd_left / cd_total, 0.0, 1.0) if cd_total > 0.0 else 0.0
	_shade.position = Vector2(0, 72 * (1.0 - frac))
	_shade.size = Vector2(72, 72 * frac)

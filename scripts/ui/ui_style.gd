class_name UiStyle
extends RefCounted

## 世界内绘制文字（预警招式名、飘字等）用的字体：项目主题默认字体（内嵌中文子集，Web 也能显示）。
## 不要用 ThemeDB.fallback_font（引擎自带字体，无中文）。
static func world_font() -> Font:
	var th := ThemeDB.get_project_theme()
	if th and th.default_font:
		return th.default_font
	return ThemeDB.fallback_font
## 占位UI样式（style_guide 2节配色：深墨半透明面板 + 金色细描边）。正式UI切图到位后换成 NinePatchRect。

const PANEL := Color(0.106, 0.114, 0.125, 0.78)
const GOLD := Color("#D9A441")
const JADE := Color("#3E8E7E")
const CINNABAR := Color("#B8382C")
const BLOOD := Color("#C9433A")
const SHIELD := Color("#F2C14E")
const MIST := Color("#F6F2E8")

static func panel(radius: int = 6, border: Color = GOLD) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = Color(border, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10; sb.content_margin_right = 10
	sb.content_margin_top = 6; sb.content_margin_bottom = 6
	return sb

static func bar(color: Color) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(240, 16)
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(0, 0, 0, 0.55); bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new(); fg.bg_color = color; fg.set_corner_radius_all(4)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fg)
	return pb

static func label(text: String, size: int = 16, color: Color = MIST) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 3)
	return l

static func button(text: String, size: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE   # 空格是闪避键，按钮不能抢焦点
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", panel(6))
	b.add_theme_stylebox_override("hover", panel(6, MIST))
	b.add_theme_stylebox_override("pressed", panel(6, JADE))
	b.add_theme_stylebox_override("disabled", panel(6, Color(0.4, 0.4, 0.4)))
	return b

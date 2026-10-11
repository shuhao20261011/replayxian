class_name UiStyle
extends RefCounted

## 世界内绘制文字（预警招式名、飘字等）用的字体：项目主题默认字体（内嵌中文子集，Web 也能显示）。
## 不要用 ThemeDB.fallback_font（引擎自带字体，无中文）。
static func world_font() -> Font:
	var th := ThemeDB.get_project_theme()
	if th and th.default_font:
		return th.default_font
	return ThemeDB.fallback_font
## v2 宣纸水墨 UI 规范（art/style/v2/07 战斗界面定调图 + 02 配色 + art/ART_STYLE_GUIDE_final.md §2/§5.4）：
## 墨底 #232C25 / 墨绿 #2F453C 深色半透明面板，古金细描边 #C5B489，金字 #EAD7A8（深色描边），
## 生命 #7B2015，护盾 #A98344，朱砂 #B8382C 只做强调。标题书法体 Ma Shan Zheng，副题 Zhi Mang Xing（均 OFL），
## 正文/数值用系统黑体（Noto Sans CJK / 微软雅黑）。正式九宫格切图到位前，边框与角花由 InkFrame 程序绘制。

const INK := Color("#232C25")
const INK_GREEN := Color("#2F453C")
const GOLD_LINE := Color("#C5B489")
const GOLD_TEXT := Color("#EAD7A8")
const HP := Color("#7B2015")
const SHIELD_C := Color("#A98344")
const PAPER := Color("#D1C6B3")
const INK_DARK := Color("#111415")
# 兼容旧名
const PANEL := Color(0.137, 0.173, 0.145, 0.86)
const GOLD := GOLD_TEXT
const JADE := Color("#63BD9D")
const CINNABAR := Color("#B8382C")
const BLOOD := Color("#9B2A1C")
const SHIELD := Color("#CEA445")
const MIST := Color("#F4F1EA")
const GOOD := Color("#8FD08A")
const BAD := Color("#E0705F")

const TITLE_FONT: FontFile = preload("res://art/fonts/MaShanZheng-Regular.ttf")
const SUB_FONT: FontFile = preload("res://art/fonts/ZhiMangXing-Regular.ttf")

static func panel(radius: int = 8, border: Color = GOLD_LINE, alpha: float = 0.86) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK, alpha)
	sb.border_color = Color(border, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	sb.anti_aliasing = true
	return sb

## 大面板：更不透明 + 外投影 + 2px 古金边
static func big_panel() -> StyleBoxFlat:
	var sb := panel(12, GOLD_LINE, 0.95)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	sb.content_margin_left = 26; sb.content_margin_right = 26
	sb.content_margin_top = 18; sb.content_margin_bottom = 18
	return sb

## 内容分区（墨绿底）
static func section(radius: int = 8) -> StyleBoxFlat:
	var sb := panel(radius, GOLD_LINE, 0.55)
	sb.bg_color = Color(INK_GREEN, 0.55)
	sb.border_color = Color(GOLD_LINE, 0.35)
	return sb

static func pill_box(h: int = 36) -> StyleBoxFlat:
	var sb := panel(h / 2, GOLD_LINE, 0.82)
	sb.set_border_width_all(1)
	sb.content_margin_left = 6; sb.content_margin_right = 16
	sb.content_margin_top = 2; sb.content_margin_bottom = 2
	return sb

static func bar(color: Color) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(240, 16)
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(0.05, 0.05, 0.05, 0.75); bg.set_corner_radius_all(3)
	bg.border_color = Color(GOLD_LINE, 0.85); bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new(); fg.bg_color = color; fg.set_corner_radius_all(2)
	fg.border_color = color.lightened(0.25); fg.border_width_top = 1
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fg)
	return pb

static func label(text: String, size: int = 16, color: Color = MIST) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.05, 0.9))
	l.add_theme_constant_override("outline_size", 4 if size >= 18 else 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## 书法标题（Ma Shan Zheng）
static func title(text: String, size: int = 30, color: Color = GOLD_TEXT) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", TITLE_FONT)
	l.add_theme_constant_override("outline_size", 6)
	return l

## 行书副题（Zhi Mang Xing）
static func subtitle(text: String, size: int = 20, color: Color = GOLD_TEXT) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", SUB_FONT)
	return l

static func _btn_box(bg: Color, border: Color, radius: int, bw: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14; sb.content_margin_right = 14
	sb.content_margin_top = 5; sb.content_margin_bottom = 5
	sb.anti_aliasing = true
	return sb

## 标准按钮：墨绿底 + 古金描边 + 金字；悬停提亮，按下变深并下沉 1px，按压缩放回弹
static func button(text: String, size: int = 18, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE   # 空格是闪避键，按钮不能抢焦点
	b.add_theme_font_size_override("font_size", size)
	var base := Color("#3A5A49") if primary else INK_GREEN
	var r := 6
	b.add_theme_stylebox_override("normal", _btn_box(Color(base, 0.92), Color(GOLD_LINE, 0.85), r))
	b.add_theme_stylebox_override("hover", _btn_box(Color(base.lightened(0.12), 0.96), GOLD_TEXT, r))
	var pr := _btn_box(Color(INK, 0.98), GOLD_TEXT, r, 2)
	pr.content_margin_top = 6; pr.content_margin_bottom = 4
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("hover_pressed", pr)
	b.add_theme_stylebox_override("disabled", _btn_box(Color(0.16, 0.17, 0.16, 0.75), Color(0.45, 0.43, 0.38, 0.6), r))
	b.add_theme_color_override("font_color", GOLD_TEXT)
	b.add_theme_color_override("font_hover_color", Color("#FFF1CC"))
	b.add_theme_color_override("font_pressed_color", Color("#FFF1CC"))
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.53, 0.48))
	b.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.05, 0.9))
	b.add_theme_constant_override("outline_size", 3)
	add_press_fx(b)
	return b

## 朱砂强调按钮（装备/学习/兑换等主操作）
static func accent_button(text: String, size: int = 18) -> Button:
	var b := button(text, size, true)
	var r := 6
	b.add_theme_stylebox_override("normal", _btn_box(Color("#8E2C22"), GOLD_LINE, r))
	b.add_theme_stylebox_override("hover", _btn_box(Color("#A5372B"), GOLD_TEXT, r))
	return b

## 圆章按钮（装备/功法/地图/突破、闪避），字用书法体
static func medallion(text: String, diameter: int = 62, font_size: int = 28) -> Button:
	var b := button(text, font_size)
	var r := diameter / 2
	var n := _btn_box(Color(INK, 0.9), GOLD_LINE, r, 2)
	n.shadow_color = Color(0, 0, 0, 0.45); n.shadow_size = 6
	var h := _btn_box(Color(INK_GREEN, 0.95), GOLD_TEXT, r, 2)
	h.shadow_color = Color(GOLD_LINE, 0.25); h.shadow_size = 8
	var p := _btn_box(Color(INK_DARK, 0.98), GOLD_TEXT, r, 3)
	for sb in [n, h, p]:
		sb.content_margin_left = 0; sb.content_margin_right = 0
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("disabled", _btn_box(Color(0.15, 0.15, 0.15, 0.8), Color(0.45, 0.43, 0.38, 0.6), r, 2))
	b.add_theme_font_override("font", TITLE_FONT)
	b.custom_minimum_size = Vector2(diameter, diameter)
	return b

## 牌匾小标签（圆章下方的“装备”“功法”）
static func plaque(text: String, size: int = 14) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := panel(4, GOLD_LINE, 0.85)
	sb.content_margin_left = 8; sb.content_margin_right = 8; sb.content_margin_top = 0; sb.content_margin_bottom = 1
	pc.add_theme_stylebox_override("panel", sb)
	var l := label(text, size, GOLD_TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(l)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pc

## 按压反馈：按下缩到 0.93，松开回弹（TRANS_BACK）；悬停微放大。暂停中也播放（面板打开时战斗暂停）。
static func add_press_fx(c: Control) -> void:
	var setpivot := func() -> void: c.pivot_offset = c.size / 2.0
	c.resized.connect(setpivot)
	var anim := func(to: float, dur: float, back: bool) -> void:
		if not c.is_inside_tree():
			return
		if c.has_meta("_fx_tw"):
			var old: Tween = c.get_meta("_fx_tw")
			if old and old.is_valid():
				old.kill()
		var tw := c.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(c, "scale", Vector2(to, to), dur).set_trans(Tween.TRANS_BACK if back else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		c.set_meta("_fx_tw", tw)
	if c is BaseButton:
		var bb := c as BaseButton
		bb.button_down.connect(func() -> void: anim.call(0.93, 0.06, false))
		bb.button_up.connect(func() -> void: anim.call(1.0, 0.22, true))
	c.mouse_entered.connect(func() -> void:
		if not (c is BaseButton and (c as BaseButton).disabled):
			anim.call(1.04, 0.12, false))
	c.mouse_exited.connect(func() -> void: anim.call(1.0, 0.15, false))

## 面板入场：淡入 + 由 0.96 放大到 1 + 轻微上移（暂停中播放）
static func pop_in(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	c.modulate.a = 0.0
	c.scale = Vector2(0.96, 0.96)
	var tw := c.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.16)
	tw.tween_property(c, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 数字千分位
static func num(v: float) -> String:
	var s := str(int(round(v)))
	var neg := s.begins_with("-")
	if neg:
		s = s.substr(1)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if neg else "") + s + out

static func hsep(alpha: float = 0.45) -> HSeparator:
	var s := HSeparator.new()
	var sb := StyleBoxLine.new()
	sb.color = Color(GOLD_LINE, alpha); sb.thickness = 1
	s.add_theme_stylebox_override("separator", sb)
	return s

static func spacer(expand: bool = true) -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

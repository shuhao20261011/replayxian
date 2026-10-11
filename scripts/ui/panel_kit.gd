class_name PanelKit
extends RefCounted
## 养成面板通用件（v2 风格）：大面板外壳、标题栏、分区、品质条目行、页签

## 返回 {root: PanelContainer, body: VBoxContainer, head: HBoxContainer, close: Button}
static func shell(owner: PanelContainer, title_text: String, sub_text: String) -> Dictionary:
	owner.add_theme_stylebox_override("panel", UiStyle.big_panel())
	owner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner.offset_left = 48; owner.offset_right = -48; owner.offset_top = 40; owner.offset_bottom = -40
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); owner.add_child(v)
	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 14); v.add_child(head)
	var t := UiStyle.title(title_text, 40); head.add_child(t)
	var st := UiStyle.subtitle(sub_text, 20, Color(UiStyle.GOLD_TEXT, 0.7)); st.size_flags_vertical = Control.SIZE_SHRINK_END; head.add_child(st)
	head.add_child(UiStyle.spacer())
	var close := UiStyle.medallion("✕", 40, 18)
	close.remove_theme_font_override("font")
	close.tooltip_text = UiText.t("BTN_CLOSE")
	head.add_child(close)
	v.add_child(UiStyle.hsep(0.6))
	var body := VBoxContainer.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation", 8)
	v.add_child(body)
	owner.add_child(InkFrame.new())
	return {"body": body, "head": head, "close": close}

## 分区：带小标题的墨绿底块，返回内容 VBox
static func section(parent: Control, caption: String, min_w: float = 0.0, expand: bool = false) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiStyle.section())
	pc.custom_minimum_size = Vector2(min_w, 0)
	pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if expand:
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(pc)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); pc.add_child(v)
	if caption != "":
		var cap := UiStyle.subtitle(caption, 22); v.add_child(cap)
	return v

## 可滚动内容区
static func scroll(parent: Control) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; v.add_theme_constant_override("separation", 4)
	sc.add_child(v)
	return v

## 条目行按钮：左侧品质色竖条，选中时金边 + 亮底
static func row(text: String, accent: Color, selected: bool, font_size: int = 16, text_color: Color = UiStyle.GOLD_TEXT) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.add_theme_font_size_override("font_size", font_size)
	var mk := func(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
		var sb := UiStyle._btn_box(bg, border, 4, bw)
		sb.border_width_left = 5
		sb.border_color = border
		sb.content_margin_left = 14
		return sb
	var n: StyleBoxFlat = mk.call(Color(UiStyle.INK, 0.75 if not selected else 0.95), Color(accent, 0.95), 1)
	if selected:
		n.bg_color = Color(UiStyle.INK_GREEN, 0.95)
		n.border_width_top = 1; n.border_width_bottom = 1; n.border_width_right = 1
	var h: StyleBoxFlat = mk.call(Color(UiStyle.INK_GREEN, 0.9), accent.lightened(0.2), 1)
	var p: StyleBoxFlat = mk.call(Color(UiStyle.INK_DARK, 1.0), accent.lightened(0.3), 2)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, text_color)
	b.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.05, 0.9))
	b.add_theme_constant_override("outline_size", 3)
	b.custom_minimum_size = Vector2(0, 36)
	UiStyle.add_press_fx(b)
	return b

## 页签按钮（功法），选中时朱砂底
static func tab(text: String, color: Color, selected: bool) -> Button:
	var b := UiStyle.button(text, 20)
	b.add_theme_font_override("font", UiStyle.TITLE_FONT)
	if selected:
		var sb := UiStyle._btn_box(Color("#8E2C22"), UiStyle.GOLD_TEXT, 6, 2)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
	else:
		b.add_theme_color_override("font_color", color.lightened(0.35))
	b.custom_minimum_size = Vector2(112, 40)
	return b

## 一行“名称 …… 数值”
static func kv(parent: Control, k: String, v: String, vcolor: Color = UiStyle.MIST, delta: String = "", dcolor: Color = UiStyle.GOOD) -> void:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8); parent.add_child(h)
	var kl := UiStyle.label(k, 15, Color(UiStyle.GOLD_TEXT, 0.75)); kl.custom_minimum_size = Vector2(88, 0); h.add_child(kl)
	h.add_child(UiStyle.label(v, 16, vcolor))
	if delta != "":
		h.add_child(UiStyle.label(delta, 15, dcolor))

## PlayerState 操作结果码 → 上屏文案（ui_texts / 待收编表）；"ok" 返回 ok_text
static func result_text(code: String, ok_text: String = "") -> String:
	match code:
		"ok":
			return ok_text
		"no_lingshi":
			return UiText.t("ERR_NOT_ENOUGH", {"item_name": GameData.material_name("CUR_LINGSHI")})
		"no_refine":
			return UiText.t("ERR_NOT_ENOUGH", {"item_name": GameData.material_name("MAT_REFINE")})
		"no_pages":
			return UiText.t("ERR_NOT_ENOUGH", {"item_name": GameData.material_name(PlayerState.PAGE_ID)})
		"cannot_reroll": return UiText.t("ERR_CANNOT_REROLL")
		"not_in_bag": return UiText.t("ERR_NOT_IN_BAG")
		"no_pool": return UiText.t("ERR_NO_POOL")
		"no_book": return UiText.t("ERR_NO_BOOK")
		"already_learned": return UiText.t("ERR_ALREADY_LEARNED")
		"not_learned": return UiText.t("ERR_NOT_LEARNED")
		"max_level": return UiText.t("ERR_MAX_LEVEL")
		"locked_region": return UiText.t("ERR_LOCKED_REGION")
	push_warning("PanelKit.result_text: 未登记的结果码 %s" % code)
	return ""

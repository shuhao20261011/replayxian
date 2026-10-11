class_name ArtUi
extends RefCounted
## 第 3 批正式 UI 切图接入（art/ART_STYLE_GUIDE_final.md §5.4 / §5.8）。全部按路径加载：美术同名替换即生效；缺图返回 null，调用方退回程序绘制。
## 九宫格边距按 §5.4 表（左, 上, 右, 下）。

const UI_DIR := "res://art/ui/"
const ICON_DIR := "res://art/ui/icons/"
const THEME_PATH := "res://art/ui/ui_theme.tres"
## 切图 -> 九宫格边距
const MARGINS := {
	"ui_panel_9p": [35, 25, 35, 25], "ui_panel_9p_translucent": [35, 25, 35, 25],
	"ui_banner_9p": [62, 28, 62, 28], "ui_pill_9p": [24, 12, 24, 12], "ui_pill_9p_hover": [24, 12, 24, 12], "ui_pill_9p_pressed": [24, 12, 24, 12],
	"ui_slot_9p": [27, 27, 27, 27], "ui_slot_9p_pressed": [27, 27, 27, 27],
	"ui_tag_9p": [31, 13, 31, 13], "ui_tag_9p_hover": [31, 13, 31, 13], "ui_tag_9p_pressed": [31, 13, 31, 13], "ui_tag_9p_disabled": [31, 13, 31, 13],
	"ui_barframe_9p": [20, 10, 20, 10], "ui_barframe_over_9p": [20, 10, 20, 10],
	"ui_bar_hp_progress_9p": [20, 10, 20, 10], "ui_bar_shield_progress_9p": [20, 10, 20, 10],
}
## qualities.order 1~5 -> 预着色品质框
const QUALITY_FRAMES := ["white", "green", "blue", "purple", "orange"]

static func tex(name: String) -> Texture2D:
	var p := UI_DIR + name + ".png"
	return load(p) as Texture2D if ResourceLoader.exists(p) else null

static func icon_path(key: String) -> String:
	return ICON_DIR + key + ".png"

static func icon(key: String) -> Texture2D:
	return load(icon_path(key)) as Texture2D if key != "" and ResourceLoader.exists(icon_path(key)) else null

static func theme() -> Theme:
	return load(THEME_PATH) as Theme if ResourceLoader.exists(THEME_PATH) else null

## 九宫格 StyleBoxTexture；content 为内容边距（默认 = 九宫格边距）
static func box(name: String, content: Variant = null) -> StyleBoxTexture:
	var t := tex(name)
	if t == null:
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = t
	var m: Array = MARGINS.get(name, [0, 0, 0, 0])
	sb.texture_margin_left = m[0]; sb.texture_margin_top = m[1]; sb.texture_margin_right = m[2]; sb.texture_margin_bottom = m[3]
	var c: Array = content if content is Array else m
	sb.content_margin_left = c[0]; sb.content_margin_top = c[1]; sb.content_margin_right = c[2]; sb.content_margin_bottom = c[3]
	return sb

## 生命 / 护盾条：TextureProgressBar（under 底框 + progress + over 金边，统一 stretch margin 20,10,20,10）
static func bar(kind: String, size: Vector2) -> TextureProgressBar:
	var b := TextureProgressBar.new()
	b.texture_under = tex("ui_barframe_9p")
	b.texture_progress = tex("ui_bar_%s_progress_9p" % kind)
	b.texture_over = tex("ui_barframe_over_9p")
	b.nine_patch_stretch = true
	b.stretch_margin_left = 20; b.stretch_margin_top = 10; b.stretch_margin_right = 20; b.stretch_margin_bottom = 10
	b.custom_minimum_size = size
	b.step = 0.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

## 品质框：qualities.order（1 白 … 5 橙）
static func quality_frame(order: int) -> Texture2D:
	return tex("ui_frame_quality_" + QUALITY_FRAMES[clampi(order, 1, 5) - 1])

## 按键图标（1~4 / q / space），pressed=按下态
static func key_icon(key: String, pressed := false) -> Texture2D:
	return icon("ui_icon_key_" + key + ("_pressed" if pressed else ""))

## 表格行的 icon 列（equip_bases / materials / skill_books / gongfa …）；查不到返回空
static func icon_key(table: String, id_col: String, id: String) -> String:
	for r in GameData.tables.get(table, []):
		if str(r.get(id_col, "")) == id:
			return str(r.get("icon", ""))
	return ""

## 物品 id（装备底子 / 材料 / 货币 / 技能书）→ 图标
static func item_icon(item_id: String) -> Texture2D:
	for spec in [["equip_bases", "base_id"], ["materials", "item_id"], ["skill_books", "book_id"], ["gongfa", "gongfa_id"]]:
		var k := icon_key(spec[0], spec[1], item_id)
		if k != "":
			return icon(k)
	return icon("ui_icon_item_" + item_id.to_lower())

## design/icon_list.csv：refs 列（如 ui_texts:NAV_GEAR|ui_texts:NAV_GEAR_SHORT）→ icon_key。菜单图标等没有业务表 icon 列的条目从这里查
const ICON_LIST := "res://design/icon_list.csv"
static var _ref_keys: Dictionary = {}
static func icon_key_for_ref(ref: String) -> String:
	if _ref_keys.is_empty():
		_ref_keys["_"] = ""
		for r in CsvUtil.load_rows(ICON_LIST):
			for one in str(r.get("refs", "")).split("|", false):
				_ref_keys[one.strip_edges()] = str(r.get("icon_key", ""))
	return _ref_keys.get(ref, "")

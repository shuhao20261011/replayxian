class_name GongfaDef
extends Resource
## gongfa.csv 功法

@export var id := ""
@export var name := ""
@export var role := ""
@export var build_dir := ""
@export var book_map_id := ""
@export var color := Color.WHITE        # v5：文字色（水墨底上提亮）
@export var fx_color := Color.WHITE     # v5：技能特效色
@export var icon := ""
@export var desc := ""

static func from_row(r: Dictionary) -> GongfaDef:
	var d := GongfaDef.new()
	d.id = CsvUtil.s(r, "gongfa_id")
	d.name = CsvUtil.s(r, "name")
	d.role = CsvUtil.s(r, "role")
	d.build_dir = CsvUtil.s(r, "build_dir")
	d.book_map_id = CsvUtil.s(r, "book_map_id")
	d.color = Color.from_string(CsvUtil.s(r, "color"), Color.WHITE)
	d.fx_color = Color.from_string(CsvUtil.s(r, "fx_color", CsvUtil.s(r, "color")), d.color)
	d.icon = CsvUtil.s(r, "icon")
	d.desc = CsvUtil.s(r, "desc")
	return d

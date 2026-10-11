class_name MapDef
extends Resource
## maps.csv 地图（breakthrough_mat_id 允许为空：最后一张地图无突破材料）

@export var id := ""
@export var name := ""
@export var order := 1
@export var realm_required := ""
@export var gear_tier := 1
@export var book_gongfa_id := ""
@export var boss_id := ""
@export var breakthrough_mat_id := ""
@export var normal_enemy_ids := PackedStringArray()
@export var desc := ""
@export var telegraph_color := ""   # v5.1：本图首领预警色（招式色为空时使用）

## 背景占位图目录名：MAP_QINGZHU -> qingzhu
func art_key() -> String:
	return id.to_lower().trim_prefix("map_")

static func from_row(r: Dictionary) -> MapDef:
	var d := MapDef.new()
	d.id = CsvUtil.s(r, "map_id")
	d.name = CsvUtil.s(r, "name")
	d.order = CsvUtil.i(r, "order", 1)
	d.realm_required = CsvUtil.s(r, "realm_required")
	d.gear_tier = CsvUtil.i(r, "gear_tier", 1)
	d.book_gongfa_id = CsvUtil.s(r, "book_gongfa_id")
	d.boss_id = CsvUtil.s(r, "boss_id")
	d.breakthrough_mat_id = CsvUtil.s(r, "breakthrough_mat_id")
	d.normal_enemy_ids = CsvUtil.list(CsvUtil.s(r, "normal_enemy_ids"))
	d.desc = CsvUtil.s(r, "desc")
	d.telegraph_color = CsvUtil.s(r, "telegraph_color")
	return d

class_name RealmDef
extends Resource
## realms.csv 境界基础属性

@export var id := ""
@export var name := ""
@export var order := 1
@export var hp := 0.0
@export var atk := 0.0
@export var def := 0.0
@export var crit_rate := 0.05
@export var crit_dmg := 1.5
## 阶段5：突破条件与解锁（realms.csv v5.x）
@export var prev_realm_id := ""
@export var xiuwei_cost := 0
@export var lingshi_cost := 0
@export var material_id := ""
@export var material_count := 0
@export var unlock_map_id := ""
@export var desc := ""

static func from_row(r: Dictionary) -> RealmDef:
	var d := RealmDef.new()
	d.id = CsvUtil.s(r, "realm_id")
	d.name = CsvUtil.s(r, "name")
	d.order = CsvUtil.i(r, "order", 1)
	d.hp = CsvUtil.f(r, "hp")
	d.atk = CsvUtil.f(r, "atk")
	d.def = CsvUtil.f(r, "def")
	d.crit_rate = CsvUtil.f(r, "crit_rate", 0.05)
	d.crit_dmg = CsvUtil.f(r, "crit_dmg", 1.5)
	d.prev_realm_id = CsvUtil.s(r, "prev_realm_id")
	d.xiuwei_cost = CsvUtil.i(r, "xiuwei_cost")
	d.lingshi_cost = CsvUtil.i(r, "lingshi_cost")
	d.material_id = CsvUtil.s(r, "material_id")
	d.material_count = CsvUtil.i(r, "material_count")
	d.unlock_map_id = CsvUtil.s(r, "unlock_map_id")
	d.desc = CsvUtil.s(r, "desc")
	return d

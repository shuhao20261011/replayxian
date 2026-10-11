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
	return d

class_name EquipBaseDef
extends Resource
## equip_bases.csv 装备底子（阶段1-2只用于开局装备属性；生成/词条在阶段4）

@export var id := ""
@export var slot_id := ""
@export var gear_tier := 1
@export var name := ""
@export var atk := 0.0
@export var hp := 0.0
@export var def := 0.0
@export var crit_rate := 0.0
@export var move_speed := 0.0
@export var is_core := false

static func from_row(r: Dictionary) -> EquipBaseDef:
	var d := EquipBaseDef.new()
	d.id = CsvUtil.s(r, "base_id")
	d.slot_id = CsvUtil.s(r, "slot_id")
	d.gear_tier = CsvUtil.i(r, "gear_tier", 1)
	d.name = CsvUtil.s(r, "name")
	d.atk = CsvUtil.f(r, "atk")
	d.hp = CsvUtil.f(r, "hp")
	d.def = CsvUtil.f(r, "def")
	d.crit_rate = CsvUtil.f(r, "crit_rate")
	d.move_speed = CsvUtil.f(r, "move_speed")
	d.is_core = CsvUtil.b(r, "is_core")
	return d

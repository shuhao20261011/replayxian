class_name GearTierDef
extends Resource
## gear_tiers.csv 装备档位

@export var tier := 1
@export var map_id := ""
@export var flat_mult := 1.0
@export var decompose_mult := 1.0
@export var reroll_lingshi_mult := 1.0

static func from_row(r: Dictionary) -> GearTierDef:
	var d := GearTierDef.new()
	d.tier = CsvUtil.i(r, "gear_tier", 1)
	d.map_id = CsvUtil.s(r, "map_id")
	d.flat_mult = CsvUtil.f(r, "flat_mult", 1.0)
	d.decompose_mult = CsvUtil.f(r, "decompose_mult", 1.0)
	d.reroll_lingshi_mult = CsvUtil.f(r, "reroll_lingshi_mult", 1.0)
	return d

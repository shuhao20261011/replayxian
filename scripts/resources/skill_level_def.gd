class_name SkillLevelDef
extends Resource
## skill_levels.csv 一行：某技能某等级的数值

@export var level := 1
@export var damage_coef := 0.0
@export var cd_s := 0.0
@export var effect_value := 0.0
@export var effect2_value := 0.0
@export var chain_count := 0
@export var upgrade_cost_lingshi := 0

static func from_row(r: Dictionary) -> SkillLevelDef:
	var d := SkillLevelDef.new()
	d.level = CsvUtil.i(r, "level", 1)
	d.damage_coef = CsvUtil.f(r, "damage_coef")
	d.cd_s = CsvUtil.f(r, "cd_s")
	d.effect_value = CsvUtil.f(r, "effect_value")
	d.effect2_value = CsvUtil.f(r, "effect2_value")
	d.chain_count = CsvUtil.i(r, "chain_count")
	d.upgrade_cost_lingshi = CsvUtil.i(r, "upgrade_cost_lingshi")
	return d

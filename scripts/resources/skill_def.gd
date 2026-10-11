class_name SkillDef
extends Resource
## skills.csv 技能；levels 由 skill_levels.csv 按 (skill_id, level) 嵌入

@export var id := ""
@export var gongfa_id := ""
@export var name := ""
@export var slot_type := "active"   # active / passive
@export var tier := ""
@export var is_basic := false
@export var shape := ""             # projectile/line/chain/circle/rect/aura/self_buff/none
@export var anchor := ""            # facing/self/nearest_front/none
@export var range_px := 0.0
@export var width_px := 0.0
@export var height_px := 0.0
@export var radius_px := 0.0
@export var max_targets := 1
@export var hits := 1
@export var damage_coef := 0.0
@export var cd_s := 0.0
@export var duration_s := 0.0
@export var tick_interval_s := 0.0
@export var chain_count := 0
@export var chain_radius_px := 0.0
@export var chain_decay := 0.0
@export var effect_type := "none"
@export var effect_value := 0.0
@export var effect_duration_s := 0.0
@export var effect2_type := "none"
@export var effect2_value := 0.0
@export var coef_growth := 0.0
@export var cd_reduce := 0.0
@export var effect_growth := 0.0
@export var effect2_growth := 0.0
@export var upgrade_cost_mult := 1.0
@export var book_id := ""
@export var default_auto := true
@export var desc := ""
@export var icon := ""   # v5：图标键（ui_icon_*）
@export var levels: Array[SkillLevelDef] = []

func is_active() -> bool:
	return slot_type == "active"

func icon_path() -> String:
	if icon != "":
		return "res://art/ui/%s.png" % icon
	return "res://art/ui/ui_icon_skill_%s.png" % id.to_lower().trim_prefix("sk_")

## 取某等级数值；表中缺行时按成长字段推算，保证改表不崩
func level_def(lv: int) -> SkillLevelDef:
	for l in levels:
		if l.level == lv:
			return l
	var d := SkillLevelDef.new()
	d.level = lv
	d.damage_coef = damage_coef * (1.0 + coef_growth * (lv - 1))
	d.cd_s = cd_s * (1.0 - cd_reduce * (lv - 1))
	d.effect_value = effect_value + effect_growth * (lv - 1)
	d.effect2_value = effect2_value + effect2_growth * (lv - 1)
	d.chain_count = chain_count
	return d

static func from_row(r: Dictionary) -> SkillDef:
	var d := SkillDef.new()
	d.id = CsvUtil.s(r, "skill_id")
	d.gongfa_id = CsvUtil.s(r, "gongfa_id")
	d.name = CsvUtil.s(r, "name")
	d.slot_type = CsvUtil.s(r, "slot_type", "active")
	d.tier = CsvUtil.s(r, "tier")
	d.is_basic = CsvUtil.b(r, "is_basic")
	d.shape = CsvUtil.s(r, "shape")
	d.anchor = CsvUtil.s(r, "anchor")
	d.range_px = CsvUtil.f(r, "range_px")
	d.width_px = CsvUtil.f(r, "width_px")
	d.height_px = CsvUtil.f(r, "height_px")
	d.radius_px = CsvUtil.f(r, "radius_px")
	d.max_targets = CsvUtil.i(r, "max_targets", 1)
	d.hits = maxi(CsvUtil.i(r, "hits", 1), 1)
	d.damage_coef = CsvUtil.f(r, "damage_coef")
	d.cd_s = CsvUtil.f(r, "cd_s")
	d.duration_s = CsvUtil.f(r, "duration_s")
	d.tick_interval_s = CsvUtil.f(r, "tick_interval_s")
	d.chain_count = CsvUtil.i(r, "chain_count")
	d.chain_radius_px = CsvUtil.f(r, "chain_radius_px")
	d.chain_decay = CsvUtil.f(r, "chain_decay")
	d.effect_type = CsvUtil.s(r, "effect_type", "none")
	d.effect_value = CsvUtil.f(r, "effect_value")
	d.effect_duration_s = CsvUtil.f(r, "effect_duration_s")
	d.effect2_type = CsvUtil.s(r, "effect2_type", "none")
	d.effect2_value = CsvUtil.f(r, "effect2_value")
	d.coef_growth = CsvUtil.f(r, "coef_growth")
	d.cd_reduce = CsvUtil.f(r, "cd_reduce")
	d.effect_growth = CsvUtil.f(r, "effect_growth")
	d.effect2_growth = CsvUtil.f(r, "effect2_growth")
	d.upgrade_cost_mult = CsvUtil.f(r, "upgrade_cost_mult", 1.0)
	d.book_id = CsvUtil.s(r, "book_id")
	d.default_auto = CsvUtil.b(r, "default_auto", true)
	d.desc = CsvUtil.s(r, "desc")
	d.icon = CsvUtil.s(r, "icon")
	return d

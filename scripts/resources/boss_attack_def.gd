class_name BossAttackDef
extends Resource
## boss_attacks.csv 首领招式（v2：damage_type / damage_maxhp_pct / first_cast_s / telegraph_color / telegraph_style）

@export var id := ""
@export var boss_id := ""
@export var name := ""
@export var is_danger := false
@export var warn_s := 0.0
@export var shape := "rect"        # rect / circle
@export var anchor := "facing"     # facing / self / player / arena
@export var offset_x := 0.0
@export var width_px := 0.0
@export var height_px := 0.0
@export var radius_px := 0.0
@export var count := 1
@export var damage_type := "atk_coef"   # atk_coef / true_maxhp
@export var damage_coef := 0.0
@export var damage_maxhp_pct := 0.0
@export var cd_s := 1.0
@export var first_cast_s := 0.0
@export var min_level_index := 1
@export var telegraph_color := ""   # 空 = 用 constants.TELEGRAPH_DEFAULT_COLOR
@export var telegraph_style := ""   # 空 = 用 constants.TELEGRAPH_DEFAULT_STYLE
@export var desc := ""

func is_true_damage() -> bool:
	return damage_type == "true_maxhp"

static func from_row(r: Dictionary) -> BossAttackDef:
	var d := BossAttackDef.new()
	d.id = CsvUtil.s(r, "attack_id")
	d.boss_id = CsvUtil.s(r, "boss_id")
	d.name = CsvUtil.s(r, "name")
	d.is_danger = CsvUtil.b(r, "is_danger")
	d.warn_s = CsvUtil.f(r, "warn_s")
	d.shape = CsvUtil.s(r, "shape", "rect")
	d.anchor = CsvUtil.s(r, "anchor", "facing")
	d.offset_x = CsvUtil.f(r, "offset_x")
	d.width_px = CsvUtil.f(r, "width_px")
	d.height_px = CsvUtil.f(r, "height_px")
	d.radius_px = CsvUtil.f(r, "radius_px")
	d.count = maxi(CsvUtil.i(r, "count", 1), 1)
	d.damage_type = CsvUtil.s(r, "damage_type", "atk_coef")
	if d.damage_type == "":
		d.damage_type = "atk_coef"
	d.damage_coef = CsvUtil.f(r, "damage_coef")
	d.damage_maxhp_pct = CsvUtil.f(r, "damage_maxhp_pct")
	d.cd_s = CsvUtil.f(r, "cd_s", 1.0)
	d.first_cast_s = CsvUtil.f(r, "first_cast_s", d.cd_s * 0.5)
	d.min_level_index = CsvUtil.i(r, "min_level_index", 1)
	d.telegraph_color = CsvUtil.s(r, "telegraph_color")
	d.telegraph_style = CsvUtil.s(r, "telegraph_style")
	d.desc = CsvUtil.s(r, "desc")
	return d

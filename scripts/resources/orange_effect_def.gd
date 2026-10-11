class_name OrangeEffectDef
extends Resource
## orange_effects.csv 核心橙装流派特效（参数为 param1~3_key/param1~3 键值）

@export var id := ""
@export var base_id := ""
@export var gongfa_id := ""
@export var name := ""
@export var params := {}
@export var internal_cd_s := 0.0
@export var desc := ""

func p(key: String, def_value: float = 0.0) -> float:
	return float(params.get(key, def_value))

static func from_row(r: Dictionary) -> OrangeEffectDef:
	var d := OrangeEffectDef.new()
	d.id = CsvUtil.s(r, "orange_effect_id")
	d.base_id = CsvUtil.s(r, "base_id")
	d.gongfa_id = CsvUtil.s(r, "gongfa_id")
	d.name = CsvUtil.s(r, "name")
	for i in range(1, 10):
		var k := CsvUtil.s(r, "param%d_key" % i)
		if k != "":
			d.params[k] = CsvUtil.f(r, "param%d" % i)
	d.internal_cd_s = CsvUtil.f(r, "internal_cd_s")
	d.desc = CsvUtil.s(r, "desc")
	return d

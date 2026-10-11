class_name AffixDef
extends Resource
## affixes.csv 随机词条

@export var id := ""
@export var name := ""
@export var stat := ""
@export var value_type := "flat"   # flat / pct / int
@export var scale_by_tier := false
@export var allowed_slots := PackedStringArray()
@export var weight := 1.0
@export var min_quality := "Q_GREEN"
## 品质名小写（green/blue/purple/orange）-> Vector2(min, max)
@export var ranges := {}

func range_for(quality_id: String) -> Vector2:
	return ranges.get(quality_id.to_lower().trim_prefix("q_"), Vector2.ZERO)

static func from_row(r: Dictionary) -> AffixDef:
	var d := AffixDef.new()
	d.id = CsvUtil.s(r, "affix_id")
	d.name = CsvUtil.s(r, "name")
	d.stat = CsvUtil.s(r, "stat")
	d.value_type = CsvUtil.s(r, "value_type", "flat")
	d.scale_by_tier = CsvUtil.b(r, "scale_by_tier")
	d.allowed_slots = CsvUtil.list(CsvUtil.s(r, "allowed_slots"))
	d.weight = CsvUtil.f(r, "weight", 1.0)
	d.min_quality = CsvUtil.s(r, "min_quality", "Q_GREEN")
	for k in r.keys():
		var key := str(k)
		if key.ends_with("_min"):
			var q := key.trim_suffix("_min")
			d.ranges[q] = Vector2(CsvUtil.f(r, key), CsvUtil.f(r, q + "_max"))
	return d

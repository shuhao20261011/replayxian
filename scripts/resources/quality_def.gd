class_name QualityDef
extends Resource
## qualities.csv 品质

@export var id := ""
@export var name := ""
@export var order := 1
@export var color := Color.WHITE        # v5：品质名文字色
@export var beam_color := Color.WHITE   # v5：掉落光柱/品质框色
@export var affix_count := 0
@export var base_mult := 1.0

static func from_row(r: Dictionary) -> QualityDef:
	var d := QualityDef.new()
	d.id = CsvUtil.s(r, "quality_id")
	d.name = CsvUtil.s(r, "name")
	d.order = CsvUtil.i(r, "order", 1)
	d.color = Color.from_string(CsvUtil.s(r, "color"), Color.WHITE)
	d.beam_color = Color.from_string(CsvUtil.s(r, "beam_color", CsvUtil.s(r, "color")), d.color)
	d.affix_count = CsvUtil.i(r, "affix_count")
	d.base_mult = CsvUtil.f(r, "base_mult", 1.0)
	return d

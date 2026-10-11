class_name SkillBookDef
extends Resource
## skill_books.csv 技能书（一书一技能）

@export var id := ""
@export var skill_id := ""
@export var name := ""
@export var gongfa_id := ""
@export var region_map_id := ""
@export var rarity := ""
@export var decompose_pages := 1
@export var exchange_pages := 10
@export var source_desc := ""

static func from_row(r: Dictionary) -> SkillBookDef:
	var d := SkillBookDef.new()
	d.id = CsvUtil.s(r, "book_id")
	d.skill_id = CsvUtil.s(r, "skill_id")
	d.name = CsvUtil.s(r, "name")
	d.gongfa_id = CsvUtil.s(r, "gongfa_id")
	d.region_map_id = CsvUtil.s(r, "region_map_id")
	d.rarity = CsvUtil.s(r, "rarity")
	d.decompose_pages = CsvUtil.i(r, "decompose_pages", 1)
	d.exchange_pages = CsvUtil.i(r, "exchange_pages", 10)
	d.source_desc = CsvUtil.s(r, "source_desc")
	return d

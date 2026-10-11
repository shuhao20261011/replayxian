class_name EnemyDef
extends Resource
## enemies.csv 普通怪与首领（基准数值，实际再乘 levels 倍率）

@export var id := ""
@export var name := ""
@export var kind := "normal"   # normal / boss
@export var map_id := ""
@export var hp := 0.0
@export var atk := 0.0
@export var def := 0.0
@export var move_speed := 0.0
@export var attack_interval_s := 1.0
@export var attack_range_px := 60.0
@export var behavior := "melee_chase"
@export var params := {}       # behavior_param 解析结果（字符串值）
@export var attack_ids := PackedStringArray()
@export var lingshi := 0.0
@export var xiuwei := 0.0
@export var desc := ""

func is_boss() -> bool:
	return kind == "boss"

func param_f(key: String, def_value: float = 0.0) -> float:
	var v := str(params.get(key, ""))
	return v.to_float() if v.is_valid_float() or v.is_valid_int() else def_value

func param_b(key: String) -> bool:
	return str(params.get(key, "false")).to_lower() == "true"

## 占位图命名：EN_BAMBOO_IMP -> art/enemies/enm_bamboo_imp_idle_01f.png；BOSS_ZHUMEI -> art/bosses/boss_zhumei_idle_01f.png
func texture_path() -> String:
	if is_boss():
		return "res://art/bosses/boss_%s_idle_01f.png" % id.to_lower().trim_prefix("boss_")
	return "res://art/enemies/enm_%s_idle_01f.png" % id.to_lower().trim_prefix("en_")

static func from_row(r: Dictionary) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = CsvUtil.s(r, "enemy_id")
	d.name = CsvUtil.s(r, "name")
	d.kind = CsvUtil.s(r, "kind", "normal")
	d.map_id = CsvUtil.s(r, "map_id")
	d.hp = CsvUtil.f(r, "hp")
	d.atk = CsvUtil.f(r, "atk")
	d.def = CsvUtil.f(r, "def")
	d.move_speed = CsvUtil.f(r, "move_speed")
	d.attack_interval_s = CsvUtil.f(r, "attack_interval_s", 1.0)
	d.attack_range_px = CsvUtil.f(r, "attack_range_px", 60.0)
	d.behavior = CsvUtil.s(r, "behavior", "melee_chase")
	d.params = CsvUtil.kv(CsvUtil.s(r, "behavior_param"))
	d.attack_ids = CsvUtil.list(str(d.params.get("attack_ids", "")))
	d.lingshi = CsvUtil.f(r, "lingshi")
	d.xiuwei = CsvUtil.f(r, "xiuwei")
	d.desc = CsvUtil.s(r, "desc")
	return d

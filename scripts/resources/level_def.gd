class_name LevelDef
extends Resource
## levels.csv 关卡；waves 由 waves.csv 按 level_id 分组嵌入

@export var id := ""
@export var map_id := ""
@export var index := 1
@export var global_index := 1
@export var name := ""
@export var enemy_hp_mult := 1.0
@export var enemy_atk_mult := 1.0
@export var boss_id := ""
@export var boss_hp_mult := 1.0
@export var boss_atk_mult := 1.0
@export var boss_time_limit_s := 60.0
@export var wave_count := 4
@export var unlock_level_id := ""
@export var unlock_realm_id := ""
@export var normal_drop_table_id := ""
@export var boss_drop_table_id := ""
@export var first_clear_reward_id := ""
@export var offline_reward_id := ""
@export var desc := ""
@export var waves: Array[WaveDef] = []

func wave_entries(wave_index: int) -> Array[WaveDef]:
	var out: Array[WaveDef] = []
	for w in waves:
		if w.wave_index == wave_index:
			out.append(w)
	return out

static func from_row(r: Dictionary) -> LevelDef:
	var d := LevelDef.new()
	d.id = CsvUtil.s(r, "level_id")
	d.map_id = CsvUtil.s(r, "map_id")
	d.index = CsvUtil.i(r, "index", 1)
	d.global_index = CsvUtil.i(r, "global_index", 1)
	d.name = CsvUtil.s(r, "name")
	d.enemy_hp_mult = CsvUtil.f(r, "enemy_hp_mult", 1.0)
	d.enemy_atk_mult = CsvUtil.f(r, "enemy_atk_mult", 1.0)
	d.boss_id = CsvUtil.s(r, "boss_id")
	d.boss_hp_mult = CsvUtil.f(r, "boss_hp_mult", 1.0)
	d.boss_atk_mult = CsvUtil.f(r, "boss_atk_mult", 1.0)
	d.boss_time_limit_s = CsvUtil.f(r, "boss_time_limit_s", 60.0)
	d.wave_count = CsvUtil.i(r, "wave_count", 4)
	d.unlock_level_id = CsvUtil.s(r, "unlock_level_id")
	d.unlock_realm_id = CsvUtil.s(r, "unlock_realm_id")
	d.normal_drop_table_id = CsvUtil.s(r, "normal_drop_table_id")
	d.boss_drop_table_id = CsvUtil.s(r, "boss_drop_table_id")
	d.first_clear_reward_id = CsvUtil.s(r, "first_clear_reward_id")
	d.offline_reward_id = CsvUtil.s(r, "offline_reward_id")
	d.desc = CsvUtil.s(r, "desc")
	return d

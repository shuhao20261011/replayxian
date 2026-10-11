class_name WaveDef
extends Resource
## waves.csv 一行：某关某波中的一组怪

@export var level_id := ""
@export var wave_index := 1
@export var enemy_id := ""
@export var count := 1
@export var spawn_delay_s := 0.0
@export var spawn_side := "right"
@export var formation := "cluster"

static func from_row(r: Dictionary) -> WaveDef:
	var d := WaveDef.new()
	d.level_id = CsvUtil.s(r, "level_id")
	d.wave_index = CsvUtil.i(r, "wave_index", 1)
	d.enemy_id = CsvUtil.s(r, "enemy_id")
	d.count = CsvUtil.i(r, "count", 1)
	d.spawn_delay_s = CsvUtil.f(r, "spawn_delay_s")
	d.spawn_side = CsvUtil.s(r, "spawn_side", "right")
	d.formation = CsvUtil.s(r, "formation", "cluster")
	return d

extends Node
## Autoload: 配置表。启动时读取 design/data/*.csv（25张）并转成 Resource 字典。
## 改表即改游戏：所有战斗数值、波次、首领招式、常量都从这里取，代码里只保留“表里没有该项时”的兜底默认值。
## 可用命令行 `-- --data-dir=<目录>` 或 load_all(dir) 指向另一套表做试玩/测试。

signal data_reloaded

const DEFAULT_DATA_DIR := "res://design/data"
const TABLE_NAMES: PackedStringArray = [
	"affixes", "book_pools", "boss_attacks", "constants", "drop_tables", "enemies", "equip_bases",
	"equip_slots", "first_clear_rewards", "gear_tiers", "gongfa", "levels", "maps", "materials",
	"offline_rewards", "orange_effects", "qualities", "quality_weights", "realms", "skill_books",
	"skill_levels", "skills", "start_kit", "tutorial_steps", "ui_texts", "waves",
]

var data_dir := DEFAULT_DATA_DIR
## 原始行：表名 -> Array[Dictionary]（阶段3+ 的表先以原始行形式提供）
var tables := {}
var constants := {}
var gongfa := {}        # id -> GongfaDef
var skills := {}        # id -> SkillDef
var books := {}         # id -> SkillBookDef
var enemies := {}       # id -> EnemyDef
var boss_attacks := {}  # id -> BossAttackDef
var maps := {}          # id -> MapDef
var levels := {}        # id -> LevelDef
var levels_ordered: Array[LevelDef] = []
var realms := {}        # id -> RealmDef
var realms_ordered: Array[RealmDef] = []
var equip_bases := {}   # id -> EquipBaseDef
var qualities := {}     # id -> QualityDef
var materials := {}     # id -> Dictionary
var errors := PackedStringArray()

func _ready() -> void:
	var dir := DEFAULT_DATA_DIR
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--data-dir="):
			dir = arg.trim_prefix("--data-dir=")
	load_all(dir)

func load_all(dir: String = DEFAULT_DATA_DIR) -> bool:
	data_dir = dir
	errors = PackedStringArray()
	tables.clear(); constants.clear(); gongfa.clear(); skills.clear(); books.clear(); enemies.clear()
	boss_attacks.clear(); maps.clear(); levels.clear(); levels_ordered.clear(); realms.clear()
	realms_ordered.clear(); equip_bases.clear(); qualities.clear(); materials.clear()
	for t in TABLE_NAMES:
		var path := dir.path_join(t + ".csv")
		if not FileAccess.file_exists(path):
			errors.append("缺少配置表 %s" % path)
			tables[t] = []
			continue
		tables[t] = CsvUtil.load_rows(path)
	_build()
	_validate()
	for e in errors:
		push_warning("GameData: " + e)
	data_reloaded.emit()
	return errors.is_empty()

func _build() -> void:
	for r in tables.get("constants", []):
		constants[CsvUtil.s(r, "key")] = CsvUtil.s(r, "value")
	for r in tables.get("gongfa", []):
		var g := GongfaDef.from_row(r); gongfa[g.id] = g
	for r in tables.get("skills", []):
		var s := SkillDef.from_row(r); skills[s.id] = s
	for r in tables.get("skill_levels", []):
		var sid := CsvUtil.s(r, "skill_id")
		if skills.has(sid):
			(skills[sid] as SkillDef).levels.append(SkillLevelDef.from_row(r))
		else:
			errors.append("skill_levels 引用了不存在的技能 %s" % sid)
	for s: SkillDef in skills.values():
		s.levels.sort_custom(func(a: SkillLevelDef, b: SkillLevelDef) -> bool: return a.level < b.level)
	for r in tables.get("skill_books", []):
		var bk := SkillBookDef.from_row(r); books[bk.id] = bk
	for r in tables.get("enemies", []):
		var e := EnemyDef.from_row(r); enemies[e.id] = e
	for r in tables.get("boss_attacks", []):
		var a := BossAttackDef.from_row(r); boss_attacks[a.id] = a
	for r in tables.get("maps", []):
		var m := MapDef.from_row(r); maps[m.id] = m
	for r in tables.get("levels", []):
		var l := LevelDef.from_row(r); levels[l.id] = l; levels_ordered.append(l)
	levels_ordered.sort_custom(func(a: LevelDef, b: LevelDef) -> bool: return a.global_index < b.global_index)
	for r in tables.get("waves", []):
		var w := WaveDef.from_row(r)
		if levels.has(w.level_id):
			(levels[w.level_id] as LevelDef).waves.append(w)
		else:
			errors.append("waves 引用了不存在的关卡 %s" % w.level_id)
	for r in tables.get("realms", []):
		var rl := RealmDef.from_row(r); realms[rl.id] = rl; realms_ordered.append(rl)
	realms_ordered.sort_custom(func(a: RealmDef, b: RealmDef) -> bool: return a.order < b.order)
	for r in tables.get("equip_bases", []):
		var eb := EquipBaseDef.from_row(r); equip_bases[eb.id] = eb
	for r in tables.get("qualities", []):
		var q := QualityDef.from_row(r); qualities[q.id] = q
	for r in tables.get("materials", []):
		materials[CsvUtil.s(r, "item_id")] = r

## 引用完整性（阶段1-2用到的部分；完整校验见 design/tools/validate.py）
func _validate() -> void:
	for s: SkillDef in skills.values():
		if not gongfa.has(s.gongfa_id):
			errors.append("技能 %s 的功法 %s 不存在" % [s.id, s.gongfa_id])
		if s.book_id != "" and not books.has(s.book_id):
			errors.append("技能 %s 的技能书 %s 不存在" % [s.id, s.book_id])
	for bk: SkillBookDef in books.values():
		if not skills.has(bk.skill_id):
			errors.append("技能书 %s 的技能 %s 不存在" % [bk.id, bk.skill_id])
	for e: EnemyDef in enemies.values():
		for aid in e.attack_ids:
			if not boss_attacks.has(aid):
				errors.append("首领 %s 的招式 %s 不存在" % [e.id, aid])
	for l: LevelDef in levels_ordered:
		if not maps.has(l.map_id):
			errors.append("关卡 %s 的地图 %s 不存在" % [l.id, l.map_id])
		if not enemies.has(l.boss_id):
			errors.append("关卡 %s 的首领 %s 不存在" % [l.id, l.boss_id])
		if l.unlock_level_id != "" and not levels.has(l.unlock_level_id):
			errors.append("关卡 %s 的前置关卡 %s 不存在" % [l.id, l.unlock_level_id])
		for wi in range(1, l.wave_count + 1):
			if l.wave_entries(wi).is_empty():
				errors.append("关卡 %s 缺少第%d波" % [l.id, wi])
		for w in l.waves:
			if not enemies.has(w.enemy_id):
				errors.append("关卡 %s 波次引用了不存在的敌人 %s" % [l.id, w.enemy_id])
	for m: MapDef in maps.values():
		# breakthrough_mat_id 允许为空（v2：最后一张地图无突破材料）
		if m.breakthrough_mat_id != "" and not materials.has(m.breakthrough_mat_id):
			errors.append("地图 %s 的突破材料 %s 不存在" % [m.id, m.breakthrough_mat_id])
	for r in tables.get("start_kit", []):
		var bid := CsvUtil.s(r, "ref_id")
		if not equip_bases.has(bid):
			errors.append("start_kit 引用了不存在的装备底子 %s" % bid)

# ---------- 常量 ----------
func const_f(key: String, def_value: float = 0.0) -> float:
	var v := str(constants.get(key, ""))
	return v.to_float() if v.is_valid_float() or v.is_valid_int() else def_value

func const_i(key: String, def_value: int = 0) -> int:
	return int(round(const_f(key, def_value)))

func const_s(key: String, def_value: String = "") -> String:
	return str(constants.get(key, def_value))

# ---------- 查询 ----------
func get_skill(id: String) -> SkillDef:
	return skills.get(id) as SkillDef

func get_enemy(id: String) -> EnemyDef:
	return enemies.get(id) as EnemyDef

func get_level(id: String) -> LevelDef:
	return levels.get(id) as LevelDef

func get_map(id: String) -> MapDef:
	return maps.get(id) as MapDef

func get_realm(id: String) -> RealmDef:
	return realms.get(id) as RealmDef

func get_boss_attack(id: String) -> BossAttackDef:
	return boss_attacks.get(id) as BossAttackDef

func first_level() -> LevelDef:
	return levels_ordered[0] if not levels_ordered.is_empty() else null

func basic_skill_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for r in tables.get("skills", []):   # 保持表内顺序
		var s := get_skill(CsvUtil.s(r, "skill_id"))
		if s != null and s.is_basic and s.is_active():
			out.append(s.id)
	return out

## v5.1 预警取色：boss_attacks.telegraph_color（非空）→ maps.telegraph_color → TELEGRAPH_DEFAULT_COLOR；
## 玩家设置“统一预警白”时一律 TELEGRAPH_ALT_COLOR。兜底色与美术 v2 规范一致（朱砂 #B8382C / 预警白 #F4F1EA）
const FALLBACK_TELEGRAPH := "#B8382C"
const FALLBACK_TELEGRAPH_ALT := "#F4F1EA"

func telegraph_color(attack: BossAttackDef, map_id: String = "", unified_alt: bool = false) -> Color:
	if unified_alt:
		return Color.from_string(const_s("TELEGRAPH_ALT_COLOR", FALLBACK_TELEGRAPH_ALT), Color(FALLBACK_TELEGRAPH_ALT))
	var c := attack.telegraph_color
	if c == "" and map_id != "" and maps.has(map_id):
		c = (maps[map_id] as MapDef).telegraph_color
	if c == "":
		c = const_s("TELEGRAPH_DEFAULT_COLOR", FALLBACK_TELEGRAPH)
	return Color.from_string(c, Color(FALLBACK_TELEGRAPH))

func telegraph_style(attack: BossAttackDef) -> String:
	return attack.telegraph_style if attack.telegraph_style != "" else const_s("TELEGRAPH_DEFAULT_STYLE", "dashed")

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
var affixes := {}       # id -> AffixDef
var affixes_ordered: Array[AffixDef] = []
var gear_tiers := {}    # tier(int) -> GearTierDef
var orange_effects := {} # id -> OrangeEffectDef
var equip_slots: Array[Dictionary] = []   # 按 order 排序的 {slot_id, name, order}
var quality_weights := {} # weight_set_id -> {quality_id: weight}
var drop_tables := {}   # drop_table_id -> Array[Dictionary]（按 seq）
var book_pools := {}    # book_pool_id -> Array[{book_id, weight}]
var first_clear := {}   # reward_id -> Array[Dictionary]（按 seq）
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
	affixes.clear(); affixes_ordered.clear(); gear_tiers.clear(); orange_effects.clear(); equip_slots.clear()
	quality_weights.clear(); drop_tables.clear(); book_pools.clear(); first_clear.clear()
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
	for r in tables.get("affixes", []):
		var af := AffixDef.from_row(r); affixes[af.id] = af; affixes_ordered.append(af)
	for r in tables.get("gear_tiers", []):
		var gt := GearTierDef.from_row(r); gear_tiers[gt.tier] = gt
	for r in tables.get("orange_effects", []):
		var oe := OrangeEffectDef.from_row(r); orange_effects[oe.id] = oe
	for r in tables.get("equip_slots", []):
		equip_slots.append({"slot_id": CsvUtil.s(r, "slot_id"), "name": CsvUtil.s(r, "name"), "order": CsvUtil.i(r, "order")})
	equip_slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.order < b.order)
	for r in tables.get("quality_weights", []):
		var w := {}
		for q in qualities.keys():
			w[q] = CsvUtil.f(r, q)
		quality_weights[CsvUtil.s(r, "weight_set_id")] = w
	for r in tables.get("drop_tables", []):
		var id := CsvUtil.s(r, "drop_table_id")
		if not drop_tables.has(id):
			drop_tables[id] = []
		drop_tables[id].append(r)
	for r in tables.get("book_pools", []):
		var id := CsvUtil.s(r, "book_pool_id")
		if not book_pools.has(id):
			book_pools[id] = []
		book_pools[id].append({"book_id": CsvUtil.s(r, "book_id"), "weight": CsvUtil.f(r, "weight", 1.0)})
	for r in tables.get("first_clear_rewards", []):
		var id := CsvUtil.s(r, "reward_id")
		if not first_clear.has(id):
			first_clear[id] = []
		first_clear[id].append(r)
	for arr in drop_tables.values():
		arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return CsvUtil.i(a, "seq") < CsvUtil.i(b, "seq"))
	for arr in first_clear.values():
		arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return CsvUtil.i(a, "seq") < CsvUtil.i(b, "seq"))

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
	for af: AffixDef in affixes.values():
		for sl in af.allowed_slots:
			if not _has_slot(sl):
				errors.append("词条 %s 的槽位 %s 不存在" % [af.id, sl])
		if not qualities.has(af.min_quality):
			errors.append("词条 %s 的最低品质 %s 不存在" % [af.id, af.min_quality])
	for eb: EquipBaseDef in equip_bases.values():
		if not _has_slot(eb.slot_id):
			errors.append("装备底子 %s 的槽位 %s 不存在" % [eb.id, eb.slot_id])
		if eb.orange_effect_id != "" and not orange_effects.has(eb.orange_effect_id):
			errors.append("装备底子 %s 的橙装特效 %s 不存在" % [eb.id, eb.orange_effect_id])
	for id in drop_tables:
		for r in drop_tables[id]:
			_check_ref("掉落表 " + id, CsvUtil.s(r, "entry_type"), CsvUtil.s(r, "ref_id"), CsvUtil.s(r, "weight_set_id"))
	for id in first_clear:
		for r in first_clear[id]:
			_check_ref("首通奖励 " + id, CsvUtil.s(r, "reward_type"), CsvUtil.s(r, "ref_id"), CsvUtil.s(r, "weight_set_id"))
	for id in book_pools:
		for e in book_pools[id]:
			if not books.has(e.book_id):
				errors.append("书池 %s 引用了不存在的技能书 %s" % [id, e.book_id])
	for l in levels_ordered:
		for t in [l.normal_drop_table_id, l.boss_drop_table_id]:
			if t != "" and not drop_tables.has(t):
				errors.append("关卡 %s 的掉落表 %s 不存在" % [l.id, t])
	for r in tables.get("start_kit", []):
		var bid := CsvUtil.s(r, "ref_id")
		if not equip_bases.has(bid):
			errors.append("start_kit 引用了不存在的装备底子 %s" % bid)

func _has_slot(slot_id: String) -> bool:
	for s in equip_slots:
		if s.slot_id == slot_id:
			return true
	return false

func _check_ref(where: String, kind: String, ref: String, ws: String) -> void:
	match kind:
		"equipment":
			if tier_from_ref(ref) <= 0 or not gear_tiers.has(tier_from_ref(ref)):
				errors.append("%s 装备档位 %s 无效" % [where, ref])
			if ws != "" and not quality_weights.has(ws):
				errors.append("%s 品质权重组 %s 不存在" % [where, ws])
		"material":
			if not materials.has(ref):
				errors.append("%s 材料 %s 不存在" % [where, ref])
		"book_pool":
			if not book_pools.has(ref):
				errors.append("%s 书池 %s 不存在" % [where, ref])
		"book":
			if not books.has(ref):
				errors.append("%s 技能书 %s 不存在" % [where, ref])
		"orange_choice":
			if not equip_bases.has(ref):
				errors.append("%s 橙装底子 %s 不存在" % [where, ref])

## "TIER_2" -> 2
func tier_from_ref(ref: String) -> int:
	return ref.trim_prefix("TIER_").to_int() if ref.begins_with("TIER_") else 0

func get_book(id: String) -> SkillBookDef:
	return books.get(id) as SkillBookDef

func get_quality(id: String) -> QualityDef:
	return qualities.get(id) as QualityDef

func get_base(id: String) -> EquipBaseDef:
	return equip_bases.get(id) as EquipBaseDef

func get_tier(tier: int) -> GearTierDef:
	return gear_tiers.get(tier) as GearTierDef

func slot_name(slot_id: String) -> String:
	for s in equip_slots:
		if s.slot_id == slot_id:
			return s.name
	return slot_id

func material_name(id: String) -> String:
	return CsvUtil.s(materials.get(id, {}), "name", id)

func qualities_ordered() -> Array[QualityDef]:
	var out: Array[QualityDef] = []
	for q: QualityDef in qualities.values():
		out.append(q)
	out.sort_custom(func(a: QualityDef, b: QualityDef) -> bool: return a.order < b.order)
	return out

func skills_of_gongfa(gongfa_id: String) -> Array[SkillDef]:
	var out: Array[SkillDef] = []
	for r in tables.get("skills", []):
		var s := get_skill(CsvUtil.s(r, "skill_id"))
		if s and s.gongfa_id == gongfa_id:
			out.append(s)
	return out

func gongfa_ordered() -> Array[GongfaDef]:
	var out: Array[GongfaDef] = []
	for r in tables.get("gongfa", []):
		out.append(gongfa[CsvUtil.s(r, "gongfa_id")])
	return out

# ---------- 常量 ----------
func const_f(key: String, def_value: float = 0.0) -> float:
	var v := str(constants.get(key, ""))
	return v.to_float() if v.is_valid_float() or v.is_valid_int() else def_value

func const_i(key: String, def_value: int = 0) -> int:
	return int(round(const_f(key, def_value)))

func const_b(key: String, def_value: bool = false) -> bool:
	if not constants.has(key):
		return def_value
	return str(constants[key]).strip_edges().to_lower() in ["true", "1", "yes"]

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

## 属性显示名：取 affixes 表里该属性词条的 name（攻击/生命/防御/暴击率/暴击伤害/反伤……）；
## 表里没有词条的属性（移动速度）用待收编文案 STAT_<属性>。
func stat_name(stat: String) -> String:
	for af: AffixDef in affixes_ordered:
		if af.stat == stat:
			return af.name
	return UiText.t("STAT_" + stat.to_upper())

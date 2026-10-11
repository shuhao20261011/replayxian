extends Node
## Autoload: 角色成长（境界、货币、已学技能、技能栏、自动设置、装备、关卡进度）。
## 战斗中的瞬时状态（生命、冷却、护盾）放在战斗场景；这里只放跨场景的成长数据。
## 存档（JSON / user://）属于开发阶段6，本阶段只在内存中保存；to_dict()/from_dict() 已预留结构。

signal currencies_changed
signal skill_bar_changed
signal progress_changed
signal auto_battle_changed(enabled: bool)

var realm_id := ""
var lingshi := 0
var xiuwei := 0
var learned_skills := {}             # skill_id -> level
var active_slots: Array[String] = [] # 长度 = ACTIVE_SLOT_COUNT，"" 为空槽
var slot_auto: Array[bool] = []
var passive_skill := ""
var equipped := {}                   # slot_id -> {base_id, quality_id}
var cleared_levels := {}             # level_id -> true
var auto_battle := true
## v3 自动挂机失败回退：level_id -> true（不稳定）；level_id -> 连续自动失败次数
var unstable_levels := {}
var auto_fail_counts := {}
## 引导进度：step_id -> {shown, done}
var tutorial := {}
## 测试/调试用属性倍率（不进存档）
var debug_atk_mult := 1.0
var debug_hp_mult := 1.0

func _ready() -> void:
	reset_new_game()

func slot_count() -> int:
	return GameData.const_i("ACTIVE_SLOT_COUNT", 4)

## 新开局。阶段3（功法/技能书/学习）完成前，开发占位：直接视为已学会3本新手基础技能并装配到1-3格。
func reset_new_game() -> void:
	realm_id = GameData.realms_ordered[0].id if not GameData.realms_ordered.is_empty() else ""
	lingshi = 0
	xiuwei = 0
	learned_skills.clear()
	passive_skill = ""
	cleared_levels.clear()
	unstable_levels.clear()
	auto_fail_counts.clear()
	tutorial.clear()
	auto_battle = true
	debug_atk_mult = 1.0
	debug_hp_mult = 1.0
	active_slots.clear(); slot_auto.clear()
	for i in slot_count():
		active_slots.append("")
		slot_auto.append(true)
	var basics := GameData.basic_skill_ids()
	for i in basics.size():
		learned_skills[basics[i]] = 1
		if i < slot_count():
			equip_skill(i, basics[i])
	equipped.clear()
	for r in GameData.tables.get("start_kit", []):
		if CsvUtil.s(r, "entry_type") == "equipment":
			var base := GameData.equip_bases.get(CsvUtil.s(r, "ref_id")) as EquipBaseDef
			if base != null:
				equipped[base.slot_id] = {"base_id": base.id, "quality_id": CsvUtil.s(r, "quality_id", "Q_WHITE")}
	currencies_changed.emit(); skill_bar_changed.emit(); progress_changed.emit()

# ---------- 技能栏 ----------
func skill_level(skill_id: String) -> int:
	return int(learned_skills.get(skill_id, 0))

func learn_skill_debug(skill_id: String, level: int = 1) -> bool:
	if GameData.get_skill(skill_id) == null:
		return false
	var old := skill_level(skill_id)
	learned_skills[skill_id] = clampi(level, 1, GameData.const_i("SKILL_MAX_LEVEL", 10))
	if old > 0 and learned_skills[skill_id] > old:
		clear_unstable_marks("skill_level_up")
	return true

## 装配主动技能：必须已学、必须是主动技能、不允许同一技能占两格（允许跨功法混搭）
func equip_skill(slot: int, skill_id: String) -> bool:
	if slot < 0 or slot >= active_slots.size():
		return false
	var s := GameData.get_skill(skill_id)
	if s == null or not s.is_active() or not learned_skills.has(skill_id):
		return false
	for i in active_slots.size():
		if i != slot and active_slots[i] == skill_id:
			return false
	active_slots[slot] = skill_id
	slot_auto[slot] = s.default_auto
	skill_bar_changed.emit()
	clear_unstable_marks("loadout_change")
	return true

func unequip_skill(slot: int) -> void:
	if slot >= 0 and slot < active_slots.size():
		active_slots[slot] = ""
		skill_bar_changed.emit()
		clear_unstable_marks("loadout_change")

func equip_passive(skill_id: String) -> bool:
	var s := GameData.get_skill(skill_id)
	if s == null or s.is_active() or not learned_skills.has(skill_id):
		return false
	passive_skill = skill_id
	skill_bar_changed.emit()
	clear_unstable_marks("loadout_change")
	return true

func set_slot_auto(slot: int, enabled: bool) -> void:
	if slot >= 0 and slot < slot_auto.size():
		slot_auto[slot] = enabled
		skill_bar_changed.emit()

func set_auto_battle(enabled: bool) -> void:
	if auto_battle == enabled:
		return
	auto_battle = enabled
	auto_battle_changed.emit(enabled)

# ---------- 属性 ----------
## 返回战斗属性：境界 + 装备底子×品质倍率 + 被动技能。词条/橙装特效在阶段4接入。
func combat_stats() -> Dictionary:
	var rl := GameData.get_realm(realm_id)
	var st := {
		"max_hp": rl.hp if rl else 500.0, "atk": rl.atk if rl else 20.0, "def": rl.def if rl else 10.0,
		"crit_rate": rl.crit_rate if rl else GameData.const_f("PLAYER_BASE_CRIT_RATE", 0.05),
		"crit_dmg": rl.crit_dmg if rl else GameData.const_f("PLAYER_BASE_CRIT_DMG", 1.5),
		"move_speed": GameData.const_f("PLAYER_MOVE_SPEED", 220.0),
		"reflect": 0.0, "extra_sword_chance": 0.0, "thunder_dmg_pct": 0.0, "thunder_cdr": 0.0, "cdr": 0.0,
	}
	var hp_pct := 0.0
	for slot_id in equipped:
		var e: Dictionary = equipped[slot_id]
		var base := GameData.equip_bases.get(e.get("base_id", "")) as EquipBaseDef
		var q := GameData.qualities.get(e.get("quality_id", "")) as QualityDef
		if base == null:
			continue
		var m := q.base_mult if q else 1.0
		st.atk += base.atk * m
		st.max_hp += base.hp * m
		st.def += base.def * m
		st.crit_rate += base.crit_rate
		st.move_speed += base.move_speed
	if passive_skill != "":
		var ps := GameData.get_skill(passive_skill)
		if ps:
			var lv := ps.level_def(maxi(skill_level(passive_skill), 1))
			for pair in [[ps.effect_type, lv.effect_value], [ps.effect2_type, lv.effect2_value]]:
				match pair[0]:
					"crit_rate_add": st.crit_rate += pair[1]
					"hp_pct": hp_pct += pair[1]
					"reflect_add": st.reflect += pair[1]
					"extra_sword_chance": st.extra_sword_chance += pair[1]
					"thunder_dmg_pct": st.thunder_dmg_pct += pair[1]
					"thunder_cdr": st.thunder_cdr += pair[1]
	st.max_hp = st.max_hp * (1.0 + hp_pct) * debug_hp_mult
	st.atk *= debug_atk_mult
	st.crit_rate = minf(st.crit_rate, GameData.const_f("CRIT_RATE_CAP", 0.75))
	return st

# ---------- 货币与进度 ----------
func add_rewards(ls: int, xw: int) -> void:
	lingshi += ls
	xiuwei += xw
	currencies_changed.emit()

func is_cleared(level_id: String) -> bool:
	return cleared_levels.has(level_id)

## 返回 true 表示首次通关
func mark_cleared(level_id: String) -> bool:
	if cleared_levels.has(level_id):
		return false
	cleared_levels[level_id] = true
	progress_changed.emit()
	return true

## 最近已通关关卡 = 已通关中全局序号最大者；没有则返回 null
func last_cleared_level() -> LevelDef:
	var best: LevelDef = null
	for l in GameData.levels_ordered:
		if cleared_levels.has(l.id):
			best = l
	return best

func realm_order() -> int:
	var rl := GameData.get_realm(realm_id)
	return rl.order if rl else 1

func can_challenge(level_id: String) -> bool:
	var l := GameData.get_level(level_id)
	if l == null:
		return false
	if l.unlock_level_id != "" and not is_cleared(l.unlock_level_id):
		return false
	if l.unlock_realm_id != "":
		var need := GameData.get_realm(l.unlock_realm_id)
		if need and realm_order() < need.order:
			return false
	return true

## 下一个可挑战的未通关关卡（没有则 null）
func next_challenge_level() -> LevelDef:
	for l in GameData.levels_ordered:
		if not is_cleared(l.id) and can_challenge(l.id):
			return l
	return null

# ---------- v3 自动挂机失败回退（design/README.md 第4节） ----------
func reset_on_reasons() -> PackedStringArray:
	return CsvUtil.list(GameData.const_s("AUTO_FAIL_RETREAT_RESET_ON", "loadout_change|skill_level_up|realm_up|manual_clear"))

## 换技能栏/被动/装备、技能升级、突破时调用；reason 需在 AUTO_FAIL_RETREAT_RESET_ON 中
func clear_unstable_marks(reason: String) -> void:
	if unstable_levels.is_empty() and auto_fail_counts.is_empty():
		return
	if not reset_on_reasons().has(reason):
		return
	unstable_levels.clear()
	auto_fail_counts.clear()
	progress_changed.emit()

## 装备换装/重铸（阶段4）调用此入口
func notify_equipment_changed() -> void:
	clear_unstable_marks("loadout_change")

## 境界突破（阶段5）调用此入口
func set_realm(id: String) -> void:
	var old := realm_order()
	realm_id = id
	if realm_order() > old:
		clear_unstable_marks("realm_up")
	progress_changed.emit()

func is_unstable(level_id: String) -> bool:
	return unstable_levels.has(level_id)

## 记录一次自动模式失败；返回 true 表示本次达到阈值、该关被标记为不稳定
func record_auto_failure(level_id: String) -> bool:
	auto_fail_counts[level_id] = int(auto_fail_counts.get(level_id, 0)) + 1
	if int(auto_fail_counts[level_id]) >= GameData.const_i("AUTO_FAIL_RETREAT_COUNT", 1):
		unstable_levels[level_id] = true
		progress_changed.emit()
		return true
	return false

## 通关一次：计数清零；玩家手动发起的挑战成功（manual_clear）清除该关标记
func record_level_success(level_id: String, manual_challenge: bool) -> void:
	auto_fail_counts.erase(level_id)
	if manual_challenge and unstable_levels.has(level_id) and reset_on_reasons().has("manual_clear"):
		unstable_levels.erase(level_id)
		progress_changed.emit()

## 回退目标：已通关且未被标记的最高关卡；没有则 null（调用方兜底刷第一关普通怪）
func auto_retreat_level() -> LevelDef:
	var best: LevelDef = null
	for l in GameData.levels_ordered:
		if cleared_levels.has(l.id) and not unstable_levels.has(l.id):
			best = l
	return best

func tutorial_state(step_id: String) -> Dictionary:
	return (tutorial.get(step_id, {"shown": 0, "done": false}) as Dictionary).duplicate()

func set_tutorial_state(step_id: String, st: Dictionary) -> void:
	tutorial[step_id] = st

## 存档结构（阶段6写入 user:// JSON；v3 标记/计数/引导进度已包含）
func to_dict() -> Dictionary:
	return {
		"realm_id": realm_id, "lingshi": lingshi, "xiuwei": xiuwei, "learned_skills": learned_skills.duplicate(),
		"active_slots": active_slots.duplicate(), "slot_auto": slot_auto.duplicate(), "passive_skill": passive_skill,
		"equipped": equipped.duplicate(true), "cleared_levels": cleared_levels.keys(), "auto_battle": auto_battle,
		"unstable_levels": unstable_levels.keys(), "auto_fail_counts": auto_fail_counts.duplicate(),
		"tutorial": tutorial.duplicate(true),
	}

func from_dict(d: Dictionary) -> void:
	realm_id = str(d.get("realm_id", realm_id))
	lingshi = int(d.get("lingshi", 0)); xiuwei = int(d.get("xiuwei", 0))
	learned_skills = (d.get("learned_skills", {}) as Dictionary).duplicate()
	active_slots.assign(d.get("active_slots", active_slots))
	slot_auto.assign(d.get("slot_auto", slot_auto))
	passive_skill = str(d.get("passive_skill", ""))
	equipped = (d.get("equipped", {}) as Dictionary).duplicate(true)
	cleared_levels.clear()
	for id in d.get("cleared_levels", []):
		cleared_levels[str(id)] = true
	auto_battle = bool(d.get("auto_battle", true))
	unstable_levels.clear()
	for id in d.get("unstable_levels", []):
		unstable_levels[str(id)] = true
	auto_fail_counts = (d.get("auto_fail_counts", {}) as Dictionary).duplicate()
	tutorial = (d.get("tutorial", {}) as Dictionary).duplicate(true)
	currencies_changed.emit(); skill_bar_changed.emit(); progress_changed.emit()

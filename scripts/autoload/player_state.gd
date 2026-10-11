extends Node
## Autoload: 角色成长（境界、货币、已学技能、技能栏、自动设置、装备、关卡进度）。
## 战斗中的瞬时状态（生命、冷却、护盾）放在战斗场景；这里只放跨场景的成长数据。
## 存档（JSON / user://）属于开发阶段6，本阶段只在内存中保存；to_dict()/from_dict() 已预留结构。

signal currencies_changed
signal skill_bar_changed
signal progress_changed
signal auto_battle_changed(enabled: bool)
signal inventory_changed
signal loot_notice(text: String)

var realm_id := ""
var lingshi := 0
var xiuwei := 0
var learned_skills := {}             # skill_id -> level
var active_slots: Array[String] = [] # 长度 = ACTIVE_SLOT_COUNT，"" 为空槽
var slot_auto: Array[bool] = []
var passive_skill := ""
var equipped := {}                   # slot_id -> GearItem
var bag: Array[GearItem] = []        # 装备背包（容量 BAG_EQUIP_CAPACITY）
var books := {}                      # book_id -> 数量（按种类堆叠，不占装备容量）
var items := {}                      # MAT_* -> 数量（炼器材料、悟道残页、突破材料）
var auto_decompose := {}             # quality_id -> bool（默认全关；橙装永不自动分解）
var pending_orange_choices: Array = []   # 每组为可选核心橙装 base_id 数组（终关首通三选一）
var next_uid := 1
var rng := RandomNumberGenerator.new()
var cleared_levels := {}             # level_id -> true
var auto_battle := true
var telegraph_alt := false   # 设置：统一预警白（所有地图首领预警都用 TELEGRAPH_ALT_COLOR）
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
	telegraph_alt = false
	debug_atk_mult = 1.0
	debug_hp_mult = 1.0
	active_slots.clear(); slot_auto.clear()
	for i in slot_count():
		active_slots.append("")
		slot_auto.append(true)
	books.clear(); items.clear(); bag.clear(); equipped.clear(); auto_decompose.clear()
	pending_orange_choices.clear()
	next_uid = 1
	rng.randomize()
	# 开局装备（start_kit.equipment）
	for r in GameData.tables.get("start_kit", []):
		if CsvUtil.s(r, "entry_type") == "equipment":
			var g := GearSystem.make_item(CsvUtil.s(r, "ref_id"), CsvUtil.s(r, "quality_id", "Q_WHITE"), rng)
			if g.base():
				g.uid = _new_uid()
				equipped[g.slot_id()] = g
	# 新手赠书（tutorial_steps 中 reward_type=book 的步骤）。
	# 主线引导（阶段7）接入前的开发捷径：直接学习并装配到第1-3格。
	for r in GameData.tables.get("tutorial_steps", []):
		if CsvUtil.s(r, "reward_type") == "book":
			for bid in CsvUtil.list(CsvUtil.s(r, "reward_ref_ids")):
				add_book(bid, maxi(CsvUtil.i(r, "reward_count", 1), 1))
	var n := 0
	for bid in books.keys():
		if learn_book(bid) == "ok":
			var bk := GameData.get_book(bid)
			if n < slot_count() and GameData.get_skill(bk.skill_id).is_active():
				equip_skill(n, bk.skill_id)
				n += 1
	currencies_changed.emit(); skill_bar_changed.emit(); progress_changed.emit(); inventory_changed.emit()

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

## 面板用：装配到指定格；若该技能已在其他格，则两格互换（不违反“同一技能不占两格”）
func place_skill(slot: int, skill_id: String) -> bool:
	var j := active_slots.find(skill_id)
	if j == slot:
		return true
	if j >= 0:
		var s := GameData.get_skill(skill_id)
		if s == null:
			return false
		var other := active_slots[slot]
		var other_auto := slot_auto[slot]
		active_slots[j] = other
		slot_auto[j] = other_auto
		active_slots[slot] = skill_id
		slot_auto[slot] = s.default_auto
		skill_bar_changed.emit()
		clear_unstable_marks("loadout_change")
		return true
	return equip_skill(slot, skill_id)

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
## 战斗属性：境界 + 装备（底子×品质 + 词条） + 被动技能 + 核心橙装特效。
## 攻击 = (境界攻击 + Σ攻击) × (1 + Σ攻击%)；生命同理（再乘被动生命%）。
func combat_stats() -> Dictionary:
	var rl := GameData.get_realm(realm_id)
	var st := {
		"max_hp": 0.0, "atk": 0.0, "def": rl.def if rl else 10.0,
		"crit_rate": rl.crit_rate if rl else GameData.const_f("PLAYER_BASE_CRIT_RATE", 0.05),
		"crit_dmg": rl.crit_dmg if rl else GameData.const_f("PLAYER_BASE_CRIT_DMG", 1.5),
		"move_speed": GameData.const_f("PLAYER_MOVE_SPEED", 220.0),
		"reflect": 0.0, "extra_sword_chance": 0.0, "thunder_dmg_pct": 0.0, "thunder_cdr": 0.0, "cdr": 0.0,
		"sword_dmg_pct": 0.0, "atk_speed": 0.0, "chain_count": 0.0, "shield_pct": 0.0, "lingshi_gain_pct": 0.0,
		"orange": [],
	}
	var atk := rl.atk if rl else 20.0
	var hp := rl.hp if rl else 500.0
	var atk_pct := 0.0
	var hp_pct := 0.0
	for slot_id in equipped:
		var g: GearItem = equipped[slot_id]
		for k in g.stat_totals().keys():
			var v := float(g.stat_totals()[k])
			match k:
				"atk": atk += v
				"hp": hp += v
				"atk_pct": atk_pct += v
				"hp_pct": hp_pct += v
				"reflect_pct": st.reflect += v
				_:
					st[k] = float(st.get(k, 0.0)) + v
		var oe := g.orange_effect()
		if oe:
			st.orange.append(oe.id)
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
	st.atk = atk * (1.0 + atk_pct) * debug_atk_mult
	st.max_hp = hp * (1.0 + hp_pct) * debug_hp_mult
	st.crit_rate = minf(st.crit_rate, GameData.const_f("CRIT_RATE_CAP", 0.75))
	return st

func has_orange(effect_id: String) -> bool:
	for g: GearItem in equipped.values():
		var oe := g.orange_effect()
		if oe and oe.id == effect_id:
			return true
	return false

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

# ---------- 物品 ----------
func _new_uid() -> int:
	next_uid += 1
	return next_uid - 1

func item_count(id: String) -> int:
	return int(items.get(id, 0))

func add_item(id: String, n: int) -> void:
	items[id] = item_count(id) + n
	inventory_changed.emit()

func book_count(book_id: String) -> int:
	return int(books.get(book_id, 0))

func add_book(book_id: String, n: int = 1) -> void:
	if GameData.get_book(book_id) == null:
		return
	books[book_id] = book_count(book_id) + n
	inventory_changed.emit()

func spend_lingshi(n: int) -> bool:
	if lingshi < n:
		return false
	lingshi -= n
	currencies_changed.emit()
	return true

# ---------- 阶段3：功法 / 技能书 / 学习 / 升级 / 残页 ----------
const PAGE_ID := "MAT_PAGE"

## 功法“已入门” = 学会了该功法任意一个技能
func gongfa_entered(gongfa_id: String) -> bool:
	for sid in learned_skills:
		var s := GameData.get_skill(sid)
		if s and s.gongfa_id == gongfa_id:
			return true
	return false

## 学习：校验持有数量与学习状态；成功消耗1本书，技能永久掌握（1级）。已学技能不扣书。
func learn_book(book_id: String) -> String:
	var bk := GameData.get_book(book_id)
	if bk == null:
		return "invalid"
	if learned_skills.has(bk.skill_id):
		return "already_learned"
	if book_count(book_id) <= 0:
		return "no_book"
	books[book_id] = book_count(book_id) - 1
	learned_skills[bk.skill_id] = 1
	inventory_changed.emit(); skill_bar_changed.emit()
	return "ok"

## 升级：消耗 skill_levels.upgrade_cost_lingshi（当前级→下一级），上限 SKILL_MAX_LEVEL
func upgrade_cost(skill_id: String) -> int:
	var s := GameData.get_skill(skill_id)
	var lv := skill_level(skill_id)
	if s == null or lv <= 0 or lv >= GameData.const_i("SKILL_MAX_LEVEL", 10):
		return -1
	return s.level_def(lv).upgrade_cost_lingshi

func upgrade_skill(skill_id: String) -> String:
	if not learned_skills.has(skill_id):
		return "not_learned"
	var cost := upgrade_cost(skill_id)
	if cost < 0:
		return "max_level"
	if not spend_lingshi(cost):
		return "no_lingshi"
	learned_skills[skill_id] = skill_level(skill_id) + 1
	skill_bar_changed.emit()
	clear_unstable_marks("skill_level_up")
	return "ok"

## 分解重复技能书 → 悟道残页（仅限已学技能的书；不自动分解）
func decompose_book(book_id: String, n: int = 1) -> String:
	var bk := GameData.get_book(book_id)
	if bk == null:
		return "invalid"
	if not learned_skills.has(bk.skill_id):
		return "not_learned"
	if n <= 0 or book_count(book_id) < n:
		return "no_book"
	books[book_id] = book_count(book_id) - n
	add_item(PAGE_ID, bk.decompose_pages * n)
	return "ok"

## 地图（区域）是否已解锁：当前境界 ≥ 地图所需境界
func map_unlocked(map_id: String) -> bool:
	var m := GameData.get_map(map_id)
	if m == null:
		return false
	var need := GameData.get_realm(m.realm_required)
	return need == null or realm_order() >= need.order

## 残页兑换：exchange_pages 张兑换1本已解锁区域内的指定技能书
func exchange_book(book_id: String) -> String:
	var bk := GameData.get_book(book_id)
	if bk == null:
		return "invalid"
	if not map_unlocked(bk.region_map_id):
		return "locked_region"
	var cost := bk.exchange_pages if bk.exchange_pages > 0 else GameData.const_i("PAGE_EXCHANGE_COST", 10)
	if item_count(PAGE_ID) < cost:
		return "no_pages"
	items[PAGE_ID] = item_count(PAGE_ID) - cost
	add_book(book_id, 1)
	return "ok"

# ---------- 阶段4：装备 ----------
func bag_capacity() -> int:
	return GameData.const_i("BAG_EQUIP_CAPACITY", 100)

func find_gear(uid: int) -> GearItem:
	for g in bag:
		if g.uid == uid:
			return g
	for g: GearItem in equipped.values():
		if g.uid == uid:
			return g
	return null

func is_equipped(g: GearItem) -> bool:
	return g != null and equipped.get(g.slot_id()) == g

## 入包：按品质自动分解（默认关闭，橙装永不）；背包满则溢出转炼器材料。返回 ok / auto_decomposed / overflow
func add_gear(g: GearItem) -> String:
	if g == null:
		return "invalid"
	if g.uid == 0:
		g.uid = _new_uid()
	var q := g.quality()
	var protected := q != null and not q.auto_decompose_allowed
	if not protected and bool(auto_decompose.get(g.quality_id, false)):
		add_item("MAT_REFINE", GearSystem.decompose_value(g))
		return "auto_decomposed"
	if bag.size() >= bag_capacity() and not protected:
		var v := GearSystem.decompose_value(g)
		add_item("MAT_REFINE", v)
		loot_notice.emit("背包已满：%s 转为炼器材料×%d" % [g.display_name(), v])
		return "overflow"
	bag.append(g)
	inventory_changed.emit()
	return "ok"

func set_auto_decompose(quality_id: String, on: bool) -> bool:
	var q := GameData.get_quality(quality_id)
	if q == null or (on and not q.auto_decompose_allowed):
		return false
	auto_decompose[quality_id] = on
	inventory_changed.emit()
	return true

## 换装：背包中的装备换到对应槽位，旧装备回背包
func equip_gear(uid: int) -> String:
	var g: GearItem = null
	for x in bag:
		if x.uid == uid:
			g = x
	if g == null:
		return "not_in_bag"
	bag.erase(g)
	var old: GearItem = equipped.get(g.slot_id())
	equipped[g.slot_id()] = g
	if old:
		bag.append(old)
	inventory_changed.emit(); progress_changed.emit()
	notify_equipment_changed()
	return "ok"

## 手动分解背包内装备
func decompose_gear(uid: int) -> String:
	for g in bag:
		if g.uid == uid:
			bag.erase(g)
			add_item("MAT_REFINE", GearSystem.decompose_value(g))
			return "ok"
	return "not_in_bag"

## 批量分解背包内某品质及以下（不含受保护的橙装），返回分解件数
func decompose_up_to(quality_order: int) -> int:
	var n := 0
	for g: GearItem in bag.duplicate():
		var q := g.quality()
		if q and q.order <= quality_order and q.auto_decompose_allowed:
			decompose_gear(g.uid)
			n += 1
	return n

## 重铸：选1条词条，消耗炼器材料+灵石，在“该槽允许、品质达标、且不与其余词条重复”的池中重抽种类+数值。核心橙装特效不可重铸。
func reroll_affix(uid: int, index: int) -> String:
	var g := find_gear(uid)
	if g == null:
		return "invalid"
	if index < 0 or index >= g.affixes.size():
		return "invalid_index"
	var cost := GearSystem.reroll_cost(g)
	if cost.is_empty():
		return "cannot_reroll"
	if item_count("MAT_REFINE") < int(cost.refine):
		return "no_refine"
	if lingshi < int(cost.lingshi):
		return "no_lingshi"
	var others: Array = []
	for i in g.affixes.size():
		if i != index:
			others.append(g.affixes[i].affix_id)
	var tmp := GearItem.new()
	tmp.base_id = g.base_id; tmp.quality_id = g.quality_id
	var a := GearSystem.roll_affix(tmp, rng, others)
	if a.is_empty():
		return "no_pool"
	items["MAT_REFINE"] = item_count("MAT_REFINE") - int(cost.refine)
	spend_lingshi(int(cost.lingshi))
	g.affixes[index] = a
	inventory_changed.emit()
	if is_equipped(g):
		notify_equipment_changed()
	return "ok"

## 与当前同槽装备比较基础属性（推荐换装只比较基础属性，流派特效由玩家判断）
func compare_gear(g: GearItem) -> Dictionary:
	var cur: GearItem = equipped.get(g.slot_id())
	var a := g.base_stats()
	var b := cur.base_stats() if cur else {}
	var d := {}
	for k in ["atk", "hp", "def", "crit_rate", "move_speed"]:
		d[k] = float(a.get(k, 0.0)) - float(b.get(k, 0.0))
	d["recommended"] = cur != g and (d.atk * 10.0 + d.hp + d.def * 5.0 + d.crit_rate * 1000.0) > 0.0
	return d

## 终关首通三选一
func add_orange_choice(base_ids: Array) -> void:
	pending_orange_choices.append(base_ids.duplicate())
	inventory_changed.emit()

func choose_orange(group_index: int, base_id: String) -> String:
	if group_index < 0 or group_index >= pending_orange_choices.size():
		return "invalid"
	var group: Array = pending_orange_choices[group_index]
	if not group.has(base_id):
		return "invalid"
	var top: String = GameData.qualities_ordered().back().id
	var g := GearSystem.make_item(base_id, top, rng)
	pending_orange_choices.remove_at(group_index)
	add_gear(g)
	return "ok"

## 调试/截图：填充一套演示用养成数据（固定种子，可复现）
func debug_fill_demo(seed_value: int = 7) -> void:
	rng.seed = seed_value
	add_rewards(12000, 3000)
	add_item("MAT_REFINE", 60)
	add_item(PAGE_ID, 12)
	for bid in ["BK_SWORD_COMBO", "BK_SWORD_PASSIVE", "BK_THUNDER_STRIKE", "BK_THUNDER_NINE", "BK_GANG_GUARD"]:
		add_book(bid, 1)
	learn_book("BK_SWORD_COMBO"); learn_book("BK_SWORD_PASSIVE")
	equip_passive("SK_SWORD_PASSIVE")
	learned_skills["SK_SWORD_FLYING"] = 4
	for i in 14:
		var t := 1 + (i % 3)
		add_gear(GearSystem.generate(t, "QW_BOSS_T%d" % t, rng))
	var ws := GearSystem.normal_bases(1, "SLOT_WEAPON")
	if not ws.is_empty():
		add_gear(GearSystem.make_item(ws[0].id, "Q_PURPLE", rng))
	add_gear(GearSystem.make_item("EQB_CORE_SWORD", GameData.qualities_ordered().back().id, rng))
	var choices: Array = []
	for b in GearSystem.core_bases():
		choices.append(b.id)
	add_orange_choice(choices)

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
		"equipped": _equipped_dict(), "bag": bag.map(func(g: GearItem) -> Dictionary: return g.to_dict()),
		"books": books.duplicate(), "items": items.duplicate(), "auto_decompose": auto_decompose.duplicate(),
		"pending_orange_choices": pending_orange_choices.duplicate(true), "next_uid": next_uid,
		"cleared_levels": cleared_levels.keys(), "auto_battle": auto_battle,
		"unstable_levels": unstable_levels.keys(), "auto_fail_counts": auto_fail_counts.duplicate(),
		"tutorial": tutorial.duplicate(true), "telegraph_alt": telegraph_alt,
	}

func _equipped_dict() -> Dictionary:
	var out := {}
	for k in equipped:
		out[k] = (equipped[k] as GearItem).to_dict()
	return out

func from_dict(d: Dictionary) -> void:
	realm_id = str(d.get("realm_id", realm_id))
	lingshi = int(d.get("lingshi", 0)); xiuwei = int(d.get("xiuwei", 0))
	learned_skills.clear()
	var ld: Dictionary = d.get("learned_skills", {})
	for k in ld:
		learned_skills[str(k)] = int(ld[k])
	active_slots.assign(d.get("active_slots", active_slots))
	slot_auto.assign(d.get("slot_auto", slot_auto))
	passive_skill = str(d.get("passive_skill", ""))
	equipped.clear()
	var eq: Dictionary = d.get("equipped", {})
	for k in eq:
		equipped[str(k)] = GearItem.from_dict(eq[k])
	bag.clear()
	for gd in d.get("bag", []):
		bag.append(GearItem.from_dict(gd))
	books.clear(); items.clear()
	var bd: Dictionary = d.get("books", {})
	for k in bd:
		books[str(k)] = int(bd[k])
	var idd: Dictionary = d.get("items", {})
	for k in idd:
		items[str(k)] = int(idd[k])
	auto_decompose = (d.get("auto_decompose", {}) as Dictionary).duplicate()
	pending_orange_choices = (d.get("pending_orange_choices", []) as Array).duplicate(true)
	next_uid = int(d.get("next_uid", 1))
	cleared_levels.clear()
	for id in d.get("cleared_levels", []):
		cleared_levels[str(id)] = true
	auto_battle = bool(d.get("auto_battle", true))
	unstable_levels.clear()
	for id in d.get("unstable_levels", []):
		unstable_levels[str(id)] = true
	auto_fail_counts = (d.get("auto_fail_counts", {}) as Dictionary).duplicate()
	tutorial = (d.get("tutorial", {}) as Dictionary).duplicate(true)
	telegraph_alt = bool(d.get("telegraph_alt", false))
	currencies_changed.emit(); skill_bar_changed.emit(); progress_changed.emit(); inventory_changed.emit()

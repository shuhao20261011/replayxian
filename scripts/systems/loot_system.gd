class_name LootSystem
extends RefCounted
## 掉落与首通奖励（读 drop_tables / book_pools / first_clear_rewards / levels）。
## roll_* 只生成奖励清单（纯函数，可测）；apply() 把清单写入 PlayerState 并返回显示用条目。
## 奖励条目：{type: equipment|material|book|lingshi|xiuwei|orange_choice, id, count, item: GearItem, choices: Array}

## 击杀掉落：按关卡的 normal/boss 掉落表逐行判定 chance（per_kill）
static func roll_kill(level: LevelDef, is_boss: bool, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	if level == null:
		return out
	var table_id := level.boss_drop_table_id if is_boss else level.normal_drop_table_id
	for r in GameData.drop_tables.get(table_id, []):
		if CsvUtil.s(r, "roll", "per_kill") != "per_kill":
			continue
		if rng.randf() >= CsvUtil.f(r, "chance", 0.0):
			continue
		var n := rng.randi_range(CsvUtil.i(r, "count_min", 1), maxi(CsvUtil.i(r, "count_min", 1), CsvUtil.i(r, "count_max", 1)))
		var ref := CsvUtil.s(r, "ref_id")
		match CsvUtil.s(r, "entry_type"):
			"equipment":
				for i in n:
					var g := GearSystem.generate(GameData.tier_from_ref(ref), CsvUtil.s(r, "weight_set_id"), rng)
					if g:
						out.append({"type": "equipment", "item": g, "count": 1})
			"material":
				out.append({"type": "material", "id": ref, "count": n})
			"book_pool":
				for i in n:
					var bid := roll_book(ref, rng)
					if bid != "":
						out.append({"type": "book", "id": bid, "count": 1})
	return out

static func roll_book(pool_id: String, rng: RandomNumberGenerator) -> String:
	var pool: Array = GameData.book_pools.get(pool_id, [])
	var total := 0.0
	for e in pool:
		total += float(e.weight)
	if total <= 0.0:
		return ""
	var r := rng.randf() * total
	for e in pool:
		r -= float(e.weight)
		if r < 0.0:
			return e.book_id
	return pool.back().book_id

## 首通奖励。equipment 槽位随机；global_index=1 的关卡固定为武器（README 3.11）。
## 可选列 slot_id（若策划表以后加上）优先。orange_choice 同一 reward_id 内合并为一组三选一。
static func roll_first_clear(level: LevelDef, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	if level == null:
		return out
	var choices: Array = []
	for r in GameData.first_clear.get(level.first_clear_reward_id, []):
		var ref := CsvUtil.s(r, "ref_id")
		var n := maxi(CsvUtil.i(r, "count", 1), 1)
		match CsvUtil.s(r, "reward_type"):
			"lingshi":
				out.append({"type": "lingshi", "id": ref, "count": n})
			"xiuwei":
				out.append({"type": "xiuwei", "id": ref, "count": n})
			"material":
				out.append({"type": "material", "id": ref, "count": n})
			"book":
				out.append({"type": "book", "id": ref, "count": n})
			"equipment":
				var slot := CsvUtil.s(r, "slot_id")
				if slot == "" and level.global_index == 1:
					slot = GameData.const_s("FIRST_CLEAR_LV1_SLOT", "SLOT_WEAPON")
				for i in n:
					var g := GearSystem.generate(GameData.tier_from_ref(ref), CsvUtil.s(r, "weight_set_id"), rng, slot)
					if g:
						out.append({"type": "equipment", "item": g, "count": 1})
			"orange_choice":
				choices.append(ref)
	if not choices.is_empty():
		out.append({"type": "orange_choice", "choices": choices, "count": 1})
	return out

## 写入背包/货币；返回显示条目 [{text, color, beam, icon(物品 id), quality(品质序 1~5，0=无光柱)}]
static func apply(grants: Array, lingshi_gain_pct: float = 0.0) -> Array:
	var shown: Array = []
	for gr in grants:
		match gr.type:
			"lingshi":
				var v := int(round(int(gr.count) * (1.0 + lingshi_gain_pct)))
				PlayerState.add_rewards(v, 0)
				shown.append({"text": UiText.t("FLOAT_LINGSHI", {"value": v}), "color": Color(1, 0.86, 0.4), "beam": "", "icon": "CUR_LINGSHI", "quality": 0})
			"xiuwei":
				PlayerState.add_rewards(0, int(gr.count))
				shown.append({"text": UiText.t("FLOAT_XIUWEI", {"value": int(gr.count)}), "color": Color(0.6, 0.85, 1), "beam": "", "icon": "CUR_XIUWEI", "quality": 0})
			"material":
				PlayerState.add_item(gr.id, int(gr.count))
				shown.append({"text": UiText.t("LOOT_ITEM_COUNT", {"item_name": GameData.material_name(gr.id), "count": int(gr.count)}), "color": Color(0.8, 0.9, 0.8), "beam": "", "icon": str(gr.id), "quality": 0})
			"book":
				PlayerState.add_book(gr.id, int(gr.count))
				var bk := GameData.get_book(gr.id)
				shown.append({"text": (bk.name if bk else ""), "color": Color(0.75, 0.6, 1), "beam": "book", "icon": str(gr.id), "quality": 4})
			"equipment":
				var g: GearItem = gr.item
				var res := PlayerState.add_gear(g)
				var q := g.quality()
				var t := g.display_name()
				if res == "auto_decomposed":
					t = UiText.t("LOOT_AUTO_DECOMPOSED", {"gear_name": t, "item_name": GameData.material_name("MAT_REFINE")})
				elif res == "overflow":
					t = UiText.t("LOOT_BAG_FULL", {"gear_name": t, "item_name": GameData.material_name("MAT_REFINE"), "count": GearSystem.decompose_value(g)})
				shown.append({"text": t, "color": g.color(), "beam": q.beam if q else "", "icon": g.base_id, "quality": (q.order if q and q.beam != "none" else 0)})
			"orange_choice":
				PlayerState.add_orange_choice(gr.choices)
				shown.append({"text": UiText.t("LOOT_ORANGE_PENDING"), "color": GameData.qualities_ordered().back().color, "beam": "tall_gold", "icon": "", "quality": 5})
	return shown

class_name GearSystem
extends RefCounted
## 装备生成、词条抽取与重铸（全部读表：equip_bases / qualities / quality_weights / affixes / gear_tiers）。
## 规则（design/README 3.15）：
## - 品质按权重组抽取；抽到橙色时从核心橙装（is_core=true）中等概率选1件（只以橙色生成）。
## - 非橙：在该档非核心底子里随机（可指定槽位）。
## - 词条数 = qualities.affix_count；在“该槽允许、品质达标（min_quality）、同件不重复”的词条中按 weight 抽；
##   数值在该品质区间均匀随机：flat 取整（scale_by_tier 时 × gear_tiers.flat_mult），pct 保留3位小数，int 取整数。

static func roll_quality(weight_set_id: String, rng: RandomNumberGenerator) -> String:
	var w: Dictionary = GameData.quality_weights.get(weight_set_id, {})
	var total := 0.0
	for q in w:
		total += float(w[q])
	if total <= 0.0:
		return "Q_WHITE"
	var r := rng.randf() * total
	for q: QualityDef in GameData.qualities_ordered():
		r -= float(w.get(q.id, 0.0))
		if r < 0.0:
			return q.id
	return GameData.qualities_ordered().back().id

static func is_top_quality(quality_id: String) -> bool:
	var q := GameData.get_quality(quality_id)
	return q != null and not q.auto_decompose_allowed and q.order == GameData.qualities_ordered().back().order

static func core_bases() -> Array[EquipBaseDef]:
	var out: Array[EquipBaseDef] = []
	for b: EquipBaseDef in GameData.equip_bases.values():
		if b.is_core:
			out.append(b)
	out.sort_custom(func(a: EquipBaseDef, b: EquipBaseDef) -> bool: return a.id < b.id)
	return out

static func normal_bases(tier: int, slot_id: String = "") -> Array[EquipBaseDef]:
	var out: Array[EquipBaseDef] = []
	for b: EquipBaseDef in GameData.equip_bases.values():
		if not b.is_core and b.gear_tier == tier and (slot_id == "" or b.slot_id == slot_id):
			out.append(b)
	out.sort_custom(func(a: EquipBaseDef, b: EquipBaseDef) -> bool: return a.id < b.id)
	return out

## 按档位 + 品质权重组生成一件装备
static func generate(tier: int, weight_set_id: String, rng: RandomNumberGenerator, slot_id: String = "") -> GearItem:
	var q := roll_quality(weight_set_id, rng)
	if is_top_quality(q) and slot_id == "":
		var cores := core_bases()
		if not cores.is_empty():
			return make_item(cores[rng.randi_range(0, cores.size() - 1)].id, q, rng)
	if is_top_quality(q):
		q = GameData.qualities_ordered()[GameData.qualities_ordered().size() - 2].id   # 指定槽位时不出橙，降一档
	var bases := normal_bases(tier, slot_id)
	if bases.is_empty():
		bases = normal_bases(tier)
	if bases.is_empty():
		return null
	return make_item(bases[rng.randi_range(0, bases.size() - 1)].id, q, rng)

static func make_item(base_id: String, quality_id: String, rng: RandomNumberGenerator) -> GearItem:
	var g := GearItem.new()
	g.base_id = base_id
	g.quality_id = quality_id
	var q := GameData.get_quality(quality_id)
	var n := q.affix_count if q else 0
	for i in n:
		var a := roll_affix(g, rng, [])
		if a.is_empty():
			break
		g.affixes.append(a)
	return g

## 可抽词条池：槽位允许、品质达标、排除 exclude_ids
static func affix_pool(slot_id: String, quality_id: String, exclude_ids: Array) -> Array[AffixDef]:
	var q := GameData.get_quality(quality_id)
	var out: Array[AffixDef] = []
	for af in GameData.affixes_ordered:
		var mq := GameData.get_quality(af.min_quality)
		if not af.allowed_slots.has(slot_id):
			continue
		if q == null or (mq != null and mq.order > q.order):
			continue
		if exclude_ids.has(af.id):
			continue
		out.append(af)
	return out

## 抽一条词条（排除该件已有词条与 extra_exclude）
static func roll_affix(g: GearItem, rng: RandomNumberGenerator, extra_exclude: Array) -> Dictionary:
	var ex: Array = extra_exclude.duplicate()
	for a in g.affixes:
		ex.append(a.affix_id)
	var pool := affix_pool(g.slot_id(), g.quality_id, ex)
	if pool.is_empty():
		return {}
	var total := 0.0
	for af in pool:
		total += af.weight
	var r := rng.randf() * total
	var pick: AffixDef = pool.back()
	for af in pool:
		r -= af.weight
		if r < 0.0:
			pick = af
			break
	return {"affix_id": pick.id, "value": roll_value(pick, g.quality_id, g.tier(), rng)}

static func roll_value(af: AffixDef, quality_id: String, tier: int, rng: RandomNumberGenerator) -> float:
	var rg := af.range_for(quality_id)
	var t := GameData.get_tier(tier)
	match af.value_type:
		"int":
			return float(rng.randi_range(int(rg.x), int(rg.y)))
		"pct":
			return snappedf(rng.randf_range(rg.x, rg.y), 0.001)
		_:
			var v := rng.randf_range(rg.x, rg.y)
			if af.scale_by_tier and t:
				v *= t.flat_mult
			return float(roundi(v))

## 分解得炼器材料 = decompose_refine × gear_tiers.decompose_mult
static func decompose_value(g: GearItem) -> int:
	var q := g.quality()
	var t := GameData.get_tier(g.tier())
	return int(round((q.decompose_refine if q else 1) * (t.decompose_mult if t else 1.0)))

## 重铸1条词条的消耗 {refine, lingshi}；不可重铸返回空
static func reroll_cost(g: GearItem) -> Dictionary:
	var q := g.quality()
	if q == null or not q.can_reroll or g.affixes.is_empty():
		return {}
	var t := GameData.get_tier(g.tier())
	return {"refine": q.reroll_refine, "lingshi": int(round(q.reroll_lingshi * (t.reroll_lingshi_mult if t else 1.0)))}

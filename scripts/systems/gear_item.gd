class_name GearItem
extends RefCounted
## 一件装备实例：底子 + 品质 + 随机词条。基础属性 = 底子白装值 × 品质 base_mult；
## 词条数值在生成时已按品质区间与档位倍率算好。

var uid := 0
var base_id := ""
var quality_id := "Q_WHITE"
var affixes: Array[Dictionary] = []   # {affix_id, value}

func base() -> EquipBaseDef:
	return GameData.get_base(base_id)

func quality() -> QualityDef:
	return GameData.get_quality(quality_id)

func slot_id() -> String:
	var b := base()
	return b.slot_id if b else ""

func tier() -> int:
	var b := base()
	return b.gear_tier if b else 1

func display_name() -> String:
	var b := base()
	var q := quality()
	return "【%s】%s" % [q.name if q else "?", b.name if b else base_id]

func color() -> Color:
	var q := quality()
	return q.color if q else Color.WHITE

func orange_effect() -> OrangeEffectDef:
	var b := base()
	return GameData.orange_effects.get(b.orange_effect_id) as OrangeEffectDef if b and b.orange_effect_id != "" else null

## 底子基础属性（已乘品质倍率）
func base_stats() -> Dictionary:
	var b := base()
	var q := quality()
	var m := q.base_mult if q else 1.0
	if b == null:
		return {}
	return {"atk": b.atk * m, "hp": b.hp * m, "def": b.def * m, "crit_rate": b.crit_rate, "move_speed": b.move_speed}

## 底子 + 词条，按 stat 键累加
func stat_totals() -> Dictionary:
	var st := base_stats()
	for a in affixes:
		var af := GameData.affixes.get(a.affix_id) as AffixDef
		if af:
			st[af.stat] = float(st.get(af.stat, 0.0)) + float(a.value)
	return st

func to_dict() -> Dictionary:
	return {"uid": uid, "base_id": base_id, "quality_id": quality_id, "affixes": affixes.duplicate(true)}

static func from_dict(d: Dictionary) -> GearItem:
	var g := GearItem.new()
	g.uid = int(d.get("uid", 0))
	g.base_id = str(d.get("base_id", ""))
	g.quality_id = str(d.get("quality_id", "Q_WHITE"))
	for a in d.get("affixes", []):
		g.affixes.append({"affix_id": str(a.affix_id), "value": float(a.value)})
	return g

## 词条显示文本
static func affix_text(a: Dictionary) -> String:
	var af := GameData.affixes.get(a.affix_id) as AffixDef
	if af == null:
		return str(a.affix_id)
	match af.value_type:
		"pct":
			return "%s +%.1f%%" % [af.name, float(a.value) * 100.0]
		_:
			return "%s +%d" % [af.name, int(a.value)]

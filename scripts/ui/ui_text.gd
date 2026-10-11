class_name UiText
extends RefCounted
## v5 文案：上屏文字一律来自 design/data/ui_texts.csv（key → text，按 placeholders 填值）。
## 表里还没有的前端文字放在 data/ui_texts_local.csv（同列结构，待策划收编；主表同名 key 优先）。
## 模板渲染与 design/tools/common.py 的 render_tpl() 一致：
##   {f} / {f:num} 数值保留至多2位小数并去掉末尾0；{f:pct} ×100 后至多1位小数加 %；{f:int} 四舍五入取整（与 Python round 一致：恰好一半时取偶）。
##   非数值（关卡名等字符串）原样代入；字段缺失时保留占位符原文并告警。

const LOCAL_PATH := "res://data/ui_texts_local.csv"

static var _rows: Dictionary = {}
static var _src: Variant = null
static var _re: RegEx

static func _ensure() -> void:
	var main: Variant = GameData.tables.get("ui_texts", [])
	if _src != null and is_same(_src, main):
		return
	_src = main
	_rows = {}
	for r in CsvUtil.load_rows(LOCAL_PATH) if FileAccess.file_exists(LOCAL_PATH) else []:
		_rows[CsvUtil.s(r, "key")] = r
	for r in main:
		_rows[CsvUtil.s(r, "key")] = r

static func has(key: String) -> bool:
	_ensure()
	return _rows.has(key)

## 按 key 取文案并渲染占位符
static func t(key: String, params: Dictionary = {}) -> String:
	_ensure()
	if not _rows.has(key):
		push_warning("UiText: 缺少文案 key %s" % key)
		return key
	return render(CsvUtil.s(_rows[key], "text"), params)

static func row(key: String) -> Dictionary:
	_ensure()
	return _rows.get(key, {})

static func render(tpl: String, data: Dictionary) -> String:
	if _re == null:
		_re = RegEx.new()
		_re.compile("\\{([a-z_][a-z0-9_]*)(?::(pct|num|int))?\\}")
	var out := ""
	var pos := 0
	for m in _re.search_all(tpl):
		out += tpl.substr(pos, m.get_start() - pos)
		var field := m.get_string(1)
		if data.has(field):
			out += fmt(data[field], m.get_string(2))
		else:
			push_warning("UiText: 模板缺少字段 %s：%s" % [field, tpl])
			out += m.get_string()
		pos = m.get_end()
	return out + tpl.substr(pos)

static func _is_number(v: Variant) -> bool:
	if v is int or v is float:
		return true
	if v is String or v is StringName:
		return String(v).strip_edges().is_valid_float()
	return false

static func fmt(v: Variant, f: String = "") -> String:
	if not _is_number(v):
		return str(v)
	var x := float(v)
	match f:
		"pct":
			return _round_g(x * 100.0, 1) + "%"   # Python: round(v*100, 1)，整数去小数，否则 "%g"
		"int":
			return _clean("%.0f" % x)               # Python: int(round(v))
	return _round_g(x, 2)                           # Python fmt_num: round(v, 2)，整数去小数，否则 "%g"

static func fmt_num(x: float) -> String:
	return _round_g(x, 2)

static func _round_g(x: float, n: int) -> String:
	var r := float(("%." + str(n) + "f") % x)
	if r == floorf(r) and absf(r) < 1e15:
		return _clean("%.0f" % r)
	return _g(r)

## Python "%g"（默认6位有效数字）：指数 < -4 或 ≥ 6 用科学计数法，否则定点；均去掉末尾0
static func _g(x: float) -> String:
	if x == 0.0:
		return "0"
	var e := _exp10(absf(x))
	if e < -4 or e >= 6:
		var m := x / pow(10.0, e)
		var ms := _fixed_trim(m, 5)
		if absf(float(ms)) >= 10.0:   # 尾数进位（如 9.999995 → 10）
			e += 1
			ms = _fixed_trim(x / pow(10.0, e), 5)
		return "%se%s%02d" % [ms, "-" if e < 0 else "+", absi(e)]
	var s := _fixed_trim(x, 5 - e)
	if _exp10(absf(float(s))) > e and e + 1 < 6:   # 定点舍入后位数增加（如 99999.95 → 100000）
		s = _fixed_trim(x, maxi(4 - e, 0))
	return s

## 十进制指数（|x| 的科学计数法指数），避免 log10 在 10 的整数次幂附近的误差
static func _exp10(a: float) -> int:
	if a >= 1.0:
		return str(int(floorf(a))).length() - 1 if a < 9e18 else int(floor(log(a) / log(10.0)))
	var s := "%.30f" % a
	var k := 2
	while k < s.length() and s[k] == "0":
		k += 1
	return -(k - 1)

## 定点 n 位（printf 精确舍入，与 Python round 同为“恰好一半取偶”），去掉末尾0与小数点
static func _fixed_trim(x: float, n: int) -> String:
	var s := ("%." + str(n) + "f") % x
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return _clean(s)

static func _clean(s: String) -> String:
	return "0" if s == "-0" else s

## 技能说明：按当前等级渲染 skills.desc_tpl（skill_levels 同名字段覆盖 skills 行）；无模板时用 desc
static func skill_desc(skill_id: String, level: int = 1) -> String:
	var base := {}
	for r in GameData.tables.get("skills", []):
		if CsvUtil.s(r, "skill_id") == skill_id:
			base = (r as Dictionary).duplicate()
			break
	if base.is_empty():
		return ""
	for r in GameData.tables.get("skill_levels", []):
		if CsvUtil.s(r, "skill_id") == skill_id and CsvUtil.i(r, "level") == level:
			base.merge(r, true)   # 与 validate.py 的 dict(skills行, **skill_levels行) 一致
			break
	return row_desc(base)

## 按本行字段渲染 desc_tpl（orange_effects / boss_attacks 等）；无模板时用 desc
static func row_desc(r: Dictionary) -> String:
	var tpl := CsvUtil.s(r, "desc_tpl")
	return render(tpl, r) if tpl != "" else CsvUtil.s(r, "desc")

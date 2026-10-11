class_name CsvUtil
extends RefCounted
## CSV 读取与字段解析（UTF-8、逗号分隔、首行为英文字段名）。
## 所有字段先按字符串读入，再由各 Resource 的 from_row() 按需转换，便于策划改表。

static func load_rows(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("CsvUtil: 无法打开 %s (err %d)" % [path, FileAccess.get_open_error()])
		return rows
	var header := f.get_csv_line()
	if header.size() > 0:
		header[0] = header[0].trim_prefix("\ufeff")
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() == 0 or (line.size() == 1 and line[0].strip_edges() == ""):
			continue
		var row := {}
		for i in header.size():
			row[header[i].strip_edges()] = line[i].strip_edges() if i < line.size() else ""
		rows.append(row)
	return rows

static func s(row: Dictionary, key: String, def: String = "") -> String:
	var v = row.get(key, def)
	return str(v) if v != null else def

static func f(row: Dictionary, key: String, def: float = 0.0) -> float:
	var v := s(row, key)
	return v.to_float() if v.is_valid_float() or v.is_valid_int() else def

static func i(row: Dictionary, key: String, def: int = 0) -> int:
	var v := s(row, key)
	if v.is_valid_int():
		return v.to_int()
	if v.is_valid_float():
		return int(v.to_float())
	return def

static func b(row: Dictionary, key: String, def: bool = false) -> bool:
	var v := s(row, key).to_lower()
	if v == "true":
		return true
	if v == "false":
		return false
	return def

## "a|b|c" -> ["a","b","c"]（空串 -> []）
static func list(value: String) -> PackedStringArray:
	var out := PackedStringArray()
	for part in value.split("|", false):
		if part.strip_edges() != "":
			out.append(part.strip_edges())
	return out

## "k=v;k2=v2" -> {k: v, k2: v2}；值保持字符串，含 "|" 的由调用方再拆
static func kv(value: String) -> Dictionary:
	var out := {}
	for part in value.split(";", false):
		var p := part.split("=", true, 1)
		if p.size() == 2:
			out[p[0].strip_edges()] = p[1].strip_edges()
	return out

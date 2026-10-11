extends Node
## Autoload：存档读写（阶段6）。编解码 / 迁移 / 校验在 SaveCodec，离线收益在 OfflineSystem；规则全文 docs/SAVE_FORMAT.md。
## 写入（原子）：序列化 → save.json.tmp → 关闭 → 重读 tmp 解析+校验和 → save.json 改名 save.json.bak → tmp 改名 save.json。
## 读取：save.json → save.json.bak → save.json.tmp（须校验通过）；Web 另有 localStorage 镜像，取 saved_at 最新的合法份。
##   全部失败：坏文件改名 save.corrupt.<时间>.json 保留，开新档并提示；存档版本高于游戏：拒读、不覆盖（本次运行不写盘）。
## 何时写：每 AUTOSAVE_INTERVAL 秒（暂停中也写，并把 last_settle_at 推到现在 → 暂停不额外产生离线收益）；
##   PlayerState.important_change（突破 / 换装 / 学习 / 升级 / 首通 / 三选一 / 离线领取 / 设置…）防抖到本帧末写一次；
##   Web 切到后台（visibilitychange=hidden）与 pagehide 立即写。
## 启用：非无头运行自动启用（测试 / QA 无头运行不碰 user://）；命令行 -- --no-save 关闭、-- --save 在无头下强制启用、-- --save-dir=<目录> 改目录。

signal status_changed(status: String)
signal boot_finished(result: Dictionary)

const FILE := "save.json"
const WEB_MIRROR_KEY := "replayxian.save.v1"
const SKIP_SCENES := ["test_runner.tscn", "qa_runner.tscn", "shot.tscn"]

var dir := "user://"
var enabled := false          # 是否允许写盘（boot 后为 true；too_new 时为 false）
var booted := false
var write_blocked := false    # 存档版本高于游戏：不覆盖
var status := "off"           # off / saved / dirty / error / blocked
var last_saved_at := 0        # unix 秒
var save_count := 0           # 实际写盘次数（测试用）
var last_reason := ""
var boot_result := {}         # {code: new|ok|recovered|corrupt|too_new, source, corrupt_files, dropped, offline:{...}}
var clock_override := -1      # 测试：固定“现在”（unix 秒）
var web_mirror_enabled := true
var _pending_reasons: Array[String] = []
var _flush_queued := false
var _autosave_t := 0.0
var _js_cbs: Array = []       # 持有 JavaScriptBridge 回调，防止被回收
var _web_mirror_override = null   # 测试：用字典模拟 localStorage

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerState.important_change.connect(request_save)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--save-dir="):
			dir = a.trim_prefix("--save-dir=")
	if should_boot():
		boot()

## 是否在启动时读档并启用自动存档（无头 / 测试 / 截图工具不启用）
static func should_boot() -> bool:
	var ua := OS.get_cmdline_user_args()
	if "--no-save" in ua:
		return false
	for a in OS.get_cmdline_args():
		for s in SKIP_SCENES:
			if str(a).ends_with(s):
				return false
	if "--save" in ua:
		return true
	return DisplayServer.get_name() != "headless"

func now() -> int:
	return clock_override if clock_override >= 0 else int(Time.get_unix_time_from_system())

func path(name: String) -> String:
	return dir.path_join(name)

func is_web() -> bool:
	return OS.has_feature("web")

func autosave_interval() -> float:
	return maxf(GameData.const_f("AUTOSAVE_INTERVAL", 10.0), 1.0)

func _set_status(s: String) -> void:
	if status != s:
		status = s
	status_changed.emit(s)

# ---------- 启动 ----------
## 读档 → 应用 → 结算离线 → 立即保存。返回 boot_result
func boot() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(dir)
	var r := load_best()
	boot_result = {"code": r.code, "source": r.get("source", ""), "corrupt_files": r.get("corrupt_files", []), "dropped": r.get("dropped", []), "offline": {}}
	if r.code == "too_new":
		PlayerState.reset_new_game()
		write_blocked = true
		enabled = false
		booted = true
		_set_status("blocked")
		boot_finished.emit(boot_result)
		return boot_result
	if r.data.is_empty():
		PlayerState.reset_new_game()
		PlayerState.last_settle_at = now(); PlayerState.max_seen_at = now()
	else:
		PlayerState.from_dict(r.data)
	var rng := RandomNumberGenerator.new(); rng.randomize()
	boot_result.offline = OfflineSystem.settle(now(), rng)
	enabled = true
	booted = true
	if is_web():
		_hook_web()
	save_now("boot")
	boot_finished.emit(boot_result)
	return boot_result

# ---------- 读取 ----------
## 按 save.json → .bak → .tmp（Web 再加 localStorage 镜像）找最新的合法存档。
## 返回 {code: new|ok|recovered|corrupt|too_new, data, source, corrupt_files, dropped}
func load_best() -> Dictionary:
	var t := now()
	var cands: Array = []
	var bad: Array[String] = []
	var any_file := false
	for name in [FILE, FILE + ".bak", FILE + ".tmp"]:
		var p := path(name)
		if not FileAccess.file_exists(p):
			continue
		any_file = true
		var txt := _read_text(p)
		var dec := SaveCodec.decode(txt, t, false)
		if dec.code == "too_new" and name == FILE:
			return {"code": "too_new", "data": {}, "source": name, "corrupt_files": [], "dropped": []}
		if dec.ok:
			cands.append({"data": dec.data, "saved_at": dec.saved_at, "source": name, "dropped": dec.dropped})
		else:
			bad.append(name)
	var mirror := _web_mirror_read()
	if mirror != "":
		var dec := SaveCodec.decode(mirror, t, false)
		if dec.ok:
			cands.append({"data": dec.data, "saved_at": dec.saved_at, "source": "localStorage", "dropped": dec.dropped})
	if cands.is_empty():
		if not any_file:
			return {"code": "new", "data": {}, "source": "", "corrupt_files": [], "dropped": []}
		var moved := _quarantine([FILE, FILE + ".bak", FILE + ".tmp"])
		return {"code": "corrupt", "data": {}, "source": "", "corrupt_files": moved, "dropped": []}
	# 主存档合法时优先；否则取 saved_at 最新的一份（Web 镜像比 IndexedDB 新时也取镜像）
	var best: Dictionary = cands[0]
	for c in cands:
		if int(c.saved_at) > int(best.saved_at):
			best = c
	var code := "ok"
	var moved: Array = []
	if FILE in bad:
		code = "recovered"
		moved = _quarantine([FILE])   # 坏的主存档先移走，避免下次写入时被改名成 .bak 覆盖好备份
	elif not FileAccess.file_exists(path(FILE)) and best.source != "localStorage":
		code = "recovered"   # 主存档缺失（如写入中途崩溃）而 .bak / .tmp 可用
	return {"code": code, "data": best.data, "source": best.source, "corrupt_files": moved, "dropped": best.dropped}

func _read_text(p: String) -> String:
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return ""
	if f.get_length() > SaveCodec.MAX_BYTES:
		return "x".repeat(SaveCodec.MAX_BYTES + 1)
	var s := f.get_as_text()
	f.close()
	return s

## 坏文件改名 save.corrupt.<时间>.json（同一秒多份加后缀），返回新文件名
func _quarantine(names: Array) -> Array:
	var out: Array = []
	var stamp := Time.get_datetime_string_from_unix_time(now()).replace(":", "").replace("-", "").replace("T", "-")
	for name in names:
		var p := path(str(name))
		if not FileAccess.file_exists(p):
			continue
		var suffix := "" if name == FILE else "." + str(name).get_extension()
		var dst := "save.corrupt.%s%s.json" % [stamp, suffix]
		var i := 1
		while FileAccess.file_exists(path(dst)):
			dst = "save.corrupt.%s%s.%d.json" % [stamp, suffix, i]; i += 1
		if DirAccess.rename_absolute(p, path(dst)) == OK:
			out.append(dst)
	return out

# ---------- 写入 ----------
func request_save(reason: String = "") -> void:
	if not enabled:
		return
	_pending_reasons.append(reason)
	if status != "dirty":
		_set_status("dirty")
	if not _flush_queued:
		_flush_queued = true
		_flush.call_deferred()

func _flush() -> void:
	_flush_queued = false
	if _pending_reasons.is_empty():
		return
	var r := "|".join(_pending_reasons)
	_pending_reasons.clear()
	save_now(r)

## 立即原子保存；在线时同时推进 last_settle_at / max_seen_at
func save_now(reason: String = "") -> bool:
	if not enabled or write_blocked:
		return false
	var t := now()
	PlayerState.last_settle_at = t
	PlayerState.max_seen_at = maxi(PlayerState.max_seen_at, t)
	var env := SaveCodec.make_envelope(PlayerState.to_dict(), t)
	var text := SaveCodec.serialize(env)
	if not write_atomic(text):
		_set_status("error")
		return false
	_web_mirror_write(text)
	last_saved_at = t
	save_count += 1
	last_reason = reason
	_autosave_t = 0.0
	_set_status("saved")
	return true

## tmp → 关闭 → 重读校验 → 旧档改名 .bak → tmp 改名正式档
func write_atomic(text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var tmp := path(FILE + ".tmp")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("SaveSystem: cannot open %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.close()
	var back := SaveCodec.decode(_read_text(tmp), now() + 1, false)
	if not back.ok:
		push_warning("SaveSystem: tmp verify failed: %s %s" % [back.code, back.detail])
		return false
	var main := path(FILE)
	var bak := path(FILE + ".bak")
	if FileAccess.file_exists(main):
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		if DirAccess.rename_absolute(main, bak) != OK:
			return false
	return DirAccess.rename_absolute(tmp, main) == OK

func _process(delta: float) -> void:
	if not enabled:
		return
	_autosave_t += delta
	if _autosave_t >= autosave_interval():
		save_now("autosave")

# ---------- 导出 / 导入 / 重置 ----------
## 当前进度的存档文本（与 save.json 同格式）
func export_string() -> String:
	if enabled:
		save_now("export")
	return SaveCodec.serialize(SaveCodec.make_envelope(PlayerState.to_dict(), now()))

func export_file_name() -> String:
	return "replayxian_save_%s.json" % Time.get_datetime_string_from_unix_time(now() + _tz_bias_s()).replace(":", "").replace("-", "").replace("T", "_")

static func _tz_bias_s() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60

## 只校验不替换（导入确认前预检，失败立即提示）
func check_import(text: String) -> Dictionary:
	return SaveCodec.decode(text, now(), true)

## 导入：全部校验通过才替换；先备份当前进度到 save.before_import.json；成功后 last_settle_at=now（导入不制造离线收益）并立即保存
func import_string(text: String) -> Dictionary:
	var dec := check_import(text)
	if not dec.ok:
		return dec
	_backup_current("save.before_import.json")
	var data: Dictionary = dec.data
	data.last_settle_at = now()
	PlayerState.from_dict(data)
	if enabled:
		save_now("import")
	PlayerState.important_change.emit("import")
	return dec

## 重置：先备份到 save.before_reset.json（并在保存时把旧档轮换成 .bak），再写新档
func reset_game() -> bool:
	_backup_current("save.before_reset.json")
	var keep_seen := maxi(PlayerState.max_seen_at, now())
	PlayerState.reset_new_game()
	PlayerState.last_settle_at = now(); PlayerState.max_seen_at = keep_seen
	if enabled:
		return save_now("reset")
	return true

func _backup_current(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var src := path(FILE)
	var text := _read_text(src) if FileAccess.file_exists(src) else SaveCodec.serialize(SaveCodec.make_envelope(PlayerState.to_dict(), now()))
	var f := FileAccess.open(path(name), FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()

func location_text() -> String:
	if is_web():
		return "IndexedDB + localStorage"
	return ProjectSettings.globalize_path(dir)

# ---------- Web ----------
func _web_storage() -> Object:
	if not is_web() or not ClassDB.class_exists("JavaScriptBridge"):
		return null
	return JavaScriptBridge.get_interface("localStorage")

func _web_mirror_write(text: String) -> void:
	if not web_mirror_enabled:
		return
	if _web_mirror_override is Dictionary:
		_web_mirror_override[WEB_MIRROR_KEY] = text
		return
	var ls := _web_storage()
	if ls:
		ls.call("setItem", WEB_MIRROR_KEY, text)

func _web_mirror_read() -> String:
	if not web_mirror_enabled:
		return ""
	if _web_mirror_override is Dictionary:
		return str(_web_mirror_override.get(WEB_MIRROR_KEY, ""))
	var ls := _web_storage()
	if ls:
		var v: Variant = ls.call("getItem", WEB_MIRROR_KEY)
		return str(v) if v != null else ""
	return ""

## 切后台 / 关页：立即保存（localStorage 同步写入，不依赖 IndexedDB 异步同步在页面关闭前完成）
func _hook_web() -> void:
	var doc := JavaScriptBridge.get_interface("document")
	var win := JavaScriptBridge.get_interface("window")
	if doc == null or win == null:
		return
	var cb := JavaScriptBridge.create_callback(_on_web_hidden)
	_js_cbs.append(cb)
	doc.addEventListener("visibilitychange", cb)
	win.addEventListener("pagehide", cb)
	JavaScriptBridge.eval("window.__replayxian_save_hooked = true;", true)

func _on_web_hidden(_args: Array) -> void:
	var doc := JavaScriptBridge.get_interface("document")
	if doc and str(doc.visibilityState) != "hidden" and not (_args.size() > 0 and str(_args[0].type) == "pagehide"):
		return
	save_now("hidden")

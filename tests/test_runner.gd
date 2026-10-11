extends Node
## 无头测试入口：godot --headless --path . res://tests/test_runner.tscn
## 依次运行 tests/test_*.gd 中所有 test_* 方法，失败时以退出码1结束。

const SUITES := [
	"res://tests/test_config.gd",
	"res://tests/test_skill_bar.gd",
	"res://tests/test_combat.gd",
	"res://tests/test_boss.gd",
	"res://tests/test_loop.gd",
	"res://tests/test_regressions.gd",
	"res://tests/test_ui_text.gd",
	"res://tests/test_gongfa.gd",
	"res://tests/test_gear.gd",
	"res://tests/test_gear_battle.gd",
	"res://tests/test_ui_panels.gd",
	"res://tests/test_art.gd",
]

## 记录运行期脚本错误：测试过程中出现任何 SCRIPT ERROR 都算该测试失败（避免错误被静默吞掉）
class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	var mutex := Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		mutex.lock()
		errors.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])
		mutex.unlock()
	func _log_message(_message: String, _error: bool) -> void:
		pass

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var total := 0
	var failed := 0
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
	var t0 := Time.get_ticks_msec()
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	for al in ["GameData", "PlayerState"]:
		var n := get_node_or_null("/root/" + al)
		if n == null or not n.has_method("to_dict" if al == "PlayerState" else "load_all"):
			total += 1; failed += 1
			print("  FAIL  autoload %s 未加载（脚本解析错误？）" % al)
	if not catcher.errors.is_empty():
		total += 1; failed += 1
		print("  FAIL  启动阶段脚本错误：\n        - " + "\n        - ".join(catcher.errors))
	for path in SUITES:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			total += 1; failed += 1
			print("  FAIL  无法加载测试脚本 %s" % path)
			continue
		var suite: TestCase = script.new()
		suite.runner = self
		for m in script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_") or (only != "" and not name.contains(only)):
				continue
			total += 1
			suite.failures.clear()
			suite._current = name
			catcher.errors.clear()
			suite.before_each()
			var t := Time.get_ticks_msec()
			await suite.call(name)
			var ms := Time.get_ticks_msec() - t
			for e in catcher.errors:
				suite.failures.append("脚本错误: " + e)
			if suite.failures.is_empty():
				print("  PASS  %s.%s (%d ms)" % [path.get_file().get_basename(), name, ms])
			else:
				failed += 1
				print("  FAIL  %s.%s" % [path.get_file().get_basename(), name])
				for f in suite.failures:
					print("        - " + f)
	print("\n%d tests, %d passed, %d failed (%.1fs)" % [total, total - failed, failed, (Time.get_ticks_msec() - t0) / 1000.0])
	OS.remove_logger(catcher)
	get_tree().paused = false
	get_tree().quit(1 if failed > 0 else 0)

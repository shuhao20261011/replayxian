extends Node
## 无头测试入口：godot --headless --path . res://tests/test_runner.tscn
## 依次运行 tests/test_*.gd 中所有 test_* 方法，失败时以退出码1结束。

const SUITES := [
	"res://tests/test_config.gd",
	"res://tests/test_skill_bar.gd",
	"res://tests/test_combat.gd",
	"res://tests/test_boss.gd",
	"res://tests/test_loop.gd",
]

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
	for path in SUITES:
		var script: GDScript = load(path)
		var suite: TestCase = script.new()
		suite.runner = self
		for m in script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_") or (only != "" and not name.contains(only)):
				continue
			total += 1
			suite.failures.clear()
			suite._current = name
			suite.before_each()
			var t := Time.get_ticks_msec()
			await suite.call(name)
			var ms := Time.get_ticks_msec() - t
			if suite.failures.is_empty():
				print("  PASS  %s.%s (%d ms)" % [path.get_file().get_basename(), name, ms])
			else:
				failed += 1
				print("  FAIL  %s.%s" % [path.get_file().get_basename(), name])
				for f in suite.failures:
					print("        - " + f)
	print("\n%d tests, %d passed, %d failed (%.1fs)" % [total, total - failed, failed, (Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().paused = false
	get_tree().quit(1 if failed > 0 else 0)

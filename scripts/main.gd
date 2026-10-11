extends Node
## 入口：战斗主场景 + HUD。
## 命令行（放在 `--` 之后）：
##   --level=LV_1_3            直接挑战某关（调试）
##   --screenshot-dir=<dir>    截图模式：按 --shots=3,8,20 的秒数截图后退出（需非 headless 运行，例如 xvfb-run）
##   --manual                  以手动模式开局
##   --god                     调试/截图用无敌
##   --boss                    跳过波次直接进入首领战（调试/截图）
##   --demo-inventory          填充演示用养成数据（书/装备/材料/三选一，固定种子）
##   --open-panel=装备|功法     在 --open-at 秒（默认1.5）打开养成面板；--gongfa=GF_xxx 选中功法页签

@onready var battle: Battle = $Battle
@onready var hud: Hud = $HUD

func _ready() -> void:
	get_window().title = UiText.t("GAME_TITLE")
	hud.bind(battle)
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	if args.has("level"):
		var l := GameData.get_level(str(args.level))
		if l:
			battle.start_run(l, Battle.RunMode.CHALLENGE)
	if args.has("boss"):
		battle.debug_force_boss()
	if args.has("god"):
		battle.player.god_mode = true   # 调试/截图：无敌
	if args.has("manual"):
		PlayerState.set_auto_battle(false)
	if args.has("demo-inventory"):
		PlayerState.debug_fill_demo()
		battle.refresh_player_stats()
	if args.has("open-panel"):
		_open_panel_later(str(args["open-panel"]), float(args.get("open-at", "1.5")), str(args.get("gongfa", "")))
	if args.has("screenshot-dir"):
		_screenshot_mode(str(args["screenshot-dir"]), str(args.get("shots", "3,8")), str(args.get("prefix", "shot")))

func _open_panel_later(title: String, at_s: float, gongfa_id: String) -> void:
	await get_tree().create_timer(at_s).timeout
	if gongfa_id != "":
		hud.gongfa_panel.gongfa_id = gongfa_id
	hud.open_panel(title)

func _screenshot_mode(dir: String, shots: String, prefix: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var start := Time.get_ticks_msec()
	for t in shots.split(","):
		var target_ms := start + int(t.to_float() * 1000.0)
		while Time.get_ticks_msec() < target_ms:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := dir.path_join("%s_%ss.png" % [prefix, t])
		img.save_png(path)
		print("screenshot: ", path)
	get_tree().quit()

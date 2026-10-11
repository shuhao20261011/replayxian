extends TestCase
## QA 第一轮（qa/bug_report.md，196c650）缺陷的回归用例：BUG-001/002/003/004/006/007/008/009/010/011/012

func _strong() -> void:
	PlayerState.debug_atk_mult = 40.0
	PlayerState.debug_hp_mult = 50.0

func _wait_finish(b: Battle, seconds: float) -> bool:
	var n := b.runs_completed
	return sim(b, seconds, func() -> bool: return b.runs_completed > n)

func _skyfall_battle() -> Battle:
	var b := make_battle()
	b.start_run(GameData.get_level("LV_3_4"), Battle.RunMode.CHALLENGE)
	b.debug_force_boss()
	b.boss.stun_t = 100.0
	return b

func test_bug001_dead_boss_nodes_released() -> void:
	_strong()
	PlayerState.mark_cleared("LV_1_1")
	var b := make_battle()
	b.start_run(GameData.get_level("LV_1_1"), Battle.RunMode.FARM)
	var wins := 0
	for i in 6:
		check(_wait_finish(b, 240.0), "第%d轮结束" % (i + 1))
		if b.last_result == "victory":
			wins += 1
		sim(b, GameData.const_f("RESULT_SHOW_TIME", 2.0) + 0.2)
		check(b.enemies_root.get_child_count() <= b.enemies.size() + 1, "Enemies 子节点数(%d) ≤ 存活数+1(%d)" % [b.enemies_root.get_child_count(), b.enemies.size() + 1])
		for e in b.enemies_root.get_children():
			check(e.alive or e == b.boss, "没有残留的死亡节点")
	check(wins >= 5, "多次胜利（%d）" % wins)
	free_battle(b)

func _check_hint_cleared(b: Battle, hidden: Array, label: String) -> void:
	check(b.tutorial.active_step.is_empty(), "%s：active_step 已清空" % label)
	near(b.time_scale, 1.0, 0.0001, "%s：恢复1倍速" % label)
	check(hidden.size() >= 1, "%s：发出 hint_hidden" % label)
	eq(int(PlayerState.tutorial_state("TUT_07_SKYFALL_DODGE").get("shown", 0)), 0, "%s：未看完的提示不计次数" % label)

func test_bug002_tutorial_reset_when_boss_killed_during_skyfall() -> void:
	var b := _skyfall_battle()
	var hidden := []
	b.tutorial.hint_hidden.connect(func(id: String, ok: bool) -> void: hidden.append([id, ok]))
	b.start_boss_attack(b.boss, GameData.get_boss_attack("BA_YANMO_SKYFALL"))
	check(not b.tutorial.active_step.is_empty(), "引导出现")
	b.boss.hp = 1.0
	b.player_hit_enemy(b.boss, 100.0, {"can_crit": false})
	b.tick(DT)
	eq(b.last_result, "victory", "预警期间击杀首领")
	_check_hint_cleared(b, hidden, "击杀首领")
	# 下一次天坠预警会再提示
	sim(b, GameData.const_f("RESULT_SHOW_TIME", 2.0) + 0.1)
	b.debug_force_boss(); b.boss.stun_t = 100.0
	var shown := []
	b.tutorial.hint_shown.connect(func(id: String, _t: String) -> void: shown.append(id))
	b.start_boss_attack(b.boss, GameData.get_boss_attack("BA_YANMO_SKYFALL"))
	eq(shown.size(), 1, "之后的天坠预警再次触发引导")
	free_battle(b)

func test_bug002_tutorial_reset_on_death_and_timeout() -> void:
	for how in ["death", "timeout"]:
		PlayerState.reset_new_game()
		var b := _skyfall_battle()
		var hidden := []
		b.tutorial.hint_hidden.connect(func(id: String, ok: bool) -> void: hidden.append([id, ok]))
		b.start_boss_attack(b.boss, GameData.get_boss_attack("BA_YANMO_SKYFALL"))
		if how == "death":
			b.player.apply_hp_loss(1e12)
		else:
			b.boss_time_left = 0.0001
		b.tick(DT)
		check(b.phase == Battle.Phase.DEFEAT, "%s 结算（%s）" % [how, b.last_result])
		_check_hint_cleared(b, hidden, how)
		check(b.telegraphs.is_empty(), "%s：预警已清理" % how)
		free_battle(b)

func test_bug003_return_to_highest_after_marks_cleared() -> void:
	for id in ["LV_1_1", "LV_1_2", "LV_1_3"]:
		PlayerState.mark_cleared(id)
	PlayerState.debug_atk_mult = 0.01
	PlayerState.debug_hp_mult = 0.002
	var b := make_battle()
	b.start_run(GameData.get_level("LV_1_3"), Battle.RunMode.FARM)
	check(_wait_finish(b, 240.0), "弱配置失败")
	sim(b, GameData.const_f("RESULT_SHOW_TIME", 2.0) + 0.1)
	check(PlayerState.is_unstable("LV_1_3"), "1-3 被标记")
	eq(b.level.id, "LV_1_2", "回退到 1-2")
	PlayerState.notify_equipment_changed()   # 换装清除标记
	_strong()
	b.player.reset_for_run(PlayerState.combat_stats())
	var seen := []
	for i in 2:
		check(_wait_finish(b, 240.0), "挂机一轮")
		sim(b, GameData.const_f("RESULT_SHOW_TIME", 2.0) + 0.1)
		seen.append(b.level.id)
	eq(seen[0], "LV_1_3", "标记清除后下一轮回到最高已通关关卡 1-3")
	check(not b.retreat_active, "回退状态结束")
	free_battle(b)

func test_bug004_auto_subtext_from_table() -> void:
	var b := _skyfall_battle()
	var shown := []
	b.tutorial.hint_shown.connect(func(_id: String, text: String) -> void: shown.append(text))
	PlayerState.set_auto_battle(true)
	b.start_boss_attack(b.boss, GameData.get_boss_attack("BA_YANMO_SKYFALL"))
	eq(shown.size(), 1, "触发")
	if shown.size() == 1:
		var parts: PackedStringArray = str(shown[0]).split("\n")
		eq(parts.size(), 2, "自动模式带第二行小字")
		var row: Dictionary = {}
		for r in GameData.tables.tutorial_steps:
			if CsvUtil.s(r, "step_id") == "TUT_07_SKYFALL_DODGE":
				row = r
		check(parts.size() == 2 and CsvUtil.s(row, "ui_target").contains(parts[1]), "小字取自 ui_target（%s）" % (parts[1] if parts.size() > 1 else ""))
	free_battle(b)

func test_bug006_dodge_exact_distance_and_cooldown() -> void:
	var b := make_battle()
	b.start_run(GameData.get_level("LV_1_1"), Battle.RunMode.CHALLENGE)
	PlayerState.set_auto_battle(false)
	var x0 := b.player.position.x
	b.player.dodge(1)
	var frames := 0
	while b.player.is_dodging() and frames < 100:
		b.player.step(DT)
		frames += 1
	near(b.player.position.x - x0, GameData.const_f("DODGE_DISTANCE"), 0.01, "闪避位移恰为 DODGE_DISTANCE")
	eq(frames, int(round(GameData.const_f("DODGE_DURATION") * 60.0)), "免伤帧数")
	var cdf := frames
	while b.player.dodge_cd > 0.0 and cdf < 1000:
		b.player.step(DT)
		cdf += 1
	eq(cdf, int(round(GameData.const_f("DODGE_COOLDOWN") * 60.0)), "冷却帧数恰为 DODGE_COOLDOWN×60")
	free_battle(b)

func test_bug007_arena_telegraph_covers_view() -> void:
	var b := _skyfall_battle()
	var tg: Telegraph = null
	b.start_boss_attack(b.boss, GameData.get_boss_attack("BA_YANMO_SKYFALL"))
	for t in b.telegraphs:
		if t.arena:
			tg = t
	check(tg != null, "全场预警")
	PlayerState.set_auto_battle(false)
	b.controller.virtual_move = 1.0
	sim(b, 0.3)
	b.controller.virtual_move = 0.0
	if tg:
		var vr := b.view_rect()
		check(tg.x0 <= vr.position.x and tg.x1 >= vr.end.x, "镜头移动后预警仍覆盖整个可见宽度")
	free_battle(b)

func test_bug009_world_origin_reset_and_log_cap() -> void:
	var b := make_battle()
	b.start_run(GameData.get_level("LV_1_1"), Battle.RunMode.CHALLENGE)
	b.player.position.x = 123456.0
	b.start_run(GameData.get_level("LV_1_1"), Battle.RunMode.FARM_NORMALS)
	near(b.player.position.x, 0.0, 0.001, "每轮开局世界坐标归零")
	for i in 400:
		b.skills.cast_log.append({"t": 0.0})
	PlayerState.set_auto_battle(false)
	var e := spawn_dummy(b, "EN_BAMBOO_IMP", 200); e.stun_t = 100.0
	b.skills.cds[0] = 0.0
	b.controller.request_skill(0)
	b.tick(DT)
	check(b.skills.cast_log.size() <= 256, "cast_log 有上限（%d）" % b.skills.cast_log.size())
	free_battle(b)

func test_bug010_farm_normals_death_not_marked() -> void:
	PlayerState.debug_atk_mult = 0.01
	PlayerState.debug_hp_mult = 0.002
	var banners := []
	var b := make_battle()
	b.banner.connect(func(t: String) -> void: banners.append(t))
	b.start_run(GameData.get_level("LV_1_1"), Battle.RunMode.FARM_NORMALS)
	check(_wait_finish(b, 240.0), "阵亡")
	sim(b, GameData.const_f("RESULT_SHOW_TIME", 2.0) + 0.1)
	check(PlayerState.unstable_levels.is_empty(), "未通关刷普通怪阵亡不打标记")
	for t in banners:
		check(not t.contains("难以稳定"), "不弹回退提示")
	eq(b.mode, Battle.RunMode.FARM_NORMALS, "继续刷1-1普通怪")
	free_battle(b)

const MAIN := preload("res://scenes/main.tscn")

func test_bug008_011_012_hud_layout() -> void:
	var m: Node = MAIN.instantiate()
	runner.add_child(m)
	await runner.get_tree().process_frame
	var hud: Hud = m.get_node("HUD")
	var battle: Battle = m.get_node("Battle")
	battle.auto_tick = false
	# BUG-011：新一轮开局行进中显示第1波
	battle.start_run(GameData.get_level("LV_1_1"), Battle.RunMode.FARM_NORMALS)
	battle.wave_index = 0
	hud._process(0.0)
	check(hud.wave_label.text.contains("第 1 / "), "新一轮开局显示第1波（%s）" % hud.wave_label.text)
	# BUG-008：生命5位数时底栏仍在 1280×720 内
	battle.player.max_hp = 99999; battle.player.hp = 99999
	hud._on_hp(99999, 99999)
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	var vp := hud.root.get_viewport_rect().size
	for c in hud.root.find_children("*", "Button", true, false):
		var r := (c as Control).get_global_rect()
		if (c as Control).is_visible_in_tree():
			check(r.end.x <= vp.x + 0.5 and r.end.y <= vp.y + 0.5, "按钮 %s 未被裁切（%s）" % [(c as Button).text.replace("\n", " "), r])
	# BUG-004/012：自动模式小字与空格键图标
	hud._show_hint("按空格闪避！\n小字")
	check(hud.hint_key.visible and hud.hint_sub.text == "小字", "空格图标与小字显示")
	hud._show_hint("")
	check(not hud.hint_key.visible and hud.hint_sub.text == "", "收起")
	runner.remove_child(m); m.queue_free()

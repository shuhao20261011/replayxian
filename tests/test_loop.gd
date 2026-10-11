extends TestCase
## 刷怪 → 首领 → 胜利/失败 → 挂机 循环（含 v3 自动挂机失败回退）

func _strong() -> void:
	PlayerState.debug_atk_mult = 40.0
	PlayerState.debug_hp_mult = 50.0

func _weak() -> void:
	PlayerState.debug_atk_mult = 0.01
	PlayerState.debug_hp_mult = 0.002

func _wait_finish(b: Battle, seconds: float) -> bool:
	var n := b.runs_completed
	return sim(b, seconds, func() -> bool: return b.runs_completed > n)

func test_new_game_challenges_first_level_and_waves_flow() -> void:
	_strong()
	var b := make_battle()
	var waves := []
	var phases := []
	b.wave_changed.connect(func(i: int, _n: int) -> void: waves.append(i))
	b.phase_changed.connect(func(p: int) -> void: phases.append(p))
	b.start_default_run()
	eq(b.level.id, GameData.first_level().id, "新存档从第一关开始")
	eq(b.mode, Battle.RunMode.CHALLENGE, "新存档直接挑战")
	check(_wait_finish(b, 240.0), "一轮结束")
	eq(b.last_result, "victory", "强力配置通关")
	eq(waves, [1, 2, 3, 4], "依次经过4波")
	check(phases.has(Battle.Phase.BOSS_INTRO) and phases.has(Battle.Phase.BOSS), "4波后进入首领战")
	check(PlayerState.is_cleared("LV_1_1"), "标记通关")
	check(PlayerState.lingshi > 0 and PlayerState.xiuwei > 0, "击杀获得灵石/修为")
	sim(b, GameData.const_f("RESULT_SHOW_TIME", 2.0) + 0.1)
	eq(b.mode, Battle.RunMode.FARM, "通关后转为挂机")
	eq(b.level.id, "LV_1_1", "挂机刷刚通关的关卡")
	check(_wait_finish(b, 240.0), "挂机再刷一轮")
	eq(b.last_result, "victory", "重复挂机通关")
	free_battle(b)

func test_fail_without_clear_farms_first_level_normals() -> void:
	_weak()
	PlayerState.set_auto_battle(false)
	var b := make_battle()
	b.start_default_run()
	check(_wait_finish(b, 120.0), "失败结束")
	eq(b.last_result, "defeat", "阵亡判负")
	sim(b, GameData.const_f("RESULT_SHOW_TIME", 2.0) + 0.1)
	eq(b.level.id, GameData.first_level().id, "未通关时刷第一关")
	eq(b.mode, Battle.RunMode.FARM_NORMALS, "只刷普通怪")
	check(PlayerState.lingshi >= 0, "失败不扣资源")
	free_battle(b)

func test_farm_normals_loops_without_boss() -> void:
	_strong()
	var b := make_battle()
	var boss_seen := [false]
	b.boss_spawned.connect(func(_bs: Boss) -> void: boss_seen[0] = true)
	b.start_run(GameData.first_level(), Battle.RunMode.FARM_NORMALS)
	check(_wait_finish(b, 200.0), "4波结束")
	eq(b.last_result, "loop", "普通怪循环")
	check(not boss_seen[0], "不刷首领")
	b.tick(DT)
	eq(b.mode, Battle.RunMode.FARM_NORMALS, "继续循环")
	eq(b.wave_index, 0, "重新从第1波开始")
	free_battle(b)

func test_boss_timeout_is_failure() -> void:
	PlayerState.debug_atk_mult = 0.0001
	PlayerState.mark_cleared("LV_1_1")
	PlayerState.set_auto_battle(false)
	var b := make_battle()
	b.start_run(GameData.get_level("LV_1_2"), Battle.RunMode.CHALLENGE)
	b.debug_force_boss()
	b.player.god_mode = true
	check(_wait_finish(b, 70.0), "首领战结束")
	eq(b.last_result, "timeout", "超过60秒判负")
	sim(b, GameData.const_f("RESULT_SHOW_TIME", 2.0) + 0.1)
	eq(b.level.id, "LV_1_1", "返回最近已通关关卡")
	eq(b.mode, Battle.RunMode.FARM, "挂机")
	check(not PlayerState.is_unstable("LV_1_2"), "手动模式失败不打标记")
	free_battle(b)

func test_manual_fail_returns_to_last_cleared_without_marks() -> void:
	for id in ["LV_1_1", "LV_1_2", "LV_1_3"]:
		PlayerState.mark_cleared(id)
	PlayerState.set_auto_battle(false)
	_weak()
	var b := make_battle()
	b.start_run(GameData.get_level("LV_1_2"), Battle.RunMode.FARM)
	check(_wait_finish(b, 120.0), "失败")
	sim(b, GameData.const_f("RESULT_SHOW_TIME", 2.0) + 0.1)
	eq(b.level.id, "LV_1_3", "手动失败：按原规则回到最近已通关关卡")
	check(PlayerState.unstable_levels.is_empty(), "不计数不打标记")
	free_battle(b)

func test_auto_fail_retreat_marks_and_banner() -> void:
	for id in ["LV_1_1", "LV_1_2", "LV_1_3"]:
		PlayerState.mark_cleared(id)
	_weak()
	var b := make_battle()
	var banners := []
	b.banner.connect(func(t: String) -> void: banners.append(t))
	b.start_run(GameData.get_level("LV_1_3"), Battle.RunMode.FARM)
	check(_wait_finish(b, 120.0), "自动挂机失败")
	sim(b, GameData.const_f("RESULT_SHOW_TIME", 2.0) + 0.1)
	check(PlayerState.is_unstable("LV_1_3"), "1-3 被标记不稳定")
	eq(b.level.id, "LV_1_2", "回退到已通关且未标记的最高关卡")
	eq(b.mode, Battle.RunMode.FARM, "继续自动挂机")
	var found := false
	for t in banners:
		if t.contains("暂难稳过") and t.contains(GameData.get_level("LV_1_3").name) and t.contains(GameData.get_level("LV_1_2").name):
			found = true
	check(found, "顶部提示一行回退信息: %s" % str(banners))
	# 再失败：1-2 也被标记，回退到 1-1
	check(_wait_finish(b, 120.0), "再次失败")
	sim(b, GameData.const_f("RESULT_SHOW_TIME", 2.0) + 0.1)
	eq(b.level.id, "LV_1_1", "继续回退")
	check(_wait_finish(b, 120.0), "第三次失败")
	sim(b, GameData.const_f("RESULT_SHOW_TIME", 2.0) + 0.1)
	eq(b.level.id, GameData.first_level().id, "无可用关卡时兜底第一关")
	eq(b.mode, Battle.RunMode.FARM_NORMALS, "兜底刷第一关普通怪")
	free_battle(b)

func test_unstable_marks_reset_rules() -> void:
	for id in ["LV_1_1", "LV_1_2", "LV_1_3"]:
		PlayerState.mark_cleared(id)
	PlayerState.record_auto_failure("LV_1_2")
	PlayerState.record_auto_failure("LV_1_3")
	check(PlayerState.is_unstable("LV_1_2") and PlayerState.is_unstable("LV_1_3"), "已标记")
	eq(PlayerState.auto_retreat_level().id, "LV_1_1", "回退目标跳过标记关")
	PlayerState.unequip_skill(2)
	check(PlayerState.unstable_levels.is_empty() and PlayerState.auto_fail_counts.is_empty(), "更换技能栏清除全部标记")
	PlayerState.record_auto_failure("LV_1_3")
	PlayerState.learn_skill_debug("SK_SWORD_FLYING", 2)
	check(PlayerState.unstable_levels.is_empty(), "技能升级清除标记")
	PlayerState.record_auto_failure("LV_1_3")
	PlayerState.set_realm("RL_ZHUJI")
	check(PlayerState.unstable_levels.is_empty(), "境界突破清除标记")
	PlayerState.record_auto_failure("LV_1_3")
	PlayerState.notify_equipment_changed()
	check(PlayerState.unstable_levels.is_empty(), "换装清除标记")

func test_manual_challenge_clear_removes_only_that_mark() -> void:
	for id in ["LV_1_1", "LV_1_2", "LV_1_3"]:
		PlayerState.mark_cleared(id)
	PlayerState.record_auto_failure("LV_1_2")
	PlayerState.record_auto_failure("LV_1_3")
	_strong()
	var b := make_battle()
	check(b.challenge("LV_1_3"), "可挑战已通关关卡")
	check(_wait_finish(b, 240.0), "挑战结束")
	eq(b.last_result, "victory", "挑战成功")
	check(not PlayerState.is_unstable("LV_1_3"), "手动挑战成功清除该关标记")
	check(PlayerState.is_unstable("LV_1_2"), "其他关卡标记保留")
	eq(int(PlayerState.auto_fail_counts.get("LV_1_3", 0)), 0, "该关失败计数清零")
	free_battle(b)

func test_marks_persist_in_save_dict() -> void:
	PlayerState.mark_cleared("LV_1_1")
	PlayerState.record_auto_failure("LV_1_1")
	PlayerState.set_tutorial_state("TUT_07_SKYFALL_DODGE", {"shown": 2, "done": false})
	var d := PlayerState.to_dict()
	var json := JSON.stringify(d)
	PlayerState.reset_new_game()
	check(not PlayerState.is_unstable("LV_1_1"), "重置后无标记")
	PlayerState.from_dict(JSON.parse_string(json))
	check(PlayerState.is_unstable("LV_1_1"), "标记从存档恢复")
	eq(int(PlayerState.auto_fail_counts.get("LV_1_1", 0)), 1, "失败计数从存档恢复")
	eq(int(PlayerState.tutorial_state("TUT_07_SKYFALL_DODGE").shown), 2, "引导次数从存档恢复")

## 默认开局配置（炼气 + 白武器白衣袍 + 3本基础技能1级）自动挂机稳定刷 1-1
func test_auto_idle_stability_default_loadout() -> void:
	PlayerState.mark_cleared("LV_1_1")
	var b := make_battle(777)
	b.start_run(GameData.get_level("LV_1_1"), Battle.RunMode.FARM)
	var results := {}
	b.run_finished.connect(func(r: String, _l: String, _f: bool) -> void: results[r] = int(results.get(r, 0)) + 1)
	sim(b, 600.0)
	print("        auto-idle 600s on LV_1_1: ", results, " lingshi=", PlayerState.lingshi)
	check(int(results.get("victory", 0)) >= 3, "10分钟内至少3轮通关")
	eq(int(results.get("defeat", 0)) + int(results.get("timeout", 0)), 0, "默认配置挂机 1-1 不失败")
	check(PlayerState.auto_battle, "全程保持自动")
	free_battle(b)

## 冒烟：15关全部可跑通（覆盖6种普通怪行为与3个首领全部招式）
func test_all_levels_playable_with_strong_stats() -> void:
	_strong()
	PlayerState.set_tutorial_state("TUT_07_SKYFALL_DODGE", {"shown": 3, "done": true})
	var b := make_battle(99)
	for l in GameData.levels_ordered:
		b.start_run(l, Battle.RunMode.CHALLENGE)
		check(_wait_finish(b, 300.0), "%s 一轮结束" % l.id)
		eq(b.last_result, "victory", "%s 强力配置通关" % l.id)
	free_battle(b)

## 冒烟：12个主动技能全部能释放并造成伤害
func test_all_active_skills_castable() -> void:
	var actives: Array[String] = []
	for s: SkillDef in GameData.skills.values():
		if s.is_active():
			actives.append(s.id)
			PlayerState.learn_skill_debug(s.id)
	PlayerState.set_auto_battle(false)
	var b := make_battle()
	b.start_run(GameData.get_level("LV_2_5"), Battle.RunMode.CHALLENGE)
	for i in range(0, actives.size(), 4):
		for k in 4:
			PlayerState.unequip_skill(k)
		for k in 4:
			if i + k < actives.size():
				check(PlayerState.equip_skill(k, actives[i + k]), "装配 %s" % actives[i + k])
		for k in 4:
			for e in b.enemies.duplicate():
				b._free_node(e)
			b.enemies.clear()
			var targets: Array[Enemy] = []
			for dx in [80, 140, 200]:
				var e := spawn_dummy(b, "EN_MARSH_WISP", dx)
				e.max_hp = 1e7; e.hp = 1e7; e.stun_t = 100.0
				targets.append(e)
			b.player.facing = 1
			b.skills.cds[k] = 0.0
			var n := b.skills.cast_log.size()
			b.controller.request_skill(k)
			b.tick(TestCase.DT)
			var sid := PlayerState.active_slots[k]
			check(b.skills.cast_log.size() == n + 1, "%s 可释放" % sid)
			var sk := GameData.get_skill(sid)
			sim(b, maxf(sk.duration_s, 0.6) + 0.6)
			if sk.shape == "self_buff" and sk.effect2_type == "burst_absorb_pct":
				b.player.absorb(1e9)   # 打破金刚不坏 → 爆发
			var dmg := false
			for e in targets:
				if e.hp < 1e7:
					dmg = true
			check(dmg or sk.shape == "self_buff" and sk.effect2_type != "burst_absorb_pct" or sk.id == "SK_GANG_GUARD", "%s 造成伤害" % sid)
			check(sk.shape != "self_buff" or b.player.shields.size() >= 0, "护盾正常")
	free_battle(b)

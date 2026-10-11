extends TestCase
## 配置表加载与数据驱动

func test_all_tables_loaded() -> void:
	eq(GameData.TABLE_NAMES.size(), 25, "25张配置表")
	for t in GameData.TABLE_NAMES:
		check((GameData.tables.get(t, []) as Array).size() > 0, "表 %s 有数据" % t)
	check(GameData.errors.is_empty(), "引用校验无错误: %s" % ", ".join(GameData.errors))

func test_skill_structure() -> void:
	eq(GameData.gongfa.size(), 3, "3部功法")
	eq(GameData.skills.size(), 15, "15个技能")
	var actives := 0
	for s: SkillDef in GameData.skills.values():
		if s.is_active():
			actives += 1
		eq(s.levels.size(), GameData.const_i("SKILL_MAX_LEVEL", 10), "%s 有1-10级数值" % s.id)
		var bk := GameData.books.get(s.book_id) as SkillBookDef
		check(bk != null and bk.skill_id == s.id, "%s 与技能书一一对应" % s.id)
	eq(actives, 12, "12个主动技能")
	eq(GameData.basic_skill_ids().size(), 3, "3个基础技能")

func test_levels_and_waves() -> void:
	eq(GameData.levels_ordered.size(), 15, "15关")
	for l in GameData.levels_ordered:
		eq(l.wave_count, GameData.const_i("WAVES_PER_LEVEL", 4), "%s 4波" % l.id)
		for wi in range(1, l.wave_count + 1):
			check(not l.wave_entries(wi).is_empty(), "%s 第%d波有怪" % [l.id, wi])
		check(GameData.get_enemy(l.boss_id) != null and GameData.get_enemy(l.boss_id).is_boss(), "%s 首领存在" % l.id)
		# 与 CSV 原始行一致（改表即改游戏）
	for r in GameData.tables.levels:
		var l := GameData.get_level(CsvUtil.s(r, "level_id"))
		near(l.boss_hp_mult, CsvUtil.f(r, "boss_hp_mult"), 0.0001, "%s boss_hp_mult 取自表" % l.id)

func test_v2_boss_attack_columns() -> void:
	var sky := GameData.get_boss_attack("BA_YANMO_SKYFALL")
	check(sky != null, "玄岩天坠存在")
	if sky == null:
		return
	eq(sky.anchor, "arena", "anchor=arena")
	eq(sky.damage_type, "true_maxhp", "真实伤害类型")
	check(sky.damage_maxhp_pct > 0.0, "damage_maxhp_pct > 0")
	check(GameData.get_enemy("BOSS_YANMO").attack_ids.has("BA_YANMO_SKYFALL"), "岩魔招式包含天坠")
	eq(GameData.telegraph_color(sky), Color(GameData.const_s("TELEGRAPH_DEFAULT_COLOR")), "预警颜色")
	eq(GameData.telegraph_style(sky), "dashed", "预警样式")
	var slash := GameData.get_boss_attack("BA_ZHUMEI_SLASH")
	eq(GameData.telegraph_style(slash), GameData.const_s("TELEGRAPH_DEFAULT_STYLE", "dashed"), "空样式回落到常量默认")

func test_plan_constants() -> void:
	near(GameData.const_f("DODGE_DURATION"), 0.3, 0.0001, "闪避0.3秒")
	near(GameData.const_f("DODGE_COOLDOWN"), 3.0, 0.0001, "闪避冷却3秒")
	near(GameData.const_f("BOSS_WARN_TIME"), 0.8, 0.0001, "预警0.8秒")
	near(GameData.const_f("BOSS_TIME_LIMIT"), 60.0, 0.0001, "首领限时60秒")
	near(GameData.const_f("REFLECT_COUNTER_ICD"), 0.8, 0.0001, "反震内置间隔")
	eq(GameData.const_i("ACTIVE_SLOT_COUNT"), 4, "4格主动栏")
	check(GameData.const_i("AUTO_FAIL_RETREAT_COUNT", 0) >= 1, "AUTO_FAIL_RETREAT_COUNT 存在")

func test_empty_breakthrough_material_ok() -> void:
	var m := GameData.get_map("MAP_XUANYAN")
	eq(m.breakthrough_mat_id, "", "玄岩洞无突破材料")
	check(GameData.errors.is_empty(), "空突破材料不报错")

func test_guard_v2_reflect_fields() -> void:
	var g := GameData.get_skill("SK_GANG_GUARD")
	eq(g.effect2_type, "reflect_add", "护体 effect2=reflect_add")
	check(g.damage_coef > 0.0, "护体反震系数>0")

## 改表即改游戏：复制一份表、修改常量和波次，重新加载后生效
func test_data_driven_override() -> void:
	var dir := "user://test_data_override"
	DirAccess.make_dir_recursive_absolute(dir)
	for t in GameData.TABLE_NAMES:
		var src := FileAccess.get_file_as_string(GameData.DEFAULT_DATA_DIR.path_join(t + ".csv"))
		if t == "constants":
			src = src.replace("DODGE_COOLDOWN,3.0", "DODGE_COOLDOWN,5.0")
		if t == "waves":
			src = src.replace("LV_1_1,1,EN_BAMBOO_IMP,4,", "LV_1_1,1,EN_BAMBOO_IMP,7,")
		var f := FileAccess.open(dir.path_join(t + ".csv"), FileAccess.WRITE)
		f.store_string(src)
		f.close()
	check(GameData.load_all(dir), "覆盖表加载成功")
	near(GameData.const_f("DODGE_COOLDOWN"), 5.0, 0.0001, "闪避冷却改为5")
	eq(GameData.get_level("LV_1_1").wave_entries(1)[0].count, 7, "1-1第1波改为7只")
	PlayerState.reset_new_game()
	var b := make_battle()
	b.start_run(GameData.get_level("LV_1_1"), Battle.RunMode.CHALLENGE)
	b.player.dodge()
	near(b.player.dodge_cd, 5.0, 0.0001, "玩家闪避冷却跟随表")
	free_battle(b)
	GameData.load_all()
	near(GameData.const_f("DODGE_COOLDOWN"), 3.0, 0.0001, "恢复默认表")

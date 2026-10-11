extends TestCase
## v5 文案：ui_texts.csv 读取、占位符渲染与 design/tools/common.py render_tpl() 逐字一致、desc_tpl 渲染

func test_render_matches_python_render_tpl() -> void:
	var f := FileAccess.open("res://tests/fixtures/render_tpl_cases.json", FileAccess.READ)
	check(f != null, "对照用例存在（python3 tools/gen_render_cases.py 生成）")
	if f == null:
		return
	var cases: Array = JSON.parse_string(f.get_as_text())
	check(cases.size() > 100, "用例数 %d" % cases.size())
	var bad := 0
	for c in cases:
		var got := ""
		if c.has("skill_id"):
			got = UiText.skill_desc(c.skill_id, int(c.level))
		else:
			got = UiText.render(c.tpl, c.row)
		if got != c.out:
			bad += 1
			if bad <= 8:
				check(false, "%s → 期望「%s」实际「%s」" % [c.get("tpl", "%s Lv%d" % [c.get("skill_id"), int(c.get("level", 0))]), c.out, got])
	eq(bad, 0, "全部与 Python render_tpl 一致")

func test_format_rules() -> void:
	eq(UiText.render("{a:pct}", {"a": 0.08}), "8%", "pct")
	eq(UiText.render("{a:pct}", {"a": 0.155}), "15.5%", "pct 1位小数")
	eq(UiText.render("{a}", {"a": "6.0"}), "6", "num 去尾0")
	eq(UiText.render("{a:num}", {"a": 1.25}), "1.25", "num 2位小数")
	eq(UiText.render("{a:int}", {"a": 2.5}), "2", "int 恰好一半取偶（同 Python round）")
	eq(UiText.render("{a:int}", {"a": 3.5}), "4", "int")
	eq(UiText.render("暂难稳过{x}", {"x": "竹径初行"}), "暂难稳过竹径初行", "字符串原样代入")

func test_skill_desc_level1_equals_desc_column() -> void:
	for r in GameData.tables.skills:
		eq(UiText.skill_desc(CsvUtil.s(r, "skill_id"), 1), CsvUtil.s(r, "desc"), "%s 1级渲染 = desc" % CsvUtil.s(r, "skill_id"))
	# 高等级随 skill_levels 变化
	var lv1 := UiText.skill_desc("SK_SWORD_FLYING", 1)
	var lv10 := UiText.skill_desc("SK_SWORD_FLYING", 10)
	check(lv1 != lv10, "10级说明数值随等级变化：%s" % lv10)
	for t in ["orange_effects", "boss_attacks"]:
		for r in GameData.tables[t]:
			if CsvUtil.s(r, "desc_tpl") != "":
				eq(UiText.row_desc(r), CsvUtil.s(r, "desc"), "%s 本行渲染 = desc" % t)

func test_ui_texts_table_and_keys() -> void:
	check(GameData.TABLE_NAMES.has("ui_texts"), "ui_texts 在 TABLE_NAMES")
	check(GameData.tables.ui_texts.size() >= 40, "主表已加载")
	eq(UiText.t("BANNER_RETREAT", {"failed_level_name": "甲", "to_level_name": "乙"}), "暂难稳过甲，退守乙", "回退横幅来自表")
	eq(UiText.t("HUD_WAVE", {"wave": 1, "wave_total": 4}), "第1/4波", "波次")
	# 主表 key 优先于待收编表；待收编表 key 不得与主表重复（策划收编后应删掉对应行）
	var main_keys := {}
	for m in GameData.tables.ui_texts:
		main_keys[CsvUtil.s(m, "key")] = true
	check(not FileAccess.file_exists("res://data/ui_texts_local.csv"), "v5.3 已收编，本地补充表已删除")
	for r in CsvUtil.load_rows(UiText.PENDING_PATH):
		var k := CsvUtil.s(r, "key")
		check(not main_keys.has(k), "待收编表 %s 已进主表，应删除该行" % k)
		var mx := CsvUtil.i(r, "max_chars")
		var txt := CsvUtil.s(r, "text")
		if mx > 0 and not txt.contains("{"):
			check(txt.length() <= mx, "%s 长度 %d ≤ %d" % [k, txt.length(), mx])
		var plain := txt
		var ph := RegEx.new(); ph.compile("\\{[^}]*\\}")
		plain = ph.sub(plain, "", true)
		check(not plain.contains(" · ") and not plain.contains(":") and not plain.contains(","), "%s 标点全角（README 5.1）" % k)

## 代码里用到的每个 UiText.t("KEY") 都必须在主表或待收编表里
func test_all_used_keys_exist() -> void:
	var re := RegEx.new(); re.compile("UiText\\.t\\(\"([A-Z0-9_]+)\"")
	var missing := []
	for p in _scripts():
		for m in re.search_all(FileAccess.get_file_as_string(p)):
			if not UiText.has(m.get_string(1)):
				missing.append("%s:%s" % [p.get_file(), m.get_string(1)])
	eq(missing, [], "所有文案 key 存在")

## 上屏文字读表：UI/战斗脚本的字符串字面量里不得出现中文（日志 push_warning/print 与注释除外）
func test_no_cjk_literals_in_ui_scripts() -> void:
	var str_re := RegEx.new(); str_re.compile("\"([^\"\\\\]|\\\\.)*\"")
	var cjk := RegEx.new(); cjk.compile("[\\x{4e00}-\\x{9fff}]")
	var bad := []
	for p in _scripts():
		var n := 0
		for line in FileAccess.get_file_as_string(p).split("\n"):
			n += 1
			var code := line.strip_edges()
			if code.begins_with("#") or code.begins_with("push_warning") or code.begins_with("push_error") or code.begins_with("print") or code.begins_with("errors.append") or code.begins_with("_check_ref"):
				continue
			for m in str_re.search_all(line):
				if cjk.search(m.get_string()) != null:
					bad.append("%s:%d %s" % [p.get_file(), n, m.get_string()])
	eq(bad, [], "无硬编码中文上屏文字")

func _scripts() -> Array:
	var out := []
	for d in ["res://scripts/battle", "res://scripts/ui", "res://scripts/systems", "res://scripts"]:
		for fn in DirAccess.get_files_at(d):
			if fn.ends_with(".gd"):
				out.append(d.path_join(fn))
	return out

func test_no_hardcoded_old_names() -> void:
	# v5 改名：冠→头冠、鞋→鞋履、攻击%→攻击加成、生命%→生命加成、攻速→攻击速度、雷伤→御雷诀伤害、竹刺突→竹刺破土
	var old := ["竹刺突", "攻击%", "生命%", "雷伤"]
	var files := []
	for d in ["res://scripts/battle", "res://scripts/ui", "res://scripts/autoload", "res://scripts"]:
		for fn in DirAccess.get_files_at(d):
			if fn.ends_with(".gd"):
				files.append(d.path_join(fn))
	for p in files:
		var txt := FileAccess.get_file_as_string(p)
		for o in old:
			check(not txt.contains("\"" + o) and not txt.contains(o + "\""), "%s 不应写死旧名称 %s" % [p, o])

func test_tutorial_reads_hint_columns() -> void:
	var row := {}
	for r in GameData.tables.tutorial_steps:
		if CsvUtil.s(r, "step_id") == "TUT_07_SKYFALL_DODGE":
			row = r
	eq(TutorialService.hint_text(row), CsvUtil.s(row, "hint_text"), "大字取 hint_text 列")
	eq(TutorialService.auto_subtext(row), CsvUtil.s(row, "sub_text"), "小字取 sub_text 列")

func test_v51_telegraph_colors_by_map_and_setting() -> void:
	var cases := {"LV_1_3": "#B8382C", "LV_2_3": "#F4F1EA", "LV_3_4": "#F4F1EA"}
	for lid in cases:
		PlayerState.telegraph_alt = false
		var b := make_battle()
		b.start_run(GameData.get_level(lid), Battle.RunMode.CHALLENGE)
		b.debug_force_boss()
		b.boss.stun_t = 100.0
		var danger: BossAttackDef = null
		for a in b.boss.attacks:
			if a.is_danger:
				danger = a
		b.start_boss_attack(b.boss, danger)
		var tg: Telegraph = b.telegraphs[0]
		eq(tg.color.to_html(false), Color(cases[lid]).to_html(false), "%s %s 预警色" % [lid, danger.id])
		_free_tgs(b)
		PlayerState.telegraph_alt = true
		b.start_boss_attack(b.boss, danger)
		eq((b.telegraphs[0] as Telegraph).color.to_html(false), Color("#F4F1EA").to_html(false), "%s 统一预警白" % lid)
		free_battle(b)
	PlayerState.telegraph_alt = false
	# 招式色留空 → 取地图色 → 再空取常量
	var a := BossAttackDef.new()
	eq(GameData.telegraph_color(a, "MAP_LEIZE").to_html(false), Color("#F4F1EA").to_html(false), "招式色空取地图色")
	eq(GameData.telegraph_color(a, "").to_html(false), Color(GameData.const_s("TELEGRAPH_DEFAULT_COLOR")).to_html(false), "再空取 TELEGRAPH_DEFAULT_COLOR")
	eq(GameData.const_s("TELEGRAPH_DEFAULT_COLOR"), "#B8382C", "常量=美术规范朱砂")
	eq(GameData.const_s("TELEGRAPH_ALT_COLOR"), "#F4F1EA", "常量=预警白")
	near(Telegraph.outline_color().a, GameData.const_f("TELEGRAPH_OUTLINE_ALPHA"), 0.001, "外描边透明度读表")
	eq(Telegraph.outline_color().to_html(false), Color(GameData.const_s("TELEGRAPH_OUTLINE_COLOR")).to_html(false), "外描边颜色读表")
	# TUT_06 文案来自表
	for r in GameData.tables.tutorial_steps:
		if CsvUtil.s(r, "step_id") == "TUT_06_BOSS":
			eq(TutorialService.hint_text(r), "按空格躲开预警区域", "TUT_06 提示")

func _free_tgs(b: Battle) -> void:
	for tg in b.telegraphs:
		tg.queue_free()
	b.telegraphs.clear()

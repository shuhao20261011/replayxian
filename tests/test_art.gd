extends TestCase
## 第 2/3 批正式美术接入：图集/锚点元数据、命中帧结算、首领技能动画、预警定稿参数

func test_every_enemy_has_frames_and_meta() -> void:
	for d: EnemyDef in GameData.enemies.values():
		check(ResourceLoader.exists(CreatureArt.frames_path(d)), "%s 图集存在 %s" % [d.id, CreatureArt.frames_path(d)])
		check(not CreatureArt.meta(d).is_empty(), "%s 有锚点元数据" % d.id)
		var sf: SpriteFrames = load(CreatureArt.frames_path(d))
		for a in [&"idle", &"move", &"attack", &"hit", &"death"]:
			check(sf.has_animation(a), "%s 有动画 %s" % [d.id, a])
		check(CreatureArt.hit_delay(d) > 0.05, "%s 命中帧延迟 > 0" % d.id)

func test_boss_danger_skills_have_animation() -> void:
	for a: BossAttackDef in GameData.boss_attacks.values():
		if not a.is_danger:
			continue
		var d := GameData.get_enemy(a.boss_id)
		var sf: SpriteFrames = load(CreatureArt.frames_path(d))
		var n := CreatureArt.skill_anim(a.id)
		check(sf.has_animation(n), "%s 有 %s" % [a.id, n])
		if sf.has_animation(n):
			var fps := sf.get_animation_speed(n)
			var w := 0.0
			for i in 4:
				w += sf.get_frame_duration(n, i) / fps
			near(w, CreatureArt.BOSS_SKILL_WINDUP_S, 0.02, "%s 前摇 0~3 合计 0.8s" % a.id)

func test_melee_damage_lands_on_hit_frame() -> void:
	var b := make_battle()
	b.start_run(GameData.get_level("LV_1_1"), Battle.RunMode.CHALLENGE)
	PlayerState.set_auto_battle(false)
	b.player.stats["def"] = 0.0
	var e := spawn_dummy(b, "EN_BAMBOO_IMP", 40.0)
	check(e.anim != null, "竹灵使用 AnimatedSprite2D 图集")
	e.attack_cd = 0.0
	var hp0 := b.player.hp
	var d := CreatureArt.hit_delay(e.def)
	b.tick(DT)
	near(b.player.hp, hp0, 0.01, "起手当帧不掉血")
	sim(b, d - 2 * DT)
	near(b.player.hp, hp0, 0.01, "命中帧前不掉血")
	sim(b, 3 * DT)
	check(b.player.hp < hp0, "命中帧结算伤害")
	free_battle(b)

func test_stun_cancels_windup() -> void:
	var b := make_battle()
	b.start_run(GameData.get_level("LV_1_1"), Battle.RunMode.CHALLENGE)
	PlayerState.set_auto_battle(false)
	var e := spawn_dummy(b, "EN_BAMBOO_IMP", 40.0)
	e.attack_cd = 0.0
	var hp0 := b.player.hp
	b.tick(DT)
	e.stun_t = 1.0
	sim(b, CreatureArt.hit_delay(e.def) + 0.1)
	near(b.player.hp, hp0, 0.01, "起手被眩晕打断不结算")
	free_battle(b)

func test_telegraph_reads_v55_constants() -> void:
	# v5.4/v5.5 表值即美术定稿值；绘制参数全部读表
	var want := {"TELEGRAPH_LINE_PX": 4.0, "TELEGRAPH_DASH_PX": 12.0, "TELEGRAPH_GAP_PX": 12.0, "TELEGRAPH_OUTLINE_ALPHA": 0.7,
		"TELEGRAPH_PROGRESS_FILL_ALPHA": 0.3, "TELEGRAPH_ARENA_LINE_PX": 6.0, "TELEGRAPH_ARENA_OUTLINE_PX": 3.0,
		"TELEGRAPH_ARENA_OUTLINE_ALPHA": 0.7, "TELEGRAPH_ARENA_FILL_ALPHA_CENTER": 0.15, "TELEGRAPH_ARENA_FILL_ALPHA_EDGE": 0.35,
		"TELEGRAPH_ARENA_DASH_PX": 24.0, "TELEGRAPH_ARENA_GAP_PX": 16.0, "TELEGRAPH_BLINK_MIN_ALPHA": 0.45}
	for k in want:
		check(GameData.constants.has(k), "常量表有 %s" % k)
		near(GameData.const_f(k, -1.0), want[k], 0.001, k)
	var tg := Telegraph.new()
	near(tg.line_px(), GameData.const_f("TELEGRAPH_LINE_PX"), 0.001, "普通主线宽读表")
	near(tg.outline_px(), GameData.const_f("TELEGRAPH_OUTLINE_PX"), 0.001, "普通外描边读表")
	near(Telegraph.outline_color().a, GameData.const_f("TELEGRAPH_OUTLINE_ALPHA"), 0.001, "普通外描边透明度读表")
	near(Telegraph.outline_color(true).a, GameData.const_f("TELEGRAPH_ARENA_OUTLINE_ALPHA"), 0.001, "全场外描边透明度读表")
	tg.arena = true
	near(tg.line_px(), GameData.const_f("TELEGRAPH_ARENA_LINE_PX"), 0.001, "全场主线宽读表")
	near(tg.outline_px(), GameData.const_f("TELEGRAPH_ARENA_OUTLINE_PX"), 0.001, "全场外描边读表")
	tg.warn = 0.8
	tg.t = 0.0
	near(tg.flash_alpha(), 1.0, 0.001, "闪烁起点 1.0")
	tg.t = 0.8 / Telegraph.BLINK_COUNT / 2.0
	near(tg.flash_alpha(), GameData.const_f("TELEGRAPH_BLINK_MIN_ALPHA"), 0.001, "闪烁谷值读表")
	tg.free()

func test_yanmo_charge_end_shift() -> void:
	var d := GameData.get_enemy("BOSS_YANMO")
	near(CreatureArt.skill_end_dx(d, &"skill_charge"), 112.0, 0.01, "charge_dx 末值取自美术构建报告")
	eq(CreatureArt.skill_end_dx(d, &"skill_skyfall"), 0.0, "其他技能不位移")
	var m := CreatureArt.meta(d)
	eq([m[0], m[1], m[2], m[3]], [448, 480, 296, 472], "岩魔新格子与锚点")
	var z := CreatureArt.meta(GameData.get_enemy("BOSS_ZHUMEI"))
	eq([z[0], z[1], z[2], z[3]], [736, 416, 352, 394], "竹魅新格子与锚点")
	for k in ["zhumei", "yanmo"]:
		var sf: SpriteFrames = load("res://art/bosses/%s/boss_%s.tres" % [k, k])
		var tx := sf.get_frame_texture(&"idle", 0)
		eq(Vector2i(tx.get_size()), Vector2i(z[0], z[1]) if k == "zhumei" else Vector2i(m[0], m[1]), "%s 帧尺寸与元数据一致" % k)

func test_yanmo_charge_moves_boss_after_anim() -> void:
	var b := make_battle()
	b.start_run(GameData.get_level("LV_3_4"), Battle.RunMode.CHALLENGE)
	var bs := b.debug_force_boss()
	bs.stun_t = 100.0
	bs.facing = -1
	var x0 := bs.position.x
	bs.play_skill(GameData.get_boss_attack("BA_YANMO_CHARGE"))
	bs.anim.animation_finished.emit()
	near(bs.position.x, x0 - 112.0, 0.5, "冲撞动画结束后沿朝向（左）挪 112px，不弹回")
	free_battle(b)

func test_toad_orb_hits_after_source_freed() -> void:
	var b := make_battle()
	b.start_run(GameData.get_level("LV_2_1"), Battle.RunMode.CHALLENGE)
	PlayerState.set_auto_battle(false)
	b.player.stats["def"] = 0.0
	var e := spawn_dummy(b, "EN_THUNDER_TOAD", 300.0)
	b.spawn_enemy_bolt(e, 50.0, 350.0)
	var hp0 := b.player.hp
	e.hp = 1.0
	b.player_hit_enemy(e, 100.0)   # 雷球在飞，雷蟾被击杀并释放
	check(not is_instance_valid(e) or not e.alive, "雷蟾已死")
	sim(b, 1.5)
	check(b.player.hp < hp0, "来源已释放的雷球仍正常命中，不报错")
	free_battle(b)

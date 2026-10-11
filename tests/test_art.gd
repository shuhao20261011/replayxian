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

func test_telegraph_final_defaults() -> void:
	var tg := Telegraph.new()
	near(tg.line_px(), GameData.const_f("TELEGRAPH_LINE_PX", 4.0), 0.001, "普通预警线宽")
	near(GameData.const_f("TELEGRAPH_LINE_PX", 4.0), 4.0, 0.001, "美术定稿 4px")
	near(tg.outline_px(), GameData.const_f("TELEGRAPH_OUTLINE_PX", 2.0), 0.001, "外描边取表")
	tg.arena = true
	near(tg.line_px(), GameData.const_f("TELEGRAPH_ARENA_LINE_PX", 6.0), 0.001, "全场预警线宽 6px")
	near(tg.outline_px(), GameData.const_f("TELEGRAPH_ARENA_OUTLINE_PX", 3.0), 0.001, "全场外描边 3px")
	near(Telegraph.outline_color().a, GameData.const_f("TELEGRAPH_OUTLINE_ALPHA"), 0.001, "外描边透明度以表为准")
	tg.warn = 0.8
	tg.t = 0.0
	near(tg.flash_alpha(), 1.0, 0.001, "闪烁起点 1.0")
	tg.t = 0.8 / GameData.const_f("TELEGRAPH_FLASH_COUNT", 3.0) / 2.0
	near(tg.flash_alpha(), GameData.const_f("TELEGRAPH_FLASH_MIN_ALPHA", 0.45), 0.001, "闪烁谷值 0.45")
	tg.free()

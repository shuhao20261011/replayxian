extends TestCase
## 装备在战斗中的效果（词条、核心橙装特效）、首领最小间距、反伤/反震防御开关（v4 REFLECT_/COUNTER_IGNORE_DEF）

func _battle(level_id: String = "LV_1_1") -> Battle:
	var b := make_battle()
	b.drops_enabled = false
	b.start_run(GameData.get_level(level_id), Battle.RunMode.CHALLENGE)
	return b

func _equip(base_id: String, q: String, affixes: Array = []) -> GearItem:
	var g := GearItem.new()
	g.base_id = base_id; g.quality_id = q
	for a in affixes:
		g.affixes.append({"affix_id": a[0], "value": float(a[1])})
	PlayerState.add_gear(g)
	PlayerState.equip_gear(g.uid)
	return g

func _set_const(k: String, v: String) -> String:
	var old := str(GameData.constants.get(k, ""))
	GameData.constants[k] = v
	return old

func test_boss_keeps_min_spacing_and_fights() -> void:
	for i in PlayerState.slot_count():
		PlayerState.unequip_skill(i)   # 只靠普攻，避免护盾吸收掩盖首领命中
	var b := _battle("LV_1_3")
	b.player.god_mode = true
	var bs := b.debug_force_boss()
	var spacing := GameData.const_f("BOSS_MIN_SPACING_PX")
	check(spacing >= 150.0, "表中 BOSS_MIN_SPACING_PX 生效（%s）" % spacing)
	var hp0 := bs.hp
	var min_d := INF
	var hit_player := [false]   # lambda 按值捕获局部变量，用数组承载
	b.player.god_mode = false
	b.player.max_hp = 1e9; b.player.hp = 1e9
	b.player.hp_changed.connect(func(h: float, _m: float) -> void:
		if h < 1e9:
			hit_player[0] = true)
	for i in 600:
		b.tick(DT)
		for tg in b.telegraphs:
			tg.done = true   # 只测普攻与站位
		min_d = minf(min_d, absf(bs.position.x - b.player.position.x))
	check(min_d >= spacing - 25.0, "自动战斗时首领与主角保持间距（最小 %.0f）" % min_d)
	check(bs.hp < hp0, "主角普攻/技能仍能打到首领")
	check(hit_player[0], "首领普攻仍能打到主角")
	# 玩家手动贴脸：首领后退
	PlayerState.set_auto_battle(false)
	bs.stun_t = 0.0
	b.player.position.x = bs.position.x - 60.0
	sim(b, 1.5)
	check(absf(bs.position.x - b.player.position.x) > 60.0 + 30.0, "贴近时首领后退")
	free_battle(b)

func test_reflect_and_counter_ignore_def_toggles() -> void:
	eq(GameData.const_s("REFLECT_IGNORE_DEF"), "0", "v4 表默认 0（吃防御）")
	eq(GameData.const_s("COUNTER_IGNORE_DEF"), "0", "v4 表默认 0（吃防御）")
	var b := _battle()
	b.player.stats["reflect"] = 0.5
	var e := spawn_dummy(b, "EN_BAMBOO_IMP", 60)
	e.defense = 100.0; e.max_hp = 1e6; e.hp = 1e6; e.stun_t = 100.0
	var cap := GameData.const_f("REFLECT_CAP")
	var refl := minf(0.5, cap)
	var h := e.hp
	b.damage_player(100.0, e, true)
	near(h - e.hp, 100.0 * refl * 0.5, 0.01, "默认：反伤吃防御（DEF100→×0.5）")
	var old := _set_const("REFLECT_IGNORE_DEF", "1")
	h = e.hp
	b.damage_player(100.0, e, true)
	near(h - e.hp, 100.0 * refl, 0.01, "REFLECT_IGNORE_DEF=1：无视防御")
	_set_const("REFLECT_IGNORE_DEF", old)
	# 反震
	b.player.stats["reflect"] = 0.0
	PlayerState.set_auto_battle(false)
	b.controller.request_skill(2)
	sim(b, b.player.cast_release_delay() + DT)
	b.player.shields[0].amount = 1e9
	var coef := b.player.shield_counter_coef()
	var atk := float(b.player.stats.atk)
	var rb := b.player.shield_reflect_bonus()
	h = e.hp
	b.enemy_contact_hit(e, 10.0)
	near(h - e.hp, (atk * coef + 10.0 * minf(rb, cap)) * 0.5, 0.01, "默认：反震+护体反伤都吃防御")
	var old2 := _set_const("COUNTER_IGNORE_DEF", "1")
	sim(b, GameData.const_f("REFLECT_COUNTER_ICD") + 0.05)
	b.player.shields[0].amount = 1e9
	h = e.hp
	b.enemy_contact_hit(e, 10.0)
	near(h - e.hp, atk * coef + 10.0 * minf(rb, cap) * 0.5, 0.01, "COUNTER_IGNORE_DEF=1：反震无视防御，反伤仍吃")
	_set_const("COUNTER_IGNORE_DEF", old2)
	free_battle(b)

func test_affix_effects_in_battle() -> void:
	_equip("EQB_RING_T1", "Q_PURPLE", [["AF_ATK_SPEED", 0.25], ["AF_SHIELD_PCT", 0.2], ["AF_LINGSHI_GAIN", 0.5]])
	var b := _battle()
	PlayerState.set_auto_battle(false)
	var e := spawn_dummy(b, "EN_BAMBOO_IMP", 80)
	e.stun_t = 100.0; e.max_hp = 1e6; e.hp = 1e6
	b.tick(DT)
	near(b.player.attack_cd, GameData.const_f("PLAYER_NORMAL_ATK_INTERVAL") / 1.25 - DT, 0.02, "攻速词条缩短普攻间隔")
	b.controller.request_skill(2)
	sim(b, b.player.cast_release_delay() + DT)
	var lv := GameData.get_skill("SK_GANG_GUARD").level_def(1)
	near(b.player.shield_total(), b.player.max_hp * lv.effect_value * 1.2, 1.0, "护盾强度词条")
	var ls0 := PlayerState.lingshi
	e.hp = 1.0
	b.player_hit_enemy(e, 10.0, {"can_crit": false})
	eq(PlayerState.lingshi - ls0, int(round(e.def.lingshi * e.reward_mult * 1.5)), "灵石获取词条")
	free_battle(b)

func test_chain_affix_and_thunder_core() -> void:
	var b := _battle()
	PlayerState.set_auto_battle(false)
	for i in 8:
		var e := spawn_dummy(b, "EN_BAMBOO_IMP", 120 + i * 40)
		e.stun_t = 100.0; e.max_hp = 1e6; e.hp = 1e6
	var s := GameData.get_skill("SK_THUNDER_STRIKE")
	var base_jumps := s.level_def(1).chain_count if s.level_def(1).chain_count > 0 else s.chain_count
	var count_hit := func() -> int:
		var n := 0
		for e in b.enemies:
			if e.hp < 1e6:
				n += 1
			e.hp = 1e6
		return n
	b.skills._execute(s, s.level_def(1))
	eq(count_hit.call(), base_jumps + 1, "基础连锁")
	_equip("EQB_CORE_THUNDER", "Q_ORANGE")
	(PlayerState.equipped["SLOT_ARTIFACT"] as GearItem).affixes.assign([{"affix_id": "AF_CHAIN_COUNT", "value": 1.0}])
	b.refresh_player_stats()
	b.skills._execute(s, s.level_def(1))
	var add := int(GameData.orange_effects["OE_THUNDER_CORE"].p("chain_count_add"))
	eq(count_hit.call(), base_jumps + 1 + add + 1, "雷核+2 与连锁词条+1")
	# 击杀返还
	b.skills.cds[1] = 5.0
	var victim: Enemy = b.enemies[0]
	victim.hp = 1.0
	b.player_hit_enemy(victim, 10.0, {"gongfa_id": "GF_THUNDER", "can_crit": false})
	near(b.skills.cds[1], 5.0 - GameData.orange_effects["OE_THUNDER_CORE"].p("kill_cd_refund_s"), 0.001, "雷法击杀返还雷法冷却")
	free_battle(b)

func test_sword_core_effects() -> void:
	var b := _battle()
	b.player.stats["crit_rate"] = 0.0
	var e := spawn_dummy(b, "EN_BAMBOO_IMP", 200)
	e.stun_t = 100.0; e.max_hp = 1e6; e.hp = 1e6; e.defense = 0.0
	var count_proj := func() -> int:
		var n := 0
		for fx in b.effects_root.get_children():
			if fx is SkillFx.Projectile:
				n += 1
		return n
	b.visual_fx = true
	b.player_hit_enemy(e, 1.0, {"gongfa_id": "GF_SWORD", "source": "skill"})
	eq(count_proj.call(), 0, "无剑核/被动时不追加")
	_equip("EQB_CORE_SWORD", "Q_ORANGE")
	b.refresh_player_stats()
	b.player.stats["crit_rate"] = 1.0
	b.player_hit_enemy(e, 1.0, {"gongfa_id": "GF_SWORD", "source": "skill"})
	eq(count_proj.call(), 1, "剑核：暴击必定追加飞剑")
	near(b._extra_sword_coef(), GameData.orange_effects["OE_SWORD_CORE"].p("extra_sword_coef"), 0.0001, "追加系数取表")
	# 对首领增伤
	b.player.stats["crit_rate"] = 0.0
	var bs := b.debug_force_boss()
	bs.defense = 0.0; bs.max_hp = 1e9; bs.hp = 1e9; bs.stun_t = 100.0
	var h := bs.hp
	b.player_hit_enemy(bs, 1.0, {"can_crit": false})
	near(h - bs.hp, float(b.player.stats.atk) * (1.0 + GameData.orange_effects["OE_SWORD_CORE"].p("boss_dmg_pct")), 0.01, "剑核对首领+15%")
	b.visual_fx = false
	free_battle(b)

func test_gang_core_effects() -> void:
	_equip("EQB_CORE_GANG", "Q_ORANGE")
	var b := _battle()
	PlayerState.set_auto_battle(false)
	var oe: OrangeEffectDef = GameData.orange_effects["OE_GANG_CORE"]
	var e := spawn_dummy(b, "EN_BAMBOO_IMP", 60)
	e.stun_t = 100.0; e.max_hp = 1e6; e.hp = 1e6; e.defense = 0.0
	b.player.stats["reflect"] = 0.0
	var h := e.hp
	b.damage_player(100.0, e, true)
	near(h - e.hp, 0.0, 0.01, "无护盾时金刚核心不加反伤")
	b.controller.request_skill(2)
	sim(b, b.player.cast_release_delay() + DT)
	var smax: float = b.player.shields[0].max
	var rb := b.player.shield_reflect_bonus()
	b.reflect_icd = 99.0   # 排除反震
	h = e.hp
	b.damage_player(10.0, e, true)
	near(h - e.hp, 10.0 * minf(rb + oe.p("reflect_add_with_shield"), GameData.const_f("REFLECT_CAP")), 0.01, "有护盾时反伤+25%")
	h = e.hp
	b.damage_player(smax * 10.0, null, false)   # 打破护盾
	eq(b.gang_bursts, 1, "护盾被击破触发冲击")
	near(h - e.hp, smax * oe.p("shield_break_burst_pct"), 0.5, "冲击=护盾上限×80%")
	b.player.hp = b.player.max_hp
	b.skills.cds[2] = 0.0
	b.controller.request_skill(2)
	sim(b, b.player.cast_release_delay() + DT)
	b.damage_player(b.player.shield_total() + 1.0, null, false)
	eq(b.gang_bursts, 1, "内置冷却内不再触发")
	free_battle(b)

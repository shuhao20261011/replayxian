class_name Battle
extends Node2D
## 战斗主场景：刷怪 → 首领 → 胜利/失败 → 挂机 循环的状态机，以及伤害结算。
## 战斗状态只存在这里；成长数据在 PlayerState（Autoload）；UI 通过信号更新。
## 所有逻辑在 tick(delta) 中执行（_physics_process 调用；测试可直接调用 tick 做确定性模拟）。

signal run_started(level: LevelDef, mode: int)
signal phase_changed(phase: int)
signal wave_changed(index: int, total: int)
signal boss_spawned(boss: Boss)
signal boss_timer_changed(seconds_left: float)
signal run_finished(result: String, level_id: String, first_clear: bool)
signal banner(text: String)
signal telegraph_started(tg: Telegraph)
signal loot_dropped(entries: Array)   # [{text, color, beam}]

enum Phase { NONE, WALK, WAVE, BOSS_INTRO, BOSS, VICTORY, DEFEAT }
enum RunMode { CHALLENGE, FARM, FARM_NORMALS }

const ENEMY_SCENE := preload("res://scenes/battle/enemy.tscn")
const BOSS_SCENE := preload("res://scenes/battle/boss.tscn")

@export var auto_tick := true
@export var autostart := true
@export var rng_seed := 0
@export var visual_fx := true

@onready var world: Node2D = $World
@onready var enemies_root: Node2D = $World/Enemies
@onready var effects_root: Node2D = $World/Effects
@onready var telegraph_root: Node2D = $World/Telegraphs
@onready var camera: Camera2D = $World/Camera2D
@onready var player: Player = $World/Player
@onready var controller: PlayerController = $PlayerController
@onready var background: Node2D = $Background

var skills: SkillSystem
var tutorial: TutorialService
var rng := RandomNumberGenerator.new()
var ground_y := 585.0
var level: LevelDef
var mode := RunMode.FARM_NORMALS
var phase := Phase.NONE
var phase_time := 0.0
var walk_duration := 1.0
var wave_index := 0
var boss_time_left := 0.0
var boss: Boss
var enemies: Array[Enemy] = []
var pending_spawns: Array[Dictionary] = []
var telegraphs: Array[Telegraph] = []
var sim_time := 0.0
var runs_completed := 0
var last_result := ""
var left_bound := -INF
var reflect_icd := 0.0
var time_scale := 1.0
var slowmo_left := 0.0
var use_alt_telegraph_color := false
var _bg_map_id := ""
var run_auto_at_fail := false
var last_danger_resolve_t := -1.0   # 上一次危险招式判定的战斗时刻（首领危险招式间隔保护用）
var retreat_active := false   # 因自动失败回退而挂在较低关卡；标记清除后回到最高已通关关卡（BUG-003）
var _sky_fill: ColorRect      # 非16:9窗口时补天空（BUG-007）
var player_initiated := false   # 本轮是否由玩家点【挑战】发起（v4 manual_clear 定义；中途切自动不影响）
var counter_hits := 0     # 调试/测试：护体反震触发次数
var reflect_hits := 0     # 调试/测试：反伤触发次数
var gang_burst_icd := 0.0  # 金刚核心护盾破碎冲击的内置冷却
var gang_bursts := 0       # 调试/测试：金刚核心冲击次数
var drops_enabled := true  # 测试可关闭掉落
var last_loot: Array = []  # 调试/测试：最近一次掉落/首通显示条目

## BUG-015：地面预警画在 HUD 之上的跟随视口图层（layer 11 > HUD 10），下沿与圆的下半圈不再被底栏挡住；
## 打开养成面板时隐藏（面板也在 HUD 层）。全场预警留在世界层（底色不染 HUD），描边内收到 HUD 让出的可见战场区。
var telegraph_over_layer: CanvasLayer
var telegraph_over_root: Node2D
## HUD 每帧上报的可见战场区（屏幕坐标：顶栏下沿～底栏上沿）；空 = 整个视口
var hud_safe_rect := Rect2()

func safe_view_rect() -> Rect2:
	var vr := view_rect()
	if hud_safe_rect.size.x <= 0.0 or hud_safe_rect.size.y <= 0.0:
		return vr
	return Rect2(vr.position + hud_safe_rect.position, hud_safe_rect.size)

func set_telegraph_overlay_visible(v: bool) -> void:
	if telegraph_over_layer:
		telegraph_over_layer.visible = v

func _ready() -> void:
	telegraph_over_layer = CanvasLayer.new()
	telegraph_over_layer.name = "TelegraphOverlay"
	telegraph_over_layer.layer = 11
	telegraph_over_layer.follow_viewport_enabled = true
	add_child(telegraph_over_layer)
	telegraph_over_root = Node2D.new()
	telegraph_over_root.name = "Telegraphs"
	telegraph_over_layer.add_child(telegraph_over_root)
	ground_y = GameData.const_f("GROUND_Y", 585.0)
	rng.seed = rng_seed if rng_seed != 0 else int(Time.get_ticks_usec())
	skills = SkillSystem.new(self)
	tutorial = TutorialService.new(self)
	player.battle = self
	controller.battle = self
	player.position = Vector2(0, ground_y)
	if autostart:
		start_default_run()

func start_default_run() -> void:
	var nxt := PlayerState.next_challenge_level()
	var first := GameData.first_level()
	if nxt != null and nxt == first and not PlayerState.is_cleared(first.id):
		start_run(first, RunMode.CHALLENGE)   # 新存档：直接挑战第一关（新手流程）
	else:
		var l := PlayerState.last_cleared_level()
		start_run(l if l else first, RunMode.FARM if l else RunMode.FARM_NORMALS)

# ---------- 时钟 ----------
func _physics_process(delta: float) -> void:
	if auto_tick:
		tick(delta)

func is_battle_paused() -> bool:
	return is_inside_tree() and get_tree().paused

func tick(delta: float) -> void:
	if is_battle_paused() or level == null:
		return
	var d := delta * time_scale
	if slowmo_left > 0.0:
		slowmo_left -= d
		if slowmo_left <= 0.0:
			time_scale = 1.0
	sim_time += d
	reflect_icd = maxf(reflect_icd - d, 0.0)
	gang_burst_icd = maxf(gang_burst_icd - d, 0.0)
	controller.update(d)
	player.step(d)
	skills.step(d)
	# BUG-014：先取快照——首领本帧起手新建的预警不在同一帧推进，从下一帧开始计时（0.8 秒 = 恰好显示 48 帧）
	var tg_snapshot := telegraphs.duplicate()
	for e in enemies.duplicate():
		if is_instance_valid(e) and e.alive:
			e.step(d)
	for tg in tg_snapshot:
		if not is_instance_valid(tg) or not telegraphs.has(tg):
			continue
		tg.step(d)
		if tg.done:
			telegraphs.erase(tg)
			_free_node(tg)
	for fx in effects_root.get_children():
		if fx is SkillFx.FxBase:
			var f := fx as SkillFx.FxBase
			if not f.done:
				f.step(d)
			if f.done:
				_free_node(f)
	_process_spawns()
	_update_phase(d)
	left_bound = maxf(left_bound, player.position.x - GameData.const_f("PLAYER_BACKTRACK_PX", 600.0))
	_update_camera()

## 镜头：地面线固定在距屏幕底边 GROUND_SCREEN_MARGIN 处（默认135，1280×720 时镜头 y=360），
## 4:3/5:4 等更高的窗口向上多显示天空，由 _sky_fill 补色（BUG-007）
func _update_camera() -> void:
	var vs := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	camera.position = Vector2(player.position.x + 200.0, ground_y + GameData.const_f("GROUND_SCREEN_MARGIN", 135.0) - vs.y / 2.0)
	if _sky_fill:
		_sky_fill.position = Vector2(camera.position.x - vs.x, camera.position.y - vs.y)
		_sky_fill.size = Vector2(vs.x * 2.0, vs.y)

## 当前可见世界区域
func view_rect() -> Rect2:
	var vs := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	return Rect2(camera.position - vs / 2.0, vs)

func start_slowmo(scale: float, duration_game_s: float) -> void:
	time_scale = clampf(scale, 0.0, 1.0)
	slowmo_left = duration_game_s

func stop_slowmo() -> void:
	time_scale = 1.0
	slowmo_left = 0.0

func _free_node(n: Node) -> void:
	if n.get_parent():
		n.get_parent().remove_child(n)
	n.queue_free()

# ---------- 关卡流程 ----------
func start_run(l: LevelDef, m: int) -> void:
	_clear_field()
	player_initiated = false
	level = l
	mode = m
	wave_index = 0
	boss = null
	boss_time_left = 0.0
	last_danger_resolve_t = -1.0
	stop_slowmo()
	player.position.x = 0.0   # BUG-009：每轮把世界原点归零，避免坐标无界增长（浮点精度）
	player.reset_for_run(PlayerState.combat_stats())
	skills.reset()
	gang_burst_icd = 0.0
	left_bound = player.position.x - GameData.const_f("PLAYER_BACKTRACK_PX", 600.0)
	_setup_background()
	walk_duration = GameData.const_f("RUN_START_WALK_TIME", 1.0)
	_enter(Phase.WALK)
	run_started.emit(level, mode)

## 养成变化后刷新本局属性（保持当前生命比例；护盾、冷却不变）
func refresh_player_stats() -> void:
	var ratio := player.hp / maxf(player.max_hp, 1.0)
	player.stats = PlayerState.combat_stats()
	player.max_hp = float(player.stats.get("max_hp", player.max_hp))
	if player.alive:
		player.hp = player.max_hp * ratio
	player.hp_changed.emit(player.hp, player.max_hp)

func challenge(level_id: String) -> bool:
	if not PlayerState.can_challenge(level_id):
		return false
	start_run(GameData.get_level(level_id), RunMode.CHALLENGE)
	player_initiated = true
	return true

func _clear_field() -> void:
	tutorial.cancel_active()   # BUG-002：战斗被清场时撤销进行中的引导
	# BUG-001：释放 Enemies 下全部节点（包括已移出 enemies 数组的死亡首领）
	for e in enemies_root.get_children():
		_free_node(e)
	enemies.clear()
	pending_spawns.clear()
	for tg in telegraphs:
		_free_node(tg)
	telegraphs.clear()
	for fx in effects_root.get_children():
		_free_node(fx)

func _enter(p: int) -> void:
	phase = p
	phase_time = 0.0
	phase_changed.emit(p)

func _update_phase(delta: float) -> void:
	phase_time += delta
	if phase != Phase.VICTORY and phase != Phase.DEFEAT and not player.alive:
		_finish("defeat")
		return
	match phase:
		Phase.WALK:
			if phase_time >= walk_duration:
				_begin_wave(wave_index + 1)
		Phase.WAVE:
			if pending_spawns.is_empty() and enemies.is_empty():
				if wave_index < level.wave_count:
					walk_duration = GameData.const_f("WAVE_ENTER_WALK_TIME", 3.0)
					_enter(Phase.WALK)
				elif mode == RunMode.FARM_NORMALS:
					_finish("loop")
				else:
					_enter(Phase.BOSS_INTRO)
		Phase.BOSS_INTRO:
			if phase_time >= GameData.const_f("BOSS_INTRO_TIME", 3.0):
				_spawn_boss()
				boss_time_left = level.boss_time_limit_s if level.boss_time_limit_s > 0.0 else GameData.const_f("BOSS_TIME_LIMIT", 60.0)
				_enter(Phase.BOSS)
		Phase.BOSS:
			boss_time_left -= delta
			boss_timer_changed.emit(boss_time_left)
			if boss == null or not boss.alive:
				_finish("victory")
			elif boss_time_left <= 0.0:
				_finish("timeout")
		Phase.VICTORY, Phase.DEFEAT:
			if phase_time >= GameData.const_f("RESULT_SHOW_TIME", 2.0):
				_next_run()

func _begin_wave(i: int) -> void:
	wave_index = i
	var base_x := player.position.x + GameData.const_f("SPAWN_DISTANCE_PX", 760.0)
	for w in level.wave_entries(i):
		var spacing := 45.0 if w.formation == "cluster" else 110.0
		for k in w.count:
			pending_spawns.append({"t": sim_time + w.spawn_delay_s + k * 0.12, "enemy_id": w.enemy_id, "x": base_x + k * spacing})
	_enter(Phase.WAVE)
	wave_changed.emit(i, level.wave_count)

func _process_spawns() -> void:
	if pending_spawns.is_empty():
		return
	for s in pending_spawns.duplicate():
		if sim_time >= float(s.t):
			pending_spawns.erase(s)
			var d := GameData.get_enemy(s.enemy_id)
			if d == null:
				continue
			# 后到的一组从当前视野右侧外进场
			var x := maxf(float(s.x), player.position.x + 500.0)
			spawn_enemy(d, x)

func spawn_enemy(d: EnemyDef, x: float) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	enemies_root.add_child(e)
	e.position = Vector2(x, ground_y)
	e.setup(d, level.enemy_hp_mult, level.enemy_atk_mult, self)
	e.died.connect(_on_enemy_died)
	enemies.append(e)
	return e

func _spawn_boss() -> void:
	var d := GameData.get_enemy(level.boss_id)
	var b: Boss = BOSS_SCENE.instantiate()
	enemies_root.add_child(b)
	b.position = Vector2(player.position.x + GameData.const_f("BOSS_SPAWN_DISTANCE_PX", 560.0), ground_y)
	b.setup_boss(d, level, self)
	b.died.connect(_on_enemy_died)
	enemies.append(b)
	boss = b
	boss_spawned.emit(b)

func _on_enemy_died(e: Enemy) -> void:
	enemies.erase(e)
	var ls := int(round(e.def.lingshi * e.reward_mult * (1.0 + float(player.stats.get("lingshi_gain_pct", 0.0)))))
	var xw := int(round(e.def.xiuwei * e.reward_mult))
	PlayerState.add_rewards(ls, xw)
	if visual_fx:
		float_text(e.position + Vector2(0, -170), UiText.t("FLOAT_LINGSHI", {"value": ls}), Color("#D9A441"), 18)
	_on_kill_orange(e)
	if drops_enabled and level:
		_show_loot(LootSystem.apply(LootSystem.roll_kill(level, e.is_boss(), rng)), e.position)
	if e != boss:
		if visual_fx and e.anim:
			CreatureArt.spawn_death(effects_root, e.def, e.position, e.facing)
		_free_node(e)
	else:
		# 首领死亡：结算展示期间淡出，下一轮 _clear_field 释放（BUG-001）
		(e as Boss).play_death()
		if visual_fx and e.is_inside_tree():
			var tw := e.create_tween()
			tw.tween_property(e, "modulate:a", 0.0, GameData.const_f("RESULT_SHOW_TIME", 2.0) * 0.8)
		else:
			e.modulate = Color(1, 1, 1, 0.0)

func _finish(result: String) -> void:
	last_result = result
	runs_completed += 1
	var first_clear := false
	if result == "victory":
		first_clear = PlayerState.mark_cleared(level.id)
		if first_clear and drops_enabled:
			_show_loot(LootSystem.apply(LootSystem.roll_first_clear(level, rng)), player.position + Vector2(160, 0))
		PlayerState.record_level_success(level.id, player_initiated)
	tutorial.cancel_active()   # BUG-002：预警期间结算，收起引导并恢复速度
	stop_slowmo()
	for tg in telegraphs:
		_free_node(tg)
	telegraphs.clear()
	run_auto_at_fail = PlayerState.auto_battle
	run_finished.emit(result, level.id, first_clear)
	match result:
		"victory":
			banner.emit(UiText.t("BANNER_FIRST_CLEAR" if first_clear else "BANNER_CLEAR", {"level_name": level.name}))
			_enter(Phase.VICTORY)
		"loop":
			_next_run()
		_:
			banner.emit(UiText.t("BANNER_TIMEOUT" if result == "timeout" else "BANNER_DEFEAT"))
			_enter(Phase.DEFEAT)

## 胜利 → 继续挂机刷本关；普通怪循环 → 继续循环；失败 → 计划3.1：返回最近已通关关卡挂机，未通关时刷第一关普通怪。
## v3：自动模式失败计数，达到 AUTO_FAIL_RETREAT_COUNT 把该关标记为不稳定，回退到“已通关且未被标记”的最高关卡。
func _next_run() -> void:
	match last_result:
		"victory":
			# BUG-003：回退挂机中，若标记已被清除（换装/升级/突破等），回到“已通关且未标记”的最高关卡
			var target := level
			if retreat_active:
				var best := PlayerState.auto_retreat_level()
				if best and best != level:
					target = best
					banner.emit(UiText.t("BANNER_RETREAT_RETURN", {"level_name": best.name}))
				if PlayerState.unstable_levels.is_empty():
					retreat_active = false
			start_run(target, RunMode.FARM)
		"loop":
			start_run(level, RunMode.FARM_NORMALS)
		_:
			var target: LevelDef = PlayerState.last_cleared_level()
			# BUG-010：未通关时刷普通怪（FARM_NORMALS）阵亡不计自动失败、不打标记
			if run_auto_at_fail and mode != RunMode.FARM_NORMALS:
				var failed := level
				if PlayerState.record_auto_failure(failed.id):
					target = PlayerState.auto_retreat_level()
					retreat_active = true
					var to_name := target.name if target else UiText.t("TEXT_FALLBACK_FARM", {"level_name": GameData.first_level().name})
					banner.emit(UiText.t("BANNER_RETREAT", {"failed_level_name": failed.name, "to_level_name": to_name}) + "\n" + UiText.t("BANNER_RETREAT_TIP"))
			if target:
				start_run(target, RunMode.FARM)
			else:
				start_run(GameData.first_level(), RunMode.FARM_NORMALS)

func combat_active() -> bool:
	return phase == Phase.WAVE or phase == Phase.BOSS or phase == Phase.WALK or phase == Phase.BOSS_INTRO

func should_advance() -> bool:
	return phase == Phase.WALK or phase == Phase.BOSS_INTRO or phase == Phase.WAVE

func has_engaged_enemies() -> bool:
	if boss != null and boss.alive:
		return true
	return nearest_enemy(player.position.x, GameData.const_f("AUTO_ENGAGE_RANGE_PX", 450.0)) != null

## 调试/测试：跳过波次直接进入首领战
func debug_force_boss() -> Boss:
	for e in enemies:
		_free_node(e)
	enemies.clear()
	pending_spawns.clear()
	wave_index = level.wave_count
	_spawn_boss()
	boss_time_left = level.boss_time_limit_s
	_enter(Phase.BOSS)
	return boss

# ---------- 查询 ----------
func nearest_enemy(x: float, max_range: float = INF) -> Enemy:
	var best: Enemy = null
	var bd := INF
	for e in enemies:
		if e.alive:
			var d := absf(e.position.x - x)
			d = maxf(d - e.body_extent(), 0.0)
			if d <= max_range + Player.HALF_WIDTH and d < bd:
				bd = d; best = e
	return best

## [x0,x1] 区间内存活敌人，按与玩家距离排序
func enemies_in_x_range(x0: float, x1: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in enemies:
		var ext := 20.0 + e.body_extent()
		if e.alive and e.position.x + ext >= x0 and e.position.x - ext <= x1:
			out.append(e)
	var px := player.position.x
	out.sort_custom(func(a: Enemy, b: Enemy) -> bool: return absf(a.position.x - px) < absf(b.position.x - px))
	return out

func view_half_width() -> float:
	return get_viewport_rect().size.x / 2.0 if is_inside_tree() else 640.0

func camera_center_x() -> float:
	return camera.position.x

# ---------- 伤害结算 ----------
## 玩家对敌人：攻击×系数×(1+流派增伤)×(1+对首领增伤)×暴击，再按目标防御减伤（Enemy.take_damage）
func player_hit_enemy(e: Enemy, coef: float, opts: Dictionary = {}) -> float:
	if e == null or not e.alive:
		return 0.0
	var st := player.stats
	var raw := float(st.get("atk", 20.0)) * coef
	var gf: String = opts.get("gongfa_id", "")
	if gf == "GF_THUNDER":
		raw *= 1.0 + float(st.get("thunder_dmg_pct", 0.0))
	elif gf == "GF_SWORD":
		raw *= 1.0 + float(st.get("sword_dmg_pct", 0.0))
	if e.is_boss():
		raw *= 1.0 + float(opts.get("boss_bonus", 0.0)) + _orange_p("OE_SWORD_CORE", "boss_dmg_pct")
	var crit := false
	if opts.get("can_crit", true):
		crit = rng.randf() < float(st.get("crit_rate", 0.05))
		if crit:
			raw *= float(st.get("crit_dmg", 1.5))
	if gf != "":
		e.last_hit_gongfa = gf
	var dealt := e.take_damage(raw, crit)
	if visual_fx and gf != "":
		var body := e.position + Vector2(0, -CreatureArt.body_height(e.def) * 0.5)
		match str(opts.get("fx", "")) if opts.has("fx") else ("sword_hit" if gf == "GF_SWORD" else ("thunder_strike" if gf == "GF_THUNDER" else "")):
			"sword_hit": spawn_fx(&"sword_hit", body)
			"thunder_strike": spawn_fx(&"thunder_strike", Vector2(e.position.x, ground_y))
			"thunder_ground": spawn_fx(&"thunder_ground", Vector2(e.position.x, ground_y))
	if opts.has("effect") and e.alive:
		var ef: Array = opts.effect
		e.apply_effect(ef[0], ef[1], ef[2])
	# 追加飞剑：剑心通明被动 + 词条 + 剑核（暴击必定追加）。飞剑诀主动技能命中触发，追加的不再触发追加。
	if gf == "GF_SWORD" and opts.get("source", "") == "skill" and not opts.get("is_extra", false):
		var extra := float(st.get("extra_sword_chance", 0.0)) + _orange_p("OE_SWORD_CORE", "extra_sword_chance")
		var forced := crit and has_orange("OE_SWORD_CORE")   # 剑核：暴击必定追加（表中无参数，按 desc 实现）
		if forced or (extra > 0.0 and rng.randf() < extra):
			var o := opts.duplicate(); o["is_extra"] = true
			spawn_projectile(600.0, 40.0, _extra_sword_coef(), o, 0.05, 1, Color("#7FE0FF"))
	return dealt

## 追加飞剑系数：被动 damage_coef 与剑核 extra_sword_coef 取大，均无时 0.8
func _extra_sword_coef() -> float:
	var c := 0.0
	var ps := GameData.get_skill(PlayerState.passive_skill)
	if ps and ps.effect_type == "extra_sword_chance" and ps.damage_coef > 0.0:
		c = ps.damage_coef
	c = maxf(c, _orange_p("OE_SWORD_CORE", "extra_sword_coef"))
	return c if c > 0.0 else 0.8

## 已装备核心橙装特效的参数（未装备返回 0）
func _orange_p(effect_id: String, key: String) -> float:
	if not (player.stats.get("orange", []) as Array).has(effect_id):
		return 0.0
	var oe := GameData.orange_effects.get(effect_id) as OrangeEffectDef
	return oe.p(key) if oe else 0.0

func has_orange(effect_id: String) -> bool:
	return (player.stats.get("orange", []) as Array).has(effect_id)

## 雷核：雷法技能击杀返还雷法冷却
func _on_kill_orange(e: Enemy) -> void:
	if e.last_hit_gongfa == "GF_THUNDER" and has_orange("OE_THUNDER_CORE"):
		skills.refund_gongfa_cooldown("GF_THUNDER", _orange_p("OE_THUNDER_CORE", "kill_cd_refund_s"))

func _show_loot(entries: Array, pos: Vector2) -> void:
	if entries.is_empty():
		return
	last_loot = entries
	loot_dropped.emit(entries)
	if visual_fx:
		var i := 0
		for en in entries:
			spawn_loot_beam(pos + Vector2(i * 46 - 40, 0), en.color, str(en.beam), str(en.text), int(en.get("quality", 0)))
			i += 1

## 敌人近战/接触攻击（触发反伤与护体反震）
func enemy_contact_hit(e: Enemy, raw: float) -> float:
	return damage_player(raw, e, true)

## 对玩家造成伤害。
## - 闪避免伤期间无伤。
## - atk 类：按防御减伤（DEF/(DEF+DEF_CONST)）与减伤 buff，护盾先吸收。
## - true_damage（true_maxhp）：无视防御与一切减伤，先扣护盾，不触发反伤/反震。
## - 反伤只对近战/接触伤害生效：减伤前伤害×min(反伤, REFLECT_CAP)，不暴击；护体护盾期间每次接触攻击另有反震（REFLECT_COUNTER_ICD 内置间隔）。
func damage_player(raw: float, attacker: Enemy, contact: bool, true_damage: bool = false) -> float:
	if not player.alive or phase == Phase.VICTORY or phase == Phase.DEFEAT:
		return 0.0
	if player.is_invulnerable():
		if visual_fx:
			float_text(player.position + Vector2(0, -190), UiText.t("FLOAT_DODGE"), Color("#F6F2E8"), 20)
		return 0.0
	var dmg := raw
	if not true_damage:
		var d := float(player.stats.get("def", 0.0))
		dmg = raw * (1.0 - d / (d + GameData.const_f("DEF_CONST", 100.0)))
		dmg *= 1.0 - player.damage_reduce()
	var counter_coef := player.shield_counter_coef()   # 受击前的护体状态
	var reflect_bonus := player.shield_reflect_bonus()
	var after := player.absorb(dmg)
	player.apply_hp_loss(after)
	if visual_fx and dmg > 0.0:
		float_text(player.position + Vector2(rng.randf_range(-20, 20), -180), "-%d" % int(round(dmg)), Color("#C9433A"), 20)
	if contact and not true_damage and attacker != null and is_instance_valid(attacker) and attacker.alive:
		if player.shield_total() > 0.0 or reflect_bonus > 0.0:
			reflect_bonus += _orange_p("OE_GANG_CORE", "reflect_add_with_shield")
		var refl := minf(float(player.stats.get("reflect", 0.0)) + reflect_bonus, GameData.const_f("REFLECT_CAP", 0.6))
		if refl > 0.0:
			reflect_hits += 1
			# REFLECT_IGNORE_DEF：反伤是否无视敌人防御（默认 false = 仍按敌人防御减伤）
			attacker.take_damage(raw * refl, false, "reflect", GameData.const_b("REFLECT_IGNORE_DEF", false))
		if counter_coef > 0.0 and reflect_icd <= 0.0 and attacker.alive:
			reflect_icd = GameData.const_f("REFLECT_COUNTER_ICD", 0.8)
			counter_hits += 1
			attacker.take_damage(float(player.stats.get("atk", 20.0)) * counter_coef, false, "counter", GameData.const_b("COUNTER_IGNORE_DEF", false))
	return dmg

## 护盾结束：金刚不坏爆发（攻击×系数 + 已吸收量×burst_absorb_pct，以自身为中心）
func on_shield_ended(s: Dictionary, broken: bool) -> void:
	# 金刚核心：护盾破碎时冲击（护盾值×shield_break_burst_pct，内置冷却）
	if broken and has_orange("OE_GANG_CORE") and gang_burst_icd <= 0.0:
		var oe := GameData.orange_effects.get("OE_GANG_CORE") as OrangeEffectDef
		gang_burst_icd = oe.internal_cd_s
		gang_bursts += 1
		var rr := oe.p("burst_radius_px")
		var amt := float(s.get("max", s.get("absorbed", 0.0))) * oe.p("shield_break_burst_pct")   # 护盾上限×80%
		for e in enemies_in_x_range(player.position.x - rr, player.position.x + rr):
			e.take_damage(amt, false, "burst")
		spawn_flash("circle", PackedVector2Array([player.position + Vector2(0, -60)]), Color("#FF9F43"), rr)
	if s.has("burst_coef"):
		var r := float(s.get("burst_radius", 200.0))
		var raw := float(player.stats.get("atk", 20.0)) * float(s.burst_coef) + float(s.absorbed) * float(s.get("burst_absorb_pct", 0.0))
		for e in enemies_in_x_range(player.position.x - r, player.position.x + r):
			var crit := rng.randf() < float(player.stats.get("crit_rate", 0.05))
			e.take_damage(raw * (float(player.stats.get("crit_dmg", 1.5)) if crit else 1.0), crit)
		spawn_flash("circle", PackedVector2Array([player.position + Vector2(0, -60)]), Color("#F2C14E"), r)

# ---------- 首领招式 ----------
func start_boss_attack(b: Boss, a: BossAttackDef) -> void:
	b.play_skill(a)
	for i in a.count:
		var tg := Telegraph.new()
		(telegraph_root if a.anchor == "arena" else telegraph_over_root).add_child(tg)
		tg.setup(self, b, a, i)
		telegraphs.append(tg)
		if i == 0:
			telegraph_started.emit(tg)
			tutorial.on_telegraph_started(tg)

func has_active_danger_telegraph() -> bool:
	return not telegraphs.is_empty()

func is_true_damage_telegraph_active() -> bool:
	for tg in telegraphs:
		if tg.attack.is_true_damage():
			return true
	return false

func time_until_next_true_damage_attack() -> float:
	if boss == null or not boss.alive:
		return INF   # 首领未登场：不预留
	var best := INF
	for a in boss.true_damage_attacks():
		best = minf(best, boss.time_until(a.id))
	return best

## 预警结束判定：返回是否命中玩家
func resolve_telegraph(tg: Telegraph) -> bool:
	if tg.attack.is_danger:
		last_danger_resolve_t = sim_time
	if visual_fx and tg.attack.id == "BA_ZHUMEI_THORN":
		spawn_thorns(tg.position.x + tg.x0, tg.position.x + tg.x1)
	var dodged := player.in_dodge_iframes()
	var inside := tg.player_inside()
	var hit := inside and not player.is_invulnerable()
	if hit and tg.boss != null:
		var a := tg.attack
		if a.is_true_damage():
			damage_player(player.max_hp * a.damage_maxhp_pct, tg.boss, false, true)
		else:
			damage_player(tg.boss.atk * a.damage_coef, tg.boss, false, false)
	elif inside and dodged and visual_fx:
		float_text(player.position + Vector2(0, -190), UiText.t("FLOAT_DODGE"), Color("#F6F2E8"), 22)
	tutorial.on_telegraph_resolved(tg, inside and dodged)
	return hit

# ---------- 表现 ----------
func float_text(pos: Vector2, text: String, color: Color, size: int = 20) -> void:
	if not visual_fx:
		return
	var ft := SkillFx.FloatText.new()
	ft.battle = self
	ft.text = text; ft.color = color; ft.size = size
	ft.position = pos
	effects_root.add_child(ft)

func show_damage_number(e: Enemy, dmg: float, crit: bool, tag: String) -> void:
	if not visual_fx:
		return
	var col := Color("#FFD36B") if crit else (Color("#F2C14E") if tag != "" else Color.WHITE)
	var h := 120.0 if not e.is_boss() else 280.0
	float_text(e.position + Vector2(rng.randf_range(-25, 25), -h), UiText.t("FLOAT_CRIT", {"value": round(dmg)}) if crit else "-%d" % int(round(dmg)), col, 30 if crit else 22)

## 掉落光柱 + 名称（颜色/样式来自 qualities.beam）
const LOOT_BEAM_SCENE := "res://art/fx/loot_beam.tscn"

## 掉落光柱：正式件 loot_beam.tscn 只设 quality（1~5，颜色/高度/粒子/橙装放射光由它自己按 beam_color 配）；
## 停留 LOOT_BEAM_TIME 秒后淡出。缺件时退回程序画线。
func spawn_loot_beam(pos: Vector2, color: Color, beam: String, text: String, quality: int = 0) -> void:
	if not visual_fx:
		return
	if quality > 0 and ResourceLoader.exists(LOOT_BEAM_SCENE):
		var lb: Node2D = load(LOOT_BEAM_SCENE).instantiate()
		lb.position = Vector2(pos.x, ground_y)
		lb.set("quality", quality)
		effects_root.add_child(lb)
		var tw := lb.create_tween()
		tw.tween_interval(GameData.const_f("LOOT_BEAM_TIME", 1.6))
		tw.tween_property(lb, "modulate:a", 0.0, 0.4)
		tw.tween_callback(lb.queue_free)
	elif beam != "" and beam != "none":
		var h := 260.0 if (beam.begins_with("tall") or beam == "book") else 160.0
		spawn_flash("line", PackedVector2Array([pos, pos + Vector2(0, -h)]), Color(color, 0.85))
	float_text(pos + Vector2(0, -120), text, color, 16)

const FX_FRAMES := "res://art/fx/fx_frames.tres"
## fx_frames.tres 的锚点（style_guide 5.3）：sword_slash / sword_hit / shield_hit 居中；落雷 (80,440)、地雷 (144,232) = 地面落点
const FX_ANCHORS := {&"thunder_strike": Vector2(80, 440), &"thunder_ground": Vector2(144, 232)}
var _fx_frames: SpriteFrames
var _fx_mat: Material
var _fx_mat_map := ""

## 当前地图的发光特效材质：亮底（青竹山）fx_on_light.gdshader（Mix + 墨晕，不发白）；暗底（雷泽谷、玄岩洞）Add
func fx_material() -> Material:
	var mid := level.map_id if level else ""
	if _fx_mat == null or _fx_mat_map != mid:
		_fx_mat_map = mid
		var m := GameData.get_map(mid) if mid != "" else null
		var light := m != null and m.art_key() == "qingzhu"
		if light and ResourceLoader.exists("res://art/fx/shaders/fx_on_light.gdshader"):
			var sm := ShaderMaterial.new()
			sm.shader = load("res://art/fx/shaders/fx_on_light.gdshader")
			_fx_mat = sm
		else:
			var cm := CanvasItemMaterial.new()
			cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			_fx_mat = cm
	return _fx_mat

## 播一次帧特效（不循环，播完释放）；pos 为锚点位置（落雷/地雷 = 地面点，其余 = 中心）
func spawn_fx(anim: StringName, pos: Vector2, flip := false, tint := Color.WHITE) -> AnimatedSprite2D:
	if not visual_fx:
		return null
	if _fx_frames == null:
		if not ResourceLoader.exists(FX_FRAMES):
			return null
		_fx_frames = load(FX_FRAMES)
	if not _fx_frames.has_animation(anim):
		return null
	var a := AnimatedSprite2D.new()
	a.sprite_frames = _fx_frames
	a.material = fx_material()
	a.modulate = tint
	if FX_ANCHORS.has(anim):
		a.centered = false
		a.offset = -FX_ANCHORS[anim]
	a.flip_h = flip
	a.position = pos
	a.z_index = 5
	effects_root.add_child(a)
	a.play(anim)
	a.animation_finished.connect(a.queue_free)
	return a

## 竹魅竹刺（style_guide 5.7）：fx_zhumei_thorn_02f.png 两帧（320×352，底部锚点 (160,344)），
## 从 skill_thorn 索引 4（= 预警结算）起沿预警条每约 120px 放一簇，逐簇延迟 0.05s
const THORN_TEX := "res://art/fx/fx_zhumei_thorn_02f.png"
var _thorn_frames: SpriteFrames
func spawn_thorns(xa: float, xb: float) -> void:
	if not ResourceLoader.exists(THORN_TEX):
		return
	if _thorn_frames == null:
		var tex: Texture2D = load(THORN_TEX)
		_thorn_frames = SpriteFrames.new()
		_thorn_frames.set_animation_loop(&"default", false)
		_thorn_frames.set_animation_speed(&"default", 10.0)
		for i in 2:
			var at := AtlasTexture.new(); at.atlas = tex; at.region = Rect2(i * 320, 0, 320, 352)
			_thorn_frames.add_frame(&"default", at, 2.0 if i == 1 else 1.0)
	var n := maxi(int(absf(xb - xa) / 120.0), 1)
	var step := (xb - xa) / float(n)
	var from := xa + step * 0.5
	if boss and boss.position.x > (xa + xb) / 2.0:   # 从首领一侧向外逐簇破土
		from = xb - step * 0.5; step = -step
	for i in n:
		var a := AnimatedSprite2D.new()
		a.sprite_frames = _thorn_frames
		a.centered = false
		a.offset = -Vector2(160, 344)
		a.flip_h = step > 0.0
		a.position = Vector2(from + step * i, ground_y)
		a.z_index = 4
		a.visible = false
		effects_root.add_child(a)
		var tw := a.create_tween()
		tw.tween_interval(0.05 * i)
		tw.tween_callback(func() -> void: a.visible = true; a.play(&"default"))
		tw.tween_interval(0.3)
		tw.tween_property(a, "modulate:a", 0.0, 0.25)
		tw.tween_callback(a.queue_free)

func spawn_flash(kind: String, pts: PackedVector2Array, color: Color, radius: float = 100.0) -> void:
	if not visual_fx:
		return
	var f := SkillFx.Flash.new()
	f.battle = self
	f.kind = kind; f.color = color; f.radius = radius
	if kind == "circle" and pts.size() > 0:
		f.position = pts[0]
	else:
		f.points = pts
	effects_root.add_child(f)

func spawn_projectile(range_px: float, width_px: float, coef: float, opts: Dictionary, delay: float, max_targets: int, color: Color) -> void:
	var p := SkillFx.Projectile.new()
	p.battle = self
	p.dir = player.facing
	p.travel_left = range_px
	p.half_width = maxf(width_px / 2.0, 10.0)
	p.coef = coef; p.opts = opts; p.delay = delay; p.max_targets = maxi(max_targets, 1); p.color = color
	p.tex = load("res://art/fx/fx_sword_blade_01f.png") if opts.get("gongfa_id", "") == "GF_SWORD" else null
	p.position = Vector2(player.position.x + 30 * player.facing, ground_y)
	effects_root.add_child(p)

func spawn_zone(x: float, radius: float, duration: float, tick_s: float, coef: float, opts: Dictionary, color: Color, follow: bool) -> void:
	var z := SkillFx.Zone.new()
	z.battle = self
	z.radius = radius; z.duration = duration; z.tick = tick_s; z.coef = coef; z.opts = opts; z.color = color
	z.follow_player = follow
	z.position = Vector2(x, ground_y - 50)
	effects_root.add_child(z)

func spawn_nine_strike(x0: float, x1: float, hits: int, duration: float, coef: float, opts: Dictionary) -> void:
	var n := SkillFx.NineStrike.new()
	n.battle = self
	n.x0 = x0; n.x1 = x1; n.strikes_left = hits; n.interval = duration / maxf(hits, 1); n.coef = coef; n.opts = opts
	effects_root.add_child(n)

func spawn_enemy_bolt(e: Enemy, dmg: float, speed: float) -> void:
	var bolt := SkillFx.EnemyBolt.new()
	bolt.battle = self
	bolt.source = e; bolt.damage = dmg; bolt.speed = speed
	bolt.dir = 1 if player.position.x > e.position.x else -1
	bolt.travel_left = e.def.attack_range_px + 120.0
	bolt.position = Vector2(e.position.x, ground_y)
	if e.anim:   # 雷蟾 attack 索引 3：雷球在锚点 (-52,-68)（朝左）处离口
		bolt.position.x += CreatureArt.TOAD_ORB_OFFSET.x * (-float(e.facing))
		bolt.tex = load("res://art/fx/fx_toad_orb.png") if ResourceLoader.exists("res://art/fx/fx_toad_orb.png") else null
	effects_root.add_child(bolt)

func _setup_background() -> void:
	if level == null or level.map_id == _bg_map_id or background == null:
		return
	_bg_map_id = level.map_id
	for c in background.get_children():
		_free_node(c)
	if _sky_fill == null:
		_sky_fill = ColorRect.new()
		_sky_fill.z_index = -100
		_sky_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		world.add_child(_sky_fill)
	var m := GameData.get_map(level.map_id)
	if m == null:
		return
	var key := m.art_key()
	var far_path := "res://art/bg/%s/bg_%s_far.png" % [key, key]
	if ResourceLoader.exists(far_path):
		var img := (load(far_path) as Texture2D).get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			_sky_fill.color = img.get_pixel(img.get_width() / 2, 0)   # 远景最上沿颜色补满高窗口的天空
	# 正式背景：res://art/bg/<map>/bg_<map>.tscn（Parallax2D 四层，依赖 World/Camera2D）
	var scene_path := "res://art/bg/%s/bg_%s.tscn" % [key, key]
	if ResourceLoader.exists(scene_path):
		var bg: Node = (load(scene_path) as PackedScene).instantiate()
		var fore := bg.get_node_or_null("Fore") as CanvasItem
		if fore:
			# 前景竹在角色之上（z=20），镜头随主角移动时会扫过主角：降低不透明度
			fore.modulate.a = GameData.const_f("BG_FORE_ALPHA", 0.6)
		background.add_child(bg)
		return
	var layers := [["far", 0.15, Vector2(0, 0), 1280.0], ["mid", 0.5, Vector2(0, 0), 2560.0], ["ground", 1.0, Vector2(0, ground_y - 10), 2560.0]]
	for L in layers:
		var path := "res://art/bg/%s/bg_%s_%s.png" % [key, key, L[0]]
		if not ResourceLoader.exists(path):
			continue
		var px := Parallax2D.new()
		px.scroll_scale = Vector2(L[1], 1.0)
		px.repeat_size = Vector2(L[3], 0)
		px.repeat_times = 3
		var sp := Sprite2D.new()
		sp.texture = load(path)
		sp.centered = false
		sp.position = L[2]
		px.add_child(sp)
		background.add_child(px)

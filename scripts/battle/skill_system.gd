class_name SkillSystem
extends RefCounted
## 4格主动技能栏的释放与冷却。手动输入与自动AI都调用 try_cast()；冷却中直接忽略（不排队）。
## 技能效果按 skills.csv 的 shape/anchor/effect_* 数据驱动执行。

signal cast(slot: int, skill_id: String, manual: bool)

var battle: Battle
var cds: Array[float] = []
var cd_totals: Array[float] = []
var cast_log: Array[Dictionary] = []   # 测试/调试：{t, slot, skill_id, manual}

func _init(b: Battle) -> void:
	battle = b
	reset()

func reset() -> void:
	cds.clear(); cd_totals.clear()
	for i in PlayerState.slot_count():
		cds.append(0.0); cd_totals.append(0.0)

func step(delta: float) -> void:
	for i in cds.size():
		cds[i] = maxf(cds[i] - delta, 0.0)

func skill_in_slot(slot: int) -> SkillDef:
	if slot < 0 or slot >= PlayerState.active_slots.size():
		return null
	var id := PlayerState.active_slots[slot]
	return GameData.get_skill(id) if id != "" else null

func level_of(s: SkillDef) -> SkillLevelDef:
	return s.level_def(maxi(PlayerState.skill_level(s.id), 1))

## 实际冷却 = 该级 cd_s × (1 − min(冷却缩减, CDR_CAP))；御雷诀另加 thunder_cdr
func cooldown_for(s: SkillDef) -> float:
	var st := battle.player.stats
	var cdr := float(st.get("cdr", 0.0))
	if s.gongfa_id == "GF_THUNDER":
		cdr += float(st.get("thunder_cdr", 0.0))
	cdr = minf(cdr, GameData.const_f("CDR_CAP", 0.4))
	return level_of(s).cd_s * (1.0 - cdr)

func is_ready(slot: int) -> bool:
	return skill_in_slot(slot) != null and slot < cds.size() and cds[slot] <= 0.0

func try_cast(slot: int, manual: bool) -> bool:
	var s := skill_in_slot(slot)
	if s == null or cds[slot] > 0.0:
		return false
	var p := battle.player
	if not p.alive or p.is_dodging() or not battle.combat_active():
		return false
	if not _execute(s, level_of(s)):
		return false
	cds[slot] = cooldown_for(s)
	cd_totals[slot] = cds[slot]
	cast_log.append({"t": battle.sim_time, "slot": slot, "skill_id": s.id, "manual": manual})
	if cast_log.size() > 256:   # BUG-009：调试日志只保留最近256条
		cast_log = cast_log.slice(cast_log.size() - 256)
	cast.emit(slot, s.id, manual)
	return true

func _opts(s: SkillDef, lv: SkillLevelDef, extra: Dictionary = {}) -> Dictionary:
	var o := {"skill_id": s.id, "gongfa_id": s.gongfa_id, "source": "skill"}
	if s.effect_type == "boss_dmg_bonus":
		o["boss_bonus"] = lv.effect_value
	if s.effect_type in ["def_down_pct", "slow_pct", "stun_s", "knockback_px"]:
		o["effect"] = [s.effect_type, lv.effect_value, s.effect_duration_s]
	o.merge(extra, true)
	return o

## 面向方向射程内最近的敌人
func nearest_front(range_px: float) -> Enemy:
	var p := battle.player
	var best: Enemy = null
	var bd := INF
	for e in battle.enemies:
		if not e.alive:
			continue
		var d := (e.position.x - p.position.x) * p.facing
		if d >= -Player.HALF_WIDTH and d <= range_px and d < bd:
			bd = d; best = e
	return best

func front_x_range(length: float) -> Vector2:
	var px := battle.player.position.x
	var f := battle.player.facing
	return Vector2(minf(px, px + f * length), maxf(px, px + f * length))

## 自动AI用：此刻释放是否有意义（有目标/在范围内）
func has_valid_target(s: SkillDef) -> bool:
	var p := battle.player
	match s.shape:
		"projectile", "line":
			return nearest_front(s.range_px) != null
		"chain":
			return nearest_front(s.range_px) != null
		"circle":
			if s.anchor == "self":
				return not battle.enemies_in_x_range(p.position.x - s.radius_px, p.position.x + s.radius_px).is_empty()
			return nearest_front(s.range_px) != null
		"rect":
			var r := front_x_range(s.range_px)
			return not battle.enemies_in_x_range(r.x, r.y).is_empty()
		"aura":
			return not battle.enemies_in_x_range(p.position.x - s.radius_px - 60, p.position.x + s.radius_px + 60).is_empty()
		"self_buff":
			return battle.has_engaged_enemies()
	return false

func _execute(s: SkillDef, lv: SkillLevelDef) -> bool:
	var p := battle.player
	var color := (GameData.gongfa.get(s.gongfa_id) as GongfaDef).color if GameData.gongfa.has(s.gongfa_id) else Color.WHITE
	match s.shape:
		"projectile":
			var interval := 0.4 / float(s.hits) if s.hits > 1 else 0.0
			for k in s.hits:
				battle.spawn_projectile(s.range_px, s.width_px, lv.damage_coef, _opts(s, lv), k * interval, s.max_targets, color)
			return true
		"line":
			var r := front_x_range(s.range_px)
			var targets := battle.enemies_in_x_range(r.x, r.y)
			for i in mini(targets.size(), s.max_targets):
				battle.player_hit_enemy(targets[i], lv.damage_coef, _opts(s, lv))
			battle.spawn_flash("rect", PackedVector2Array([Vector2(r.x, p.position.y - 100), Vector2(r.y, p.position.y - 60)]), color)
			return true
		"chain":
			var first := nearest_front(s.range_px)
			if first == null:
				return false
			var hit := [first]
			var cur: Enemy = first
			var pts := PackedVector2Array([Vector2(first.position.x, first.position.y - 500), first.position + Vector2(0, -60)])
			battle.player_hit_enemy(first, lv.damage_coef, _opts(s, lv))
			var jumps := lv.chain_count if lv.chain_count > 0 else s.chain_count
			for k in jumps:
				var nxt: Enemy = null
				var bd := INF
				for e in battle.enemies:
					if e.alive and not hit.has(e):
						var d := absf(e.position.x - cur.position.x)
						if d <= s.chain_radius_px and d < bd:
							bd = d; nxt = e
				if nxt == null:
					break
				hit.append(nxt)
				pts.append(nxt.position + Vector2(0, -60))
				battle.player_hit_enemy(nxt, lv.damage_coef * pow(1.0 - s.chain_decay, k + 1), _opts(s, lv))
				cur = nxt
			battle.spawn_flash("line", pts, color)
			return true
		"circle":
			if s.anchor == "self":
				for e in battle.enemies_in_x_range(p.position.x - s.radius_px, p.position.x + s.radius_px):
					battle.player_hit_enemy(e, lv.damage_coef, _opts(s, lv))
				battle.spawn_flash("circle", PackedVector2Array([p.position + Vector2(0, -60)]), color, s.radius_px)
				return true
			var tgt := nearest_front(s.range_px)
			if tgt == null:
				return false
			battle.spawn_zone(tgt.position.x, s.radius_px, s.duration_s, s.tick_interval_s, lv.damage_coef, _opts(s, lv), color, false)
			return true
		"rect":
			var r := front_x_range(s.range_px)
			if battle.enemies_in_x_range(r.x, r.y).is_empty():
				return false   # 九霄神雷：区域内无敌人不消耗冷却
			battle.spawn_nine_strike(r.x, r.y, s.hits, s.duration_s, lv.damage_coef, _opts(s, lv))
			return true
		"aura":
			battle.spawn_zone(p.position.x, s.radius_px, s.duration_s, s.tick_interval_s, lv.damage_coef, _opts(s, lv), color, true)
			if s.effect_type == "dmg_reduce_pct":
				p.dmg_reduce_v = lv.effect_value
				p.dmg_reduce_t = s.effect_duration_s if s.effect_duration_s > 0.0 else s.duration_s
			return true
		"self_buff":
			if s.effect_type != "shield_maxhp_pct":
				return false
			var data := {
				"skill_id": s.id, "amount": p.max_hp * lv.effect_value, "max": p.max_hp * lv.effect_value,
				"time": s.duration_s if s.duration_s > 0.0 else s.effect_duration_s,
			}
			match s.effect2_type:
				"reflect_add":   # 护体 v2：护盾期间额外反伤 + 反震（damage_coef）
					data["reflect_add"] = lv.effect2_value
					data["counter_coef"] = lv.damage_coef
				"burst_absorb_pct":   # 金刚不坏：破碎/结束时爆发
					data["burst_coef"] = lv.damage_coef
					data["burst_absorb_pct"] = lv.effect2_value
					data["burst_radius"] = s.radius_px
			p.add_shield(data)
			return true
	return false

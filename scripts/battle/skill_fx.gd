class_name SkillFx
extends RefCounted
## 技能效果与战斗表现节点（占位绘制）。逻辑全部在 step(delta) 中由 Battle 的物理更新驱动，
## 动画/绘制只负责表现；正式美术到位后可把 _draw 换成 Sprite/Line2D/粒子。

## 统一基类：所有效果节点都实现 step()
class FxBase extends Node2D:
	var battle: Battle
	var life := 0.0
	var done := false
	func step(_delta: float) -> void:
		pass
	func finish() -> void:
		done = true

## 飞剑等弹道：沿面向飞行，命中首个敌人（max_targets 支持贯穿）
class Projectile extends FxBase:
	var dir := 1
	var speed := 1100.0
	var travel_left := 600.0
	var half_width := 20.0
	var coef := 1.0
	var opts := {}
	var delay := 0.0
	var max_targets := 1
	var hit_ids := {}
	var color := Color("#7FE0FF")
	var tex: Texture2D
	func step(delta: float) -> void:
		if delay > 0.0:
			delay -= delta
			visible = false
			if delay <= 0.0:
				position.x = battle.player.position.x + 30 * dir
				dir = battle.player.facing
			return
		visible = true
		var dx := speed * delta
		var x0 := position.x
		position.x += dx * dir
		travel_left -= dx
		for e in battle.enemies_in_x_range(minf(x0, position.x) - half_width, maxf(x0, position.x) + half_width):
			if hit_ids.has(e.get_instance_id()):
				continue
			hit_ids[e.get_instance_id()] = true
			battle.player_hit_enemy(e, coef, opts)
			if hit_ids.size() >= max_targets:
				finish(); return
		if travel_left <= 0.0:
			finish()
	func _draw() -> void:
		draw_set_transform(Vector2(0, -80), 0.0, Vector2(dir, 1))
		if tex:
			draw_texture(tex, Vector2(-48, -12))
		else:
			draw_line(Vector2(-40, 0), Vector2(40, 0), color, 6)

## 短暂的表现用闪光（直线、圆、闪电折线），无逻辑
class Flash extends FxBase:
	var kind := "line"
	var points := PackedVector2Array()
	var radius := 100.0
	var color := Color.WHITE
	var duration := 0.25
	func step(delta: float) -> void:
		life += delta
		modulate.a = clampf(1.0 - life / duration, 0.0, 1.0)
		if life >= duration:
			finish()
	func _draw() -> void:
		match kind:
			"line":
				if points.size() >= 2:
					draw_polyline(points, color, 8.0)
					draw_polyline(points, Color.WHITE, 2.0)
			"circle":
				draw_circle(Vector2.ZERO, radius, Color(color, 0.25))
				draw_arc(Vector2.ZERO, radius, 0, TAU, 48, color, 4.0)
			"rect":
				if points.size() == 2:
					draw_rect(Rect2(points[0], points[1] - points[0]), Color(color, 0.3))

## 持续区域（雷云）：固定位置，每 tick 对半径内敌人造成伤害并附加效果
class Zone extends FxBase:
	var radius := 180.0
	var duration := 3.0
	var tick := 0.5
	var tick_t := 0.0
	var coef := 0.5
	var opts := {}
	var color := Color("#9DB4FF")
	var follow_player := false
	func step(delta: float) -> void:
		life += delta
		if follow_player:
			position.x = battle.player.position.x
		tick_t -= delta
		if tick_t <= 0.0:
			tick_t += maxf(tick, 0.05)
			for e in battle.enemies_in_x_range(position.x - radius, position.x + radius):
				battle.player_hit_enemy(e, coef, opts)
		queue_redraw()
		if life >= duration:
			finish()
	func _draw() -> void:
		draw_arc(Vector2(0, -10), radius, PI, TAU, 32, color, 3.0)
		draw_circle(Vector2(0, -10), radius, Color(color, 0.12))

## 九霄神雷：持续时间内均匀降下 hits 道雷，每道随机锁定区域内一个敌人
class NineStrike extends FxBase:
	var x0 := 0.0
	var x1 := 0.0
	var strikes_left := 9
	var interval := 0.15
	var t := 0.0
	var coef := 0.9
	var opts := {}
	func step(delta: float) -> void:
		t -= delta
		if t <= 0.0 and strikes_left > 0:
			t += interval
			strikes_left -= 1
			var cands := battle.enemies_in_x_range(minf(x0, x1), maxf(x0, x1))
			if not cands.is_empty():
				var e: Enemy = cands[battle.rng.randi_range(0, cands.size() - 1)]
				battle.player_hit_enemy(e, coef, opts)
				battle.spawn_flash("line", PackedVector2Array([Vector2(e.position.x, e.position.y - 500), Vector2(e.position.x + 10, e.position.y - 60)]), Color("#9DB4FF"))
		if strikes_left <= 0:
			finish()

## 敌人远程弹（雷蟾雷球）：非接触伤害，不触发反伤
class EnemyBolt extends FxBase:
	var source: Enemy
	var dir := -1
	var speed := 350.0
	var damage := 10.0
	var travel_left := 500.0
	func step(delta: float) -> void:
		var dx := speed * delta
		position.x += dx * dir
		travel_left -= dx
		var p := battle.player
		if p.alive and absf(p.position.x - position.x) < 24.0:
			battle.damage_player(damage, source, false)
			finish(); return
		if travel_left <= 0.0:
			finish()
	func _draw() -> void:
		draw_circle(Vector2(0, -60), 12, Color("#BFD3FF"))
		draw_circle(Vector2(0, -60), 6, Color.WHITE)

## 飘字（伤害、闪避、奖励）
class FloatText extends FxBase:
	var text := ""
	var color := Color.WHITE
	var size := 22
	var duration := 0.9
	func step(delta: float) -> void:
		life += delta
		position.y -= 50.0 * delta
		modulate.a = clampf(1.5 - life / duration * 1.5, 0.0, 1.0)
		if life >= duration:
			finish()
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
		draw_string_outline(font, Vector2(-w / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.1, 0.1, 0.1, 0.9))
		draw_string(font, Vector2(-w / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

class_name Telegraph
extends Node2D
## 首领危险攻击预警区域（预警区 = 判定区）。预警结束瞬间判定：玩家处于闪避免伤或不在区域内 = 无伤。
## 颜色/样式读 boss_attacks.telegraph_color / telegraph_style，空则用 constants 默认（朱砂虚线）。

var battle: Battle
var boss: Boss
var attack: BossAttackDef
var shape := "rect"
var x0 := 0.0
var x1 := 0.0
var cx := 0.0
var radius := 0.0
var arena := false
var delay := 0.0         # 多段（天雷三连）依次出现
var warn := 0.8
var t := 0.0
var color := Color("#C8312B")
var style := "dashed"
var done := false
var resolved_hit := false
var _locked := false

func setup(b: Battle, bs: Boss, a: BossAttackDef, index: int) -> void:
	battle = b
	boss = bs
	attack = a
	shape = a.shape
	warn = a.warn_s if a.warn_s > 0.0 else GameData.const_f("BOSS_WARN_TIME", 0.8)
	delay = index * GameData.const_f("BOSS_MULTI_AREA_INTERVAL", 0.4) if a.anchor == "player" else 0.0
	color = GameData.telegraph_color(a)
	if battle.use_alt_telegraph_color:
		color = Color.from_string(GameData.const_s("TELEGRAPH_ALT_COLOR", "#FFFFFF"), Color.WHITE)
	style = GameData.telegraph_style(a)
	arena = a.anchor == "arena"
	visible = delay <= 0.0
	if delay <= 0.0:
		_lock_area()

## 锁定区域：anchor=player 在预警出现瞬间锁定玩家位置，之后不跟随
func _lock_area() -> void:
	_locked = true
	var f := float(boss.facing)
	match attack.anchor:
		"facing":
			var a0 := boss.position.x + f * attack.offset_x
			var a1 := a0 + f * attack.width_px
			x0 = minf(a0, a1); x1 = maxf(a0, a1)
			cx = (x0 + x1) / 2.0
		"self":
			cx = boss.position.x + f * attack.offset_x
		"player":
			cx = battle.player.position.x + attack.offset_x
		"arena":
			cx = battle.player.position.x
	if attack.shape == "circle":
		radius = attack.radius_px
		x0 = cx - radius; x1 = cx + radius
	if arena:
		var half := battle.view_half_width()
		x0 = battle.camera_center_x() - half; x1 = battle.camera_center_x() + half
		cx = (x0 + x1) / 2.0
	position = Vector2(0, battle.ground_y)
	queue_redraw()

func player_inside() -> bool:
	if arena:
		return true
	var px := battle.player.position.x
	return px + Player.HALF_WIDTH >= x0 and px - Player.HALF_WIDTH <= x1

func progress() -> float:
	return clampf(t / warn, 0.0, 1.0)

func step(delta: float) -> void:
	if done:
		return
	if delay > 0.0:
		delay -= delta
		if delay <= 0.0:
			visible = true
			_lock_area()
		return
	t += delta
	queue_redraw()
	if t >= warn:
		done = true
		resolved_hit = battle.resolve_telegraph(self)

func _draw() -> void:
	if not _locked:
		return
	var h := attack.height_px if attack.height_px > 0.0 else 120.0
	var fill := Color(color, 0.18 + 0.25 * progress())
	if shape == "circle" and not arena:
		var r := radius
		var pts := PackedVector2Array()
		for i in 49:
			var ang := TAU * i / 48.0
			pts.append(Vector2(cx + cos(ang) * r, sin(ang) * r * 0.25 - 4))
		draw_colored_polygon(pts, fill)
		_outline(pts)
		var inner := PackedVector2Array()
		for i in 49:
			var ang := TAU * i / 48.0
			inner.append(Vector2(cx + cos(ang) * r * progress(), sin(ang) * r * 0.25 * progress() - 4))
		if progress() > 0.02:
			draw_colored_polygon(inner, Color(color, 0.35))
	else:
		var top := -h if not arena else -battle.ground_y
		var rect := Rect2(x0, top, x1 - x0, -top + 20)
		draw_rect(rect, fill)
		var pts := PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y), rect.position])
		_outline(pts)
		draw_rect(Rect2(x0, 14, (x1 - x0) * progress(), 6), color)
	if arena:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(cx - 80, -330), attack.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, color)

func _outline(pts: PackedVector2Array) -> void:
	for i in pts.size() - 1:
		if style == "dashed":
			draw_dashed_line(pts[i], pts[i + 1], color, 3.0, 12.0)
		else:
			draw_line(pts[i], pts[i + 1], color, 3.0)

class_name Telegraph
extends Node2D
## 首领危险攻击预警区域（预警区 = 判定区）。预警结束瞬间判定：玩家处于闪避免伤或不在区域内 = 无伤。
## 颜色：招式色 → 地图色 → TELEGRAPH_DEFAULT_COLOR（玩家设置统一预警白时用 ALT）；样式 telegraph_style，空则 constants 默认（虚线）。
## v5.1 美术实测：区域内填充 = 预警色 × TELEGRAPH_FILL_ALPHA；描边外侧再加 TELEGRAPH_OUTLINE_PX 宽的暗色外描边。

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
var color := Color(GameData.FALLBACK_TELEGRAPH)
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
	color = GameData.telegraph_color(a, battle.level.map_id if battle.level else "", battle.use_alt_telegraph_color or PlayerState.telegraph_alt)
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
	position = Vector2(0, battle.ground_y)
	if arena:
		_fit_arena()
	queue_redraw()

## 全场预警每帧按当前镜头与视口铺满（BUG-007：镜头移动/非16:9窗口时也不露边）
func _fit_arena() -> void:
	var vr := battle.view_rect().grow(40.0)
	x0 = vr.position.x; x1 = vr.end.x
	cx = (x0 + x1) / 2.0

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
	if arena:
		_fit_arena()
	queue_redraw()
	if t >= warn - 1e-6:   # 固定步长累加的浮点残差不应多拖一帧
		done = true
		resolved_hit = battle.resolve_telegraph(self)

func _draw() -> void:
	if not _locked:
		return
	var h := attack.height_px if attack.height_px > 0.0 else 120.0
	var fill := Color(color, GameData.const_f("TELEGRAPH_FILL_ALPHA", 0.15))
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
			draw_colored_polygon(inner, Color(color, minf(fill.a * 2.0, 1.0)))   # 进度：内圈随预警时间扩大
	else:
		var rect := Rect2(x0, -h, x1 - x0, h + 20)
		if arena:
			var vr := battle.view_rect().grow(40.0)
			rect = Rect2(x0, vr.position.y - position.y, x1 - x0, vr.size.y)
		draw_rect(rect, fill)
		var orect := rect
		if arena:   # 全场预警：填充铺满视口外沿，描边内收到屏幕边缘内侧，像一圈屏幕警示框
			var vr2 := battle.view_rect().grow(-(LINE_PX + 2.0 * GameData.const_f("TELEGRAPH_OUTLINE_PX", 2.0)))
			orect = Rect2(vr2.position - Vector2(0, position.y), vr2.size)
		var pts := PackedVector2Array([orect.position, orect.position + Vector2(orect.size.x, 0), orect.end, orect.position + Vector2(0, orect.size.y), orect.position])
		_outline(pts)
		var bar := Rect2(x0, 14, (x1 - x0) * progress(), 6)
		draw_rect(bar.grow(GameData.const_f("TELEGRAPH_OUTLINE_PX", 2.0)), outline_color())
		draw_rect(bar, color)
	# BUG-012：引导提示显示期间不画招式名（与屏幕中央“按空格闪避！”重叠）
	if arena and not battle.tutorial.is_active_for(self):
		var font := UiStyle.world_font()
		draw_string_outline(font, Vector2(cx - 80, -330), attack.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, int(GameData.const_f("TELEGRAPH_OUTLINE_PX", 2.0)) * 2, outline_color())
		draw_string(font, Vector2(cx - 80, -330), attack.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, color)

const LINE_PX := 3.0

## v5.1 外描边：TELEGRAPH_OUTLINE_COLOR × TELEGRAPH_OUTLINE_ALPHA
static func outline_color() -> Color:
	var c := Color.from_string(GameData.const_s("TELEGRAPH_OUTLINE_COLOR", "#1C1E21"), Color("#1C1E21"))
	return Color(c, GameData.const_f("TELEGRAPH_OUTLINE_ALPHA", 0.6))

## 主描边（预警色，虚线/实线）外侧加一圈 TELEGRAPH_OUTLINE_PX 宽的暗色外描边（连续实线，亮背景与熔岩高光上也能分辨）
func _outline(pts: PackedVector2Array) -> void:
	var ow := LINE_PX + 2.0 * GameData.const_f("TELEGRAPH_OUTLINE_PX", 2.0)
	draw_polyline(pts, outline_color(), ow, true)
	for i in pts.size() - 1:
		if style == "dashed":
			draw_dashed_line(pts[i], pts[i + 1], color, LINE_PX, 12.0)
		else:
			draw_line(pts[i], pts[i + 1], color, LINE_PX)

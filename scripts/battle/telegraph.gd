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
	modulate.a = flash_alpha()
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
			draw_colored_polygon(inner, Color(color, GameData.const_f("TELEGRAPH_PROGRESS_FILL_ALPHA", 0.3)))   # 进度：内圈随预警时间扩大
	else:
		var rect := Rect2(x0, -h, x1 - x0, h + 20)
		if arena:
			var vr := battle.view_rect().grow(40.0)
			rect = Rect2(x0, vr.position.y - position.y, x1 - x0, vr.size.y)
		if arena:
			_radial_fill(rect, Color(color, GameData.const_f("TELEGRAPH_ARENA_FILL_ALPHA_CENTER", 0.15)))
		else:
			draw_rect(rect, fill)
		var orect := rect
		if arena:   # 全场预警：填充铺满视口外沿，描边内收到屏幕边缘内侧，像一圈屏幕警示框
			var vr2 := battle.safe_view_rect().grow(-(line_px() + 2.0 * outline_px()))   # BUG-015：内收到 HUD 让出的可见战场区
			orect = Rect2(vr2.position - Vector2(0, position.y), vr2.size)
		var pts := PackedVector2Array([orect.position, orect.position + Vector2(orect.size.x, 0), orect.end, orect.position + Vector2(0, orect.size.y), orect.position])
		_outline(pts, avoid_rects_local() if arena else [])
		var bar := Rect2(x0, 14, (x1 - x0) * progress(), 6)
		draw_rect(bar.grow(outline_px()), outline_color(arena))
		draw_rect(bar, color)
	# BUG-012：引导提示显示期间不画招式名（与屏幕中央“按空格闪避！”重叠）
	if arena and not battle.tutorial.is_active_for(self):
		var font := UiStyle.world_font()
		draw_string_outline(font, Vector2(cx - 80, -330), attack.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, int(outline_px()) * 2, outline_color())
		draw_string(font, Vector2(cx - 80, -330), attack.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, color)

## 第 3 批美术定稿（style_guide 2.2 / 5.8）= 策划 v5.4/v5.5 常量（README 3.7），全部读表，代码默认同表值：
## TELEGRAPH_LINE_PX=4、TELEGRAPH_DASH_PX=12、TELEGRAPH_GAP_PX=12、TELEGRAPH_ARENA_LINE_PX=6、TELEGRAPH_ARENA_DASH_PX=24、
## TELEGRAPH_ARENA_GAP_PX=16、TELEGRAPH_ARENA_OUTLINE_PX=3、
## TELEGRAPH_ARENA_OUTLINE_ALPHA=0.7、TELEGRAPH_ARENA_FILL_ALPHA_CENTER=0.15→EDGE=0.35、TELEGRAPH_BLINK_MIN_ALPHA=0.45、
## TELEGRAPH_PROGRESS_FILL_ALPHA=0.3；闪烁次数表里没有，代码固定 3 次/0.8s（美术 5.8：2~3 次）。
func line_px() -> float:
	return GameData.const_f("TELEGRAPH_ARENA_LINE_PX", 6.0) if arena else GameData.const_f("TELEGRAPH_LINE_PX", 4.0)

func outline_px() -> float:
	return GameData.const_f("TELEGRAPH_ARENA_OUTLINE_PX", 3.0) if arena else GameData.const_f("TELEGRAPH_OUTLINE_PX", 2.0)

## v5.1 外描边：TELEGRAPH_OUTLINE_COLOR × TELEGRAPH_OUTLINE_ALPHA（表值 0.6；美术定稿 0.7，以表为准）
static func outline_color(arena_wide := false) -> Color:
	var c := Color.from_string(GameData.const_s("TELEGRAPH_OUTLINE_COLOR", "#1C1E21"), Color("#1C1E21"))
	return Color(c, GameData.const_f("TELEGRAPH_ARENA_OUTLINE_ALPHA", 0.7) if arena_wide else GameData.const_f("TELEGRAPH_OUTLINE_ALPHA", 0.7))

const BLINK_COUNT := 3.0
## 闪烁：预警期间不透明度在 1.0 与 TELEGRAPH_FLASH_MIN_ALPHA 之间往返 TELEGRAPH_FLASH_COUNT 次（按预警计时驱动，确定性，暂停时冻结）
func flash_alpha() -> float:
	var n := BLINK_COUNT
	var lo := GameData.const_f("TELEGRAPH_BLINK_MIN_ALPHA", 0.45)
	var ph := 0.5 - 0.5 * cos(TAU * n * progress())
	return lerpf(1.0, lo, ph)

## 全场底色：中心 TELEGRAPH_ARENA_FILL_ALPHA_CENTER → 四边 TELEGRAPH_ARENA_FILL_ALPHA_EDGE 的径向渐变（三角扇，顶点色插值）
func _radial_fill(rect: Rect2, fill: Color) -> void:
	var edge := Color(color, GameData.const_f("TELEGRAPH_ARENA_FILL_ALPHA_EDGE", 0.35))
	var c := rect.get_center()
	var ring := [rect.position, Vector2(c.x, rect.position.y), Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, c.y),
		rect.end, Vector2(c.x, rect.end.y), Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, c.y)]
	for i in ring.size():
		var a: Vector2 = ring[i]; var b: Vector2 = ring[(i + 1) % ring.size()]
		draw_polygon(PackedVector2Array([c, a, b]), PackedColorArray([fill, edge, edge]))

## 全场描边在 HUD 控件处断开时，控件四周再留的空隙（px）
const AVOID_PAD := 8.0

## HUD 控件矩形（屏幕坐标，battle.hud_avoid_rects）→ 本节点坐标（与描边 orect 同一换算）
func avoid_rects_local() -> Array:
	var out: Array = []
	if battle == null:
		return out
	var vr := battle.view_rect()
	for r: Rect2 in battle.hud_avoid_rects:
		out.append(Rect2(vr.position + r.position - Vector2(0, position.y), r.size).grow(AVOID_PAD))
	return out

## 线段 a→b 去掉与 rects（按线宽 half_w 加粗判断）相交的部分，返回保留区间 [[d0, d1], ...]（沿线距离）
static func clip_segment(a: Vector2, b: Vector2, rects: Array, half_w: float) -> Array:
	var len := a.distance_to(b)
	var keep: Array = [[0.0, len]]
	if len <= 0.0:
		return []
	var dir := (b - a) / len
	for r: Rect2 in rects:
		var g := r.grow(half_w)
		# Liang–Barsky：线段与矩形相交的距离区间
		var t0 := 0.0; var t1 := len
		var ok := true
		for ax in 2:
			var p0 := a[ax]; var dv := dir[ax]
			var lo := g.position[ax]; var hi := g.end[ax]
			if absf(dv) < 1e-6:
				if p0 < lo or p0 > hi:
					ok = false
					break
			else:
				var ta := (lo - p0) / dv; var tb := (hi - p0) / dv
				t0 = maxf(t0, minf(ta, tb)); t1 = minf(t1, maxf(ta, tb))
		if not ok or t1 <= t0:
			continue
		var nk: Array = []
		for iv in keep:
			if t1 <= iv[0] or t0 >= iv[1]:
				nk.append(iv)
				continue
			if t0 > iv[0]:
				nk.append([iv[0], t0])
			if t1 < iv[1]:
				nk.append([t1, iv[1]])
		keep = nk
	return keep

## 主描边（预警色，虚线/实线）外侧加一圈外描边（连续实线，亮背景与熔岩高光上也能分辨）。
## avoid：要让开的矩形（全场预警让开 HUD 控件），描边在其中断开；虚线相位按沿线距离连续，断口两侧花纹对齐。
func _outline(pts: PackedVector2Array, avoid: Array = []) -> void:
	var lw := line_px()
	var ow := lw + 2.0 * outline_px()
	var on := GameData.const_f("TELEGRAPH_ARENA_DASH_PX", 24.0) if arena else GameData.const_f("TELEGRAPH_DASH_PX", 12.0)
	var off := GameData.const_f("TELEGRAPH_ARENA_GAP_PX", 16.0) if arena else GameData.const_f("TELEGRAPH_GAP_PX", 12.0)
	if avoid.is_empty():
		draw_polyline(pts, outline_color(arena), ow, true)
		var carry := 0.0   # 虚线相位跨线段连续，拐角处不重新起笔
		for i in pts.size() - 1:
			if style == "dashed":
				carry = _dash(pts[i], pts[i + 1], lw, on, off, carry)
			else:
				draw_line(pts[i], pts[i + 1], color, lw)
		return
	var period := on + maxf(off, 0.0)
	var base_phase := 0.0
	for i in pts.size() - 1:
		var a := pts[i]; var b := pts[i + 1]
		var len := a.distance_to(b)
		if len <= 0.0:
			continue
		var dir := (b - a) / len
		for iv in clip_segment(a, b, avoid, ow * 0.5):
			var p0: Vector2 = a + dir * float(iv[0]); var p1: Vector2 = a + dir * float(iv[1])
			# 外描边两端各延半个线宽，拐角处与相邻边接上
			var ext0 := ow * 0.5 if float(iv[0]) <= 0.0 else 0.0
			var ext1 := ow * 0.5 if float(iv[1]) >= len else 0.0
			draw_line(p0 - dir * ext0, p1 + dir * ext1, outline_color(arena), ow)
			if style == "dashed":
				_dash(p0, p1, lw, on, off, fposmod(base_phase + float(iv[0]), period) if period > 0.0 else 0.0)
			else:
				draw_line(p0, p1, color, lw)
		base_phase += len

## 划 on / 空 off 的虚线；phase 为本段起点已走过的周期长度，返回终点相位
func _dash(a: Vector2, b: Vector2, lw: float, on: float, off: float, phase: float) -> float:
	var len := a.distance_to(b)
	if len <= 0.0 or on <= 0.0:
		return phase
	var dir := (b - a) / len
	var period := on + maxf(off, 0.0)
	var d := 0.0
	var ph := fposmod(phase, period)
	while d < len:
		if ph < on:
			var seg := minf(on - ph, len - d)
			draw_line(a + dir * d, a + dir * (d + seg), color, lw)
			d += seg; ph += seg
		else:
			var gap := minf(period - ph, len - d)
			d += gap; ph += gap
		if ph >= period:
			ph -= period
	return ph

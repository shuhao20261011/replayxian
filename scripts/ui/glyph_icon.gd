class_name GlyphIcon
extends Control
## 小图标（正式图标切图到位前的程序绘制版）：jade 灵石、taiji 修为/境界、shield 护盾、save 存档、arrow_up 推荐

@export var kind := "jade"
@export var dim := 26.0

func _init(k: String = "jade", d: float = 26.0) -> void:
	kind = k; dim = d
	custom_minimum_size = Vector2(d, d)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 1.0
	match kind:
		"jade":
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.2), c + Vector2(r * 0.5, r * 0.85), c + Vector2(-r * 0.5, r * 0.85), c + Vector2(-r * 0.8, -r * 0.2)])
			draw_colored_polygon(pts, Color("#2E8C6E"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.2), c + Vector2(0, 0), c + Vector2(-r * 0.8, -r * 0.2)]), Color("#7FD8B4"))
			pts.append(pts[0])
			draw_polyline(pts, Color("#C9F2DF"), 1.2, true)
		"taiji":
			draw_circle(c, r, UiStyle.MIST)
			var half := PackedVector2Array()
			for i in 25:
				var a := -PI / 2 + PI * i / 24.0
				half.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(half, UiStyle.INK_DARK)   # 右半黑
			draw_circle(c + Vector2(0, -r / 2), r / 2, UiStyle.MIST)
			draw_circle(c + Vector2(0, r / 2), r / 2, UiStyle.INK_DARK)
			draw_circle(c + Vector2(0, -r / 2), r / 7, UiStyle.INK_DARK)
			draw_circle(c + Vector2(0, r / 2), r / 7, UiStyle.MIST)
			draw_arc(c, r, 0, TAU, 32, UiStyle.GOLD_LINE, 1.5, true)
		"shield":
			var s := PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.8), c + Vector2(r * 0.8, -r * 0.8), c + Vector2(r * 0.8, 0), c + Vector2(0, r), c + Vector2(-r * 0.8, 0)])
			draw_colored_polygon(s, Color("#6E5524"))
			s.append(s[0])
			draw_polyline(s, UiStyle.SHIELD, 2.0, true)
			draw_line(c + Vector2(0, -r * 0.6), c + Vector2(0, r * 0.6), UiStyle.SHIELD, 2.0, true)
		"save":
			draw_arc(c + Vector2(0, 2), r * 0.7, PI * 0.95, PI * 2.05, 16, UiStyle.GOLD_TEXT, 2.0, true)
			draw_line(c + Vector2(0, r * 0.7), c + Vector2(0, -r * 0.2), UiStyle.GOLD_TEXT, 2.0, true)
			draw_polyline(PackedVector2Array([c + Vector2(-5, -r * 0.05), c + Vector2(0, -r * 0.35), c + Vector2(5, -r * 0.05)]), UiStyle.GOLD_TEXT, 2.0, true)
		"arrow_up":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, 0), c + Vector2(r * 0.3, 0), c + Vector2(r * 0.3, r), c + Vector2(-r * 0.3, r), c + Vector2(-r * 0.3, 0), c + Vector2(-r * 0.8, 0)]), UiStyle.GOOD)

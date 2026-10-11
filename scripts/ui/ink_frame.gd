class_name InkFrame
extends Control
## 面板装饰层：内侧细金线 + 四角回纹角花 + 顶部居中云纹点缀（程序绘制，代替尚未交付的九宫格切图）。
## 放在 PanelContainer 里作为最后一个子节点，铺满且不拦截鼠标。

@export var inset := 7.0
@export var corner := 18.0
@export var cloud := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _draw() -> void:
	var g := Color(UiStyle.GOLD_LINE, 0.55)
	var gs := Color(UiStyle.GOLD_LINE, 0.95)
	var r := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	if r.size.x <= corner * 3 or r.size.y <= corner * 3:
		return
	draw_rect(r, g, false, 1.0, true)
	for cpos in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var sx := 1.0 if cpos.x <= r.position.x + 0.1 else -1.0
		var sy := 1.0 if cpos.y <= r.position.y + 0.1 else -1.0
		var c: Vector2 = cpos
		# 回纹角花：两段折线 + 菱形点
		var pts := PackedVector2Array([c + Vector2(0, corner * sy), c, c + Vector2(corner * sx, 0)])
		draw_polyline(pts, gs, 2.0, true)
		var k := corner * 0.45
		draw_polyline(PackedVector2Array([c + Vector2(k * sx, corner * 0.8 * sy), c + Vector2(k * sx, k * sy), c + Vector2(corner * 0.8 * sx, k * sy)]), gs, 1.2, true)
		var d := c + Vector2(-4 * sx, -4 * sy)
		draw_colored_polygon(PackedVector2Array([d + Vector2(0, -3), d + Vector2(3, 0), d + Vector2(0, 3), d + Vector2(-3, 0)]), gs)
	if cloud:
		var cx := size.x / 2.0
		var y := inset
		draw_line(Vector2(cx - 60, y), Vector2(cx - 18, y), Color(0, 0, 0, 0), 1)
		for s in [-1.0, 1.0]:
			draw_arc(Vector2(cx + s * 12, y), 6, PI, TAU, 12, gs, 1.5, true)
			draw_arc(Vector2(cx + s * 24, y + 1), 4, PI, TAU, 10, gs, 1.2, true)
		draw_circle(Vector2(cx, y - 1), 3, gs)

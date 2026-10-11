extends Node2D
## 掉落光柱：quality 1~5 = 白/绿/蓝/紫/橙（qualities.csv 的 beam_color）。节点原点放在掉落物落点（地面）。
## 高度：白 0（无柱，只有底座微光）、绿 110、蓝 200、紫 300、橙 420；橙装额外显示放射光。

const BEAM_COLORS := [Color("#CACAC9"), Color("#62BB73"), Color("#347DD2"), Color("#934DC5"), Color("#D89522")]
const HEIGHTS := [0.0, 110.0, 200.0, 300.0, 420.0]

@export_range(1, 5) var quality := 4:
	set(v):
		quality = clampi(v, 1, 5)
		if is_node_ready():
			_apply()

func _ready() -> void:
	_apply()

func _apply() -> void:
	var c: Color = BEAM_COLORS[quality - 1]
	var h: float = HEIGHTS[quality - 1]
	$Beam.visible = h > 0.0
	$Beam.modulate = c
	$Beam.scale = Vector2(1.0, maxf(h, 1.0) / 512.0)
	$Base.modulate = Color(c, 0.6 if quality == 1 else 1.0)
	$Particles.color = c
	$Particles.emitting = h > 0.0
	$Particles.emission_rect_extents = Vector2(12.0, 4.0)
	$Particles.lifetime = 0.6 + h / 300.0
	$Rays.visible = quality == 5
	$Rays.modulate = c

func _process(_delta: float) -> void:
	if $Rays.visible:
		var t := Time.get_ticks_msec() / 1000.0
		$Rays.scale = Vector2.ONE * (1.0 + 0.06 * sin(t * 2.4))
		$Rays.modulate.a = 0.75 + 0.25 * sin(t * 2.4)

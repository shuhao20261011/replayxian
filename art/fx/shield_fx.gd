extends Node2D
## 护盾：球（shield_sphere.gdshader）+ 八卦符环缓转。节点原点放在主角身体中心（约脚底上方 90px）。
## 受击：调用 hit()，在 HitFlash（AnimatedSprite2D，fx_frames.tres 的 shield_hit）上播一次。
@export var ring_speed := 0.2   # 弧度/秒

func _process(delta: float) -> void:
	$Ring.rotation += ring_speed * delta

func hit() -> void:
	$HitFlash.visible = true
	$HitFlash.play(&"shield_hit")
	await $HitFlash.animation_finished
	$HitFlash.visible = false

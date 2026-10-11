class_name CreatureArt
extends RefCounted
## 怪物/首领正式图集接入（art/ART_STYLE_GUIDE_final.md 5.1.2 / 5.7）。这里只放美术规格（锚点、悬浮、命中帧），
## 不放玩法数值。SpriteFrames 按路径加载（res://art/enemies/<key>/enm_<key>.tres、res://art/bosses/<key>/boss_<key>.tres），
## 美术以同名文件替换即可生效；缺图时返回 null，调用方退回占位绘制。
## 所有怪物图集朝左；节点原点 = 地面点（y=585）；centered=false，offset=(-AX,-AY)，朝右时 offset.x=-(W-AX)。

## key -> [W, H, AX, AY, 攻击命中帧索引, 身体高度(血条位置), 悬浮上下浮动]
const META := {
	"bamboo_imp": [256, 192, 152, 184, 2, 128, false],
	"mountain_ape": [288, 224, 144, 216, 3, 178, false],
	"marsh_wisp": [224, 192, 96, 184, 2, 160, true],
	"thunder_toad": [256, 160, 128, 152, 3, 122, false],
	"cave_bat": [192, 224, 72, 216, 3, 180, true],
	"rock_golem": [320, 288, 160, 280, 3, 236, false],
	"zhumei": [736, 416, 352, 394, 2, 290, false],   # 第 2.1 批：格子 736×416
	"kuiniu": [384, 480, 192, 466, 2, 268, false],
	"yanmo": [448, 480, 296, 472, 3, 318, false],    # 第 2.1 批：格子 448×480
}
## 雷蟾雷球生成点（相对锚点，朝左）
const TOAD_ORB_OFFSET := Vector2(-52, -68)
## 首领危险技能：前摇 4 帧合计 0.8s（索引 3 定格），索引 4 为出手判定帧
const BOSS_SKILL_WINDUP_S := 0.8

## 美术构建报告（art/final/src/_enemy_build_report.json 的副本）：岩魔 skill_charge 出手帧的画内前冲位移等
const BUILD_REPORT := "res://art/bosses/enemy_build_report.json"
static var _report: Dictionary = {}

static func build_report() -> Dictionary:
	if _report.is_empty() and FileAccess.file_exists(BUILD_REPORT):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUILD_REPORT))
		_report = d if d is Dictionary else {"_": 0}
	return _report

## 技能动画结束时的画内位移（像素，朝左为正向）：yanmo.charge_dx 末值的绝对值；无数据返回 0
static func skill_end_dx(d: EnemyDef, anim: StringName) -> float:
	var r: Dictionary = build_report().get(art_key(d), {})
	var key := String(anim).trim_prefix("skill_") + "_dx"
	var arr: Array = r.get(key, [])
	return absf(float(arr.back())) if not arr.is_empty() else 0.0

static func art_key(d: EnemyDef) -> String:
	return d.id.to_lower().trim_prefix("boss_").trim_prefix("en_")

static func frames_path(d: EnemyDef) -> String:
	var k := art_key(d)
	return ("res://art/bosses/%s/boss_%s.tres" if d.is_boss() else "res://art/enemies/%s/enm_%s.tres") % [k, k]

static func meta(d: EnemyDef) -> Array:
	return META.get(art_key(d), [])

static func make_sprite(d: EnemyDef) -> AnimatedSprite2D:
	var p := frames_path(d)
	if not ResourceLoader.exists(p) or meta(d).is_empty():
		return null
	var s := AnimatedSprite2D.new()
	s.name = "Anim"
	s.sprite_frames = load(p)
	s.centered = false
	apply_facing(s, d, -1)
	s.play(&"idle")
	return s

static func apply_facing(s: AnimatedSprite2D, d: EnemyDef, facing: int, bob: float = 0.0) -> void:
	var m := meta(d)
	if m.is_empty():
		return
	s.flip_h = facing > 0
	s.offset = Vector2(-(float(m[0]) - float(m[2])) if facing > 0 else -float(m[2]), -float(m[3]) + bob)

## 普攻从起手到命中帧的秒数（命中帧索引 / 动作帧率，按 speed_scale 缩放前）
static func hit_delay(d: EnemyDef) -> float:
	var p := frames_path(d)
	var m := meta(d)
	if m.is_empty() or not ResourceLoader.exists(p):
		return 0.0
	var sf: SpriteFrames = load(p)
	if not sf.has_animation(&"attack"):
		return 0.0
	var t := 0.0
	var fps := sf.get_animation_speed(&"attack")
	for i in int(m[4]):
		t += sf.get_frame_duration(&"attack", i) / maxf(fps, 0.01)
	return t

static func body_height(d: EnemyDef) -> float:
	var m := meta(d)
	return float(m[5]) if not m.is_empty() else 120.0

static func hovers(d: EnemyDef) -> bool:
	var m := meta(d)
	return not m.is_empty() and bool(m[6])

## 首领危险技能的动画名（style_guide 5.1.2：BA_ZHUMEI_THORN -> skill_thorn）
static func skill_anim(attack_id: String) -> StringName:
	var parts := attack_id.split("_")
	return StringName("skill_" + parts[parts.size() - 1].to_lower())

## 死亡动画（敌人节点立即释放，另起一个只做表现的精灵播完淡出）
static func spawn_death(parent: Node, d: EnemyDef, pos: Vector2, facing: int) -> void:
	var s := make_sprite(d)
	if s == null or not s.sprite_frames.has_animation(&"death"):
		if s:
			s.free()
		return
	s.position = pos
	apply_facing(s, d, facing)
	parent.add_child(s)
	s.play(&"death")
	s.animation_finished.connect(func() -> void:
		var tw := s.create_tween()
		tw.tween_property(s, "modulate:a", 0.0, 0.35)
		tw.tween_callback(s.queue_free))

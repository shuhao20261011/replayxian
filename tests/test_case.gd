class_name TestCase
extends RefCounted
## 极简测试基类：test_* 方法；断言失败记录到 failures。可 await（协程测试）。

const DT := 1.0 / 60.0
const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")

var runner: Node
var failures: Array[String] = []
var _current := ""

func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append("%s: %s" % [_current, msg])

func eq(a: Variant, b: Variant, msg: String) -> void:
	check(a == b, "%s (got %s, expected %s)" % [msg, str(a), str(b)])

func near(a: float, b: float, eps: float, msg: String) -> void:
	check(absf(a - b) <= eps, "%s (got %.4f, expected %.4f±%.4f)" % [msg, a, b, eps])

func before_each() -> void:
	if GameData.data_dir != GameData.DEFAULT_DATA_DIR:
		GameData.load_all()
	PlayerState.reset_new_game()
	runner.get_tree().paused = false

## 创建一个手动驱动（不跑 _physics_process）的战斗实例
func make_battle(seed_value: int = 12345) -> Battle:
	var b: Battle = BATTLE_SCENE.instantiate()
	b.autostart = false
	b.auto_tick = false
	b.visual_fx = false
	b.rng_seed = seed_value
	runner.add_child(b)
	b.controller.read_device_input = false
	return b

func free_battle(b: Battle) -> void:
	if is_instance_valid(b):
		runner.remove_child(b)
		b.queue_free()

## 以固定步长推进；until 返回 true 时提前结束并返回 true
func sim(b: Battle, seconds: float, until: Callable = Callable()) -> bool:
	var n := int(ceil(seconds / DT))
	for i in n:
		b.tick(DT)
		if until.is_valid() and until.call():
			return true
	return false

func spawn_dummy(b: Battle, enemy_id: String, dx: float) -> Enemy:
	return b.spawn_enemy(GameData.get_enemy(enemy_id), b.player.position.x + dx)

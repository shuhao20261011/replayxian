class_name TutorialService
extends RefCounted
## 情境引导（tutorial_steps.category = contextual）。阶段1-2只接入战斗内的情境步骤（如 TUT_07 天坠闪避）：
## - trigger_ref_ids 中的 BA_* 招式预警出现时触发；未完成且提示次数 < max_show_count 才提示。
## - 提示期间按 time_scale / time_scale_duration_s 对战斗时钟慢放（0=暂停整个提示期间），输入照常响应。
## - 预警结束时玩家处于闪避免伤 → 完成；否则下次再提示；累计提示达到 max_show_count 自动视为完成。
## 主线步骤（TUT_01~06：领书/学习/装配/换装…）依赖阶段3-4的系统，暂未接入。

signal hint_shown(step_id: String, text: String)
signal hint_hidden(step_id: String, success: bool)

var battle: Battle
var steps: Array[Dictionary] = []
var active_step := {}
var active_tg: Telegraph

func _init(b: Battle) -> void:
	battle = b
	for r in GameData.tables.get("tutorial_steps", []):
		if CsvUtil.s(r, "category", "main") == "contextual":
			steps.append(r)

static func hint_text(row: Dictionary) -> String:
	var ui := CsvUtil.s(row, "ui_target")
	var a := ui.find("“")
	var b := ui.find("”", a + 1)
	if a >= 0 and b > a:
		return ui.substr(a + 1, b - a - 1)
	return CsvUtil.s(row, "name")

func on_telegraph_started(tg: Telegraph) -> void:
	if not active_step.is_empty():
		return
	for r in steps:
		var sid := CsvUtil.s(r, "step_id")
		if not CsvUtil.list(CsvUtil.s(r, "trigger_ref_ids")).has(tg.attack.id):
			continue
		var st := PlayerState.tutorial_state(sid)
		if st.get("done", false) or int(st.get("shown", 0)) >= CsvUtil.i(r, "max_show_count", 1):
			continue
		st["shown"] = int(st.get("shown", 0)) + 1
		PlayerState.set_tutorial_state(sid, st)
		active_step = r
		active_tg = tg
		var scale := CsvUtil.f(r, "time_scale", 1.0)
		var dur := CsvUtil.f(r, "time_scale_duration_s", 0.0)
		if scale < 1.0:
			battle.start_slowmo(scale, dur if dur > 0.0 else tg.warn)
		var sub := auto_subtext(r) if PlayerState.auto_battle else ""
		hint_shown.emit(sid, hint_text(r) + ("\n" + sub if sub != "" else ""))
		return

## 自动模式附加小字：ui_target 中“小字“……””的内容（文案来自表）
static func auto_subtext(row: Dictionary) -> String:
	var ui := CsvUtil.s(row, "ui_target")
	var k := ui.find("小字“")
	if k < 0:
		return ""
	var a := k + 2
	var b := ui.find("”", a + 1)
	return ui.substr(a + 1, b - a - 1) if b > a else ""

## 战斗提前结束/换关时撤销进行中的提示（BUG-002）：收起提示、恢复1倍速、清空状态。
## 本次提示没有完整看完，不计入 max_show_count（shown 回退1），下一次天坠预警会再提示。
func cancel_active() -> void:
	if active_step.is_empty():
		return
	var sid := CsvUtil.s(active_step, "step_id")
	var st := PlayerState.tutorial_state(sid)
	if not st.get("done", false):
		st["shown"] = maxi(int(st.get("shown", 0)) - 1, 0)
		PlayerState.set_tutorial_state(sid, st)
	battle.stop_slowmo()
	active_step = {}
	active_tg = null
	hint_hidden.emit(sid, false)

func is_active_for(tg: Telegraph) -> bool:
	return not active_step.is_empty() and active_tg == tg

func on_telegraph_resolved(tg: Telegraph, dodged: bool) -> void:
	if active_step.is_empty() or tg != active_tg:
		return
	var sid := CsvUtil.s(active_step, "step_id")
	var st := PlayerState.tutorial_state(sid)
	if dodged or int(st.get("shown", 0)) >= CsvUtil.i(active_step, "max_show_count", 1):
		st["done"] = true
		PlayerState.set_tutorial_state(sid, st)
	if dodged:
		battle.float_text(battle.player.position + Vector2(0, -200), "闪避成功", Color("#3E8E7E"), 30)
	battle.stop_slowmo()
	active_step = {}
	active_tg = null
	hint_hidden.emit(sid, dodged)

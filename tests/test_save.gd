extends TestCase
## 阶段6：存档 / 迁移 / 损坏恢复 / 原子写入 / 导入校验 / 离线收益（时钟回拨、封顶、重复领取、背包满）/ 自动存档触发。
## 全部在 user://test_saves/<用例>/ 下进行，不碰真实存档；时间用 SaveSystem.clock_override 固定。

const T0 := 1_800_000_000   # 固定“现在”（2027-01-15）

var _n := 0

func _dir() -> String:
	_n += 1
	var d := "user://test_saves/%s_%d" % [_current, _n]
	_wipe(d)
	DirAccess.make_dir_recursive_absolute(d)
	return d

static func _wipe(d: String) -> void:
	var da := DirAccess.open(d)
	if da:
		for f in da.get_files():
			da.remove(f)

func _files(d: String) -> PackedStringArray:
	var da := DirAccess.open(d)
	return da.get_files() if da else PackedStringArray()

## 启用存档系统（测试目录、固定时钟、模拟 localStorage）
func _on(d: String, now: int = T0, mirror: bool = false) -> void:
	SaveSystem.dir = d
	SaveSystem.clock_override = now
	SaveSystem.enabled = true
	SaveSystem.write_blocked = false
	SaveSystem.booted = false
	SaveSystem._web_mirror_override = {} if mirror else null
	SaveSystem._pending_reasons.clear()
	SaveSystem.save_count = 0

func _off() -> void:
	SaveSystem.enabled = false
	SaveSystem.write_blocked = false
	SaveSystem.dir = "user://"
	SaveSystem.clock_override = -1
	SaveSystem._web_mirror_override = null
	SaveSystem._pending_reasons.clear()
	SaveSystem._flush_queued = false
	SaveSystem._set_status("off")

func _write(p: String, text: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE); f.store_string(text); f.close()

func _read(p: String) -> String:
	return FileAccess.get_file_as_string(p)

## 一份有内容的进度：通关 1-1..1-3、学技能、灵石、背包装备、不稳定标记
func _progress() -> void:
	PlayerState.debug_fill_demo()
	for id in ["LV_1_1", "LV_1_2", "LV_1_3"]:
		PlayerState.cleared_levels[id] = true
	PlayerState.lingshi = 12345; PlayerState.xiuwei = 678
	PlayerState.unstable_levels["LV_1_3"] = true
	PlayerState.auto_fail_counts["LV_1_3"] = 2
	PlayerState.telegraph_alt = true
	PlayerState.auto_battle = false

func _env_text() -> String:
	return SaveCodec.serialize(SaveCodec.make_envelope(PlayerState.to_dict(), T0))

# ---------- 往返 ----------
func test_roundtrip_save_load() -> void:
	var d := _dir(); _on(d)
	_progress()
	var before := SaveCodec.canonical_json(PlayerState.to_dict())
	check(SaveSystem.save_now("test"), "保存成功")
	check(FileAccess.file_exists(d + "/save.json") and not FileAccess.file_exists(d + "/save.json.tmp"), "写 save.json，tmp 已改名")
	var env: Dictionary = JSON.parse_string(_read(d + "/save.json"))
	eq(int(env.save_version), SaveCodec.SAVE_VERSION, "信封 save_version")
	check(env.has("game_version") and env.has("saved_at") and str(env.checksum).begins_with("sha256:"), "信封字段齐全")
	eq(int(env.saved_at), T0, "saved_at = 现在")
	check(not str(env.data).contains("debug_"), "debug_* 不进存档")
	PlayerState.reset_new_game()
	var r := SaveSystem.load_best()
	eq(r.code, "ok", "读档 ok")
	PlayerState.from_dict(r.data)
	var after := PlayerState.to_dict()
	# 保存时 last_settle_at / max_seen_at 推到现在，其余字段完全一致
	var b: Dictionary = JSON.parse_string(before); b.last_settle_at = T0; b.max_seen_at = T0
	eq(SaveCodec.canonical_json(after), SaveCodec.canonical_json(b), "存→读 全字段一致")
	check(PlayerState.is_unstable("LV_1_3") and int(PlayerState.auto_fail_counts["LV_1_3"]) == 2, "自动失败标记 / 计数持久化")
	check(PlayerState.telegraph_alt and not PlayerState.auto_battle, "设置（统一预警白 / 自动战斗）持久化")
	_off()

func test_second_save_rotates_bak() -> void:
	var d := _dir(); _on(d)
	PlayerState.lingshi = 1; SaveSystem.save_now()
	PlayerState.lingshi = 2; SaveSystem.clock_override = T0 + 10; SaveSystem.save_now()
	var bak: Dictionary = JSON.parse_string(_read(d + "/save.json.bak"))
	var cur: Dictionary = JSON.parse_string(_read(d + "/save.json"))
	eq(int(bak.data.lingshi), 1, ".bak = 上一份")
	eq(int(cur.data.lingshi), 2, "save.json = 最新")
	_off()

func test_from_dict_merges_defaults() -> void:
	var d := PlayerState.to_dict()
	d.erase("telegraph_alt"); d.erase("pending_offline"); d.erase("tutorial"); d.erase("slot_auto")
	d.lingshi = 77
	PlayerState.telegraph_alt = true
	PlayerState.from_dict(d)
	eq(PlayerState.lingshi, 77, "提供的字段覆盖")
	check(PlayerState.telegraph_alt == false and PlayerState.pending_offline.is_empty(), "缺失字段取 reset_new_game 默认")
	eq(PlayerState.slot_auto.size(), PlayerState.slot_count(), "slot_auto 默认长度")

# ---------- 迁移 ----------
func test_migration_v0_bare_dict() -> void:
	_progress()
	var v0 := PlayerState.to_dict()
	for k in ["last_settle_at", "max_seen_at", "pending_offline", "telegraph_alt"]:
		v0.erase(k)
	var dec := SaveCodec.decode(JSON.stringify(v0), T0, true)
	check(dec.ok, "v0（阶段1-5 裸字典）可读：%s %s" % [dec.code, dec.detail])
	eq(dec.version, 0, "识别为 v0")
	eq(int(dec.data.last_settle_at), 0, "v0→v1 补 last_settle_at=0（不产生离线收益）")
	check((dec.data.pending_offline as Dictionary).is_empty(), "补 pending_offline")
	eq(int(dec.data.lingshi), 12345, "原有字段保留")

func test_migration_chain_and_too_new() -> void:
	var calls: Array = []
	var migs := {
		1: func(d: Dictionary) -> Dictionary: calls.append(1); d["v2_field"] = "a"; return d,
		2: func(d: Dictionary) -> Dictionary: calls.append(2); d["v3_field"] = str(d.get("v2_field", "")) + "b"; return d,
	}
	var src := {"x": 1}
	var m := SaveCodec.migrate(src, 1, migs, 3)
	check(m.ok, "v1→v3 链式迁移")
	eq(calls, [1, 2], "逐级执行")
	eq(m.data.get("v3_field"), "ab", "每步拿到上一步结果")
	check(not src.has("v2_field"), "纯函数：不改输入")
	check(not SaveCodec.migrate(src, 0, migs, 3).ok, "缺迁移步骤 → 失败")
	# 信封版本高于游戏 → too_new
	var env := SaveCodec.make_envelope(PlayerState.to_dict(), T0)
	env.save_version = SaveCodec.SAVE_VERSION + 1
	eq(SaveCodec.decode(SaveCodec.serialize(env), T0, true).code, "too_new", "高版本拒读")

func test_too_new_save_not_overwritten() -> void:
	var d := _dir(); _on(d)
	var env := SaveCodec.make_envelope(PlayerState.to_dict(), T0)
	env.save_version = 99
	var text := SaveCodec.serialize(env)
	_write(d + "/save.json", text)
	SaveSystem.enabled = false
	var r := SaveSystem.boot()
	eq(r.code, "too_new", "启动：高版本存档")
	check(SaveSystem.write_blocked and not SaveSystem.enabled, "本次运行不写盘")
	check(not SaveSystem.save_now("x"), "save_now 被拒")
	eq(_read(d + "/save.json"), text, "原文件未被覆盖")
	_off()

# ---------- 损坏恢复 ----------
func test_corrupt_main_recovers_from_bak() -> void:
	var d := _dir(); _on(d)
	PlayerState.lingshi = 111; SaveSystem.save_now()
	PlayerState.lingshi = 222; SaveSystem.clock_override = T0 + 10; SaveSystem.save_now()
	_write(d + "/save.json", "{\"save_version\": 1, \"data\": {tru")   # 写坏主存档
	PlayerState.reset_new_game()
	var r := SaveSystem.load_best()
	eq(r.code, "recovered", "主存档坏 → 回退备份")
	eq(r.source, "save.json.bak", "来源 .bak")
	eq(int(r.data.lingshi), 111, "备份内容")
	eq(r.corrupt_files.size(), 1, "坏主存档改名保留")
	check(str(r.corrupt_files[0]).begins_with("save.corrupt.") and FileAccess.file_exists(d + "/" + str(r.corrupt_files[0])), "save.corrupt.<时间>.json 存在")
	check(not FileAccess.file_exists(d + "/save.json"), "坏文件已移走（下次写入不会把它轮换成 .bak）")
	_off()

func test_checksum_mismatch_counts_as_corrupt() -> void:
	var d := _dir(); _on(d)
	PlayerState.lingshi = 5; SaveSystem.save_now()
	PlayerState.lingshi = 6; SaveSystem.clock_override = T0 + 10; SaveSystem.save_now()
	var t := _read(d + "/save.json").replace("\"lingshi\": 6", "\"lingshi\": 999999")
	_write(d + "/save.json", t)
	var r := SaveSystem.load_best()
	eq(r.code, "recovered", "校验和不符 → 视为损坏")
	eq(int(r.data.lingshi), 5, "用备份")
	_off()

func test_leftover_tmp_used_when_main_missing() -> void:
	var d := _dir(); _on(d)
	PlayerState.lingshi = 9
	_write(d + "/save.json.tmp", _env_text())   # 模拟写完 tmp 后崩溃
	var r := SaveSystem.load_best()
	eq(r.source, "save.json.tmp", "主存档 / 备份都没有 → 用校验通过的 tmp")
	eq(int(r.data.lingshi), 9, "tmp 内容")
	_off()

func test_all_corrupt_new_game_never_crash() -> void:
	var d := _dir(); _on(d)
	_write(d + "/save.json", "garbage")
	_write(d + "/save.json.bak", "{}")
	_write(d + "/save.json.tmp", "")
	PlayerState.lingshi = 4242
	SaveSystem.enabled = false
	var r := SaveSystem.boot()
	eq(r.code, "corrupt", "全部损坏")
	eq(PlayerState.lingshi, 0, "开新档")
	eq((r.corrupt_files as Array).size(), 3, "三份坏文件都改名保留")
	check(FileAccess.file_exists(d + "/save.json"), "随即写入新档")
	var ok := 0
	for f in _files(d):
		if f.begins_with("save.corrupt."):
			ok += 1
	eq(ok, 3, "save.corrupt.* ×3")
	_off()

func test_web_mirror_newer_wins() -> void:
	var d := _dir(); _on(d, T0, true)
	PlayerState.lingshi = 1; SaveSystem.save_now()
	# 模拟：切后台时写了 localStorage，但 IndexedDB 异步同步没赶上（文件仍是旧的）
	PlayerState.lingshi = 2
	SaveSystem._web_mirror_override[SaveSystem.WEB_MIRROR_KEY] = SaveCodec.serialize(SaveCodec.make_envelope(PlayerState.to_dict(), T0 + 30))
	var r := SaveSystem.load_best()
	eq(r.source, "localStorage", "镜像较新 → 用镜像")
	eq(int(r.data.lingshi), 2, "镜像内容")
	eq(r.code, "ok", "不算损坏")
	_off()

# ---------- 导入校验 ----------
func _import_rejected(text: String, code: String, why: String) -> void:
	var d := _dir(); _on(d)
	_progress(); SaveSystem.save_now()
	var before := SaveCodec.canonical_json(PlayerState.to_dict())
	var file_before := _read(d + "/save.json")
	var r := SaveSystem.import_string(text)
	check(not r.ok, "%s：被拒" % why)
	eq(r.code, code, "%s：错误码（%s）" % [why, r.detail])
	eq(SaveCodec.canonical_json(PlayerState.to_dict()), before, "%s：当前进度不变" % why)
	eq(_read(d + "/save.json"), file_before, "%s：存档文件不变" % why)
	_off()

func _env_with(mut: Callable) -> String:
	PlayerState.reset_new_game()
	PlayerState.debug_fill_demo()
	var data := PlayerState.to_dict()
	mut.call(data)
	return SaveCodec.serialize(SaveCodec.make_envelope(data, T0))

func test_import_rejects_invalid() -> void:
	_import_rejected("not json {", "parse", "非法 JSON")
	_import_rejected("[1,2,3]", "parse", "顶层不是对象")
	_import_rejected("x".repeat(SaveCodec.MAX_BYTES + 10), "too_big", "超过 1MB")
	_import_rejected(_env_with(func(d: Dictionary) -> void: d.erase("realm_id")), "fields", "缺必要字段")
	_import_rejected(_env_with(func(d: Dictionary) -> void: d.lingshi = -5), "range", "负灵石")
	_import_rejected(_env_with(func(d: Dictionary) -> void: d.lingshi = 1.5), "fields", "小数灵石")
	_import_rejected(_env_with(func(d: Dictionary) -> void: d.lingshi = "100"), "fields", "字符串灵石")
	_import_rejected(_env_with(func(d: Dictionary) -> void: d.xiuwei = SaveCodec.MAX_CURRENCY + 1), "range", "修为超上限")
	_import_rejected(_env_with(func(d: Dictionary) -> void: d.realm_id = "RL_NOPE"), "ids", "未知境界")
	_import_rejected(_env_with(func(d: Dictionary) -> void: d.learned_skills = {"SK_SWORD_FLYING": 99}), "range", "技能等级超上限")
	_import_rejected(_env_with(func(d: Dictionary) -> void: d.active_slots = ["", ""]), "fields", "技能栏长度不对")
	_import_rejected(_env_with(func(d: Dictionary) -> void: d.active_slots = ["SK_SWORD_FLYING", "SK_SWORD_FLYING", "", ""]; d.learned_skills = {"SK_SWORD_FLYING": 1}), "rules", "同技能占两槽")
	_import_rejected(_env_with(func(d: Dictionary) -> void: d.learned_skills = {}; d.active_slots = ["SK_SWORD_FLYING", "", "", ""]), "rules", "未学技能上槽")
	_import_rejected(_env_with(func(d: Dictionary) -> void:
		var g: Variant = (d.bag as Array)[0] if not (d.bag as Array).is_empty() else {"uid": 1, "base_id": "EQB_WEAPON_T1", "quality_id": "Q_WHITE", "affixes": []}
		var big := []
		for i in PlayerState.bag_capacity() + 1:
			big.append(g)
		d.bag = big), "range", "背包超容量")
	var env := SaveCodec.make_envelope(PlayerState.to_dict(), T0); env.save_version = 9
	_import_rejected(SaveCodec.serialize(env), "too_new", "版本更高")
	PlayerState.reset_new_game()
	var env2 := SaveCodec.make_envelope(PlayerState.to_dict(), T0)
	env2.data.lingshi = 999999   # 改了数据但没改校验和
	_import_rejected(SaveCodec.serialize(env2), "checksum", "校验和不符（文件被改 / 损坏）")
	PlayerState.reset_new_game()
	var nan := SaveCodec.serialize(SaveCodec.make_envelope(PlayerState.to_dict(), T0))
	check(nan.contains("\"xiuwei\": 0"), "夹具含 xiuwei")
	_import_rejected(nan.replace("\"xiuwei\": 0", "\"xiuwei\": NaN"), "parse", "NaN")

func test_import_drops_unknown_ids_and_clamps_time() -> void:
	var d := _dir(); _on(d)
	_progress()
	var text := _env_with(func(dd: Dictionary) -> void:
		dd.books["BK_NOT_EXIST"] = 3
		dd.cleared_levels.append("LV_9_9")
		(dd.bag as Array).append({"uid": 9999, "base_id": "EQB_GONE", "quality_id": "Q_WHITE", "affixes": []})
		dd.last_settle_at = T0 + 86400 * 30   # 未来时间
		dd.max_seen_at = T0 + 86400 * 30)
	var r := SaveSystem.import_string(text)
	check(r.ok, "未知 ID 丢弃后导入成功：%s %s" % [r.code, r.detail])
	check((r.dropped as Array).size() >= 3, "记录丢弃项 %s" % str(r.dropped))
	check(not PlayerState.books.has("BK_NOT_EXIST") and not PlayerState.cleared_levels.has("LV_9_9"), "未知书 / 关卡已丢弃")
	eq(PlayerState.last_settle_at, T0, "导入后 last_settle_at = 现在（导入不制造离线收益）")
	eq(PlayerState.max_seen_at, T0, "导入的未来 max_seen_at 夹到现在")
	check(FileAccess.file_exists(d + "/save.before_import.json"), "导入前自动备份")
	_off()

func test_import_export_string_roundtrip() -> void:
	var d := _dir(); _on(d)
	_progress()
	var s := SaveSystem.export_string()
	var snap := SaveCodec.canonical_json(PlayerState.to_dict())
	PlayerState.reset_new_game()
	var r := SaveSystem.import_string(s)
	check(r.ok, "导出串可导入")
	eq(SaveCodec.canonical_json(PlayerState.to_dict()), snap, "导出→导入 全字段一致")
	check(SaveSystem.export_file_name().begins_with("replayxian_save_") and SaveSystem.export_file_name().ends_with(".json"), "导出文件名")
	_off()

func test_uid_duplicates_reassigned() -> void:
	PlayerState.debug_fill_demo()
	var data := PlayerState.to_dict()
	for g in data.bag:
		g.uid = 5
	var v := SaveCodec.validate_data(data, T0, true)
	check(v.ok, "重复 uid 不拒绝")
	var seen := {}
	for g in v.data.bag:
		check(int(g.uid) > 0 and not seen.has(int(g.uid)), "uid 唯一且非 0")
		seen[int(g.uid)] = true
	check(int(v.data.next_uid) > seen.keys().max(), "next_uid 大于全部 uid")

# ---------- 重置 ----------
func test_reset_backs_up_first() -> void:
	var d := _dir(); _on(d)
	_progress(); SaveSystem.save_now()
	var old := _read(d + "/save.json")
	check(SaveSystem.reset_game(), "重置")
	eq(PlayerState.lingshi, 0, "新档")
	eq(_read(d + "/save.before_reset.json"), old, "重置前备份 = 旧存档")
	eq(_read(d + "/save.json.bak"), old, "旧档同时轮换为 .bak")
	_off()

# ---------- 离线收益 ----------
func _rng(seed_v: int = 7) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = seed_v
	return r

func _cleared(id: String = "LV_1_3") -> void:
	for l in GameData.levels_ordered:
		PlayerState.cleared_levels[l.id] = true
		if l.id == id:
			break

func test_offline_basic_rates_from_table() -> void:
	_cleared("LV_1_3")
	PlayerState.last_settle_at = T0; PlayerState.max_seen_at = T0
	var r := OfflineSystem.settle(T0 + 60 * 60, _rng())
	eq(r.code, "ok", "1 小时")
	eq(r.minutes, 60, "60 分钟")
	var row := OfflineSystem.row_for_level("LV_1_3")
	var p := PlayerState.pending_offline
	eq(p.level_id, "LV_1_3", "按最近已通关关卡")
	eq(int(p.lingshi), int(floor(CsvUtil.f(row, "lingshi_per_min") * 60)), "灵石 = 每分钟 × 分钟")
	eq(int(p.xiuwei), int(floor(CsvUtil.f(row, "xiuwei_per_min") * 60)), "修为")
	eq(int(p.items.get("MAT_REFINE", 0)), int(floor(CsvUtil.f(row, "refine_per_min") * 60)), "炼器材料")
	var exp_g := CsvUtil.f(row, "equip_per_min") * 60
	check((p.gear as Array).size() == int(floor(exp_g)) or (p.gear as Array).size() == int(floor(exp_g)) + 1, "装备件数 ≈ 每分钟期望 × 分钟")
	for gd in p.gear:
		check(str(gd.quality_id) != GameData.qualities_ordered().back().id, "离线不出橙")
	eq(PlayerState.last_settle_at, T0 + 3600, "结算后 last_settle_at = now")

func test_offline_cap_8h() -> void:
	_cleared("LV_2_1")
	PlayerState.last_settle_at = T0; PlayerState.max_seen_at = T0
	var r := OfflineSystem.settle(T0 + 3 * 86400, _rng())
	eq(r.minutes, 480, "3 天 → 封顶 480 分钟（OFFLINE_CAP_MINUTES / cap_minutes）")
	check(r.capped and bool(PlayerState.pending_offline.capped), "标记已封顶")
	# 未领取又离线：合并后总分钟数仍不超过上限
	var r2 := OfflineSystem.settle(T0 + 4 * 86400, _rng(8))
	eq(OfflineSystem.pending_minutes(), 480, "未领取 + 再次离线：合计仍 ≤ 480")
	check(r2.code != "ok", "已满不再生成")

func test_offline_clock_rollback_zero() -> void:
	_cleared("LV_1_3")
	PlayerState.last_settle_at = T0; PlayerState.max_seen_at = T0
	var r := OfflineSystem.settle(T0 - 86400, _rng())   # 系统时间往回拨一天
	eq(r.code, "rollback", "时钟回拨")
	check(PlayerState.pending_offline.is_empty(), "回拨得 0")
	eq(PlayerState.max_seen_at, T0, "max_seen_at 不回改")
	# 再把时间拨到“比回拨点晚 8 小时但仍早于 max_seen_at”：仍为 0（防先回拨再拨回刷收益）
	var r2 := OfflineSystem.settle(T0 - 86400 + 8 * 3600, _rng())
	eq(r2.code, "rollback", "仍早于见过的最大时间 → 0")
	check(PlayerState.pending_offline.is_empty(), "依旧 0")
	# 负时间差（last_settle_at 在未来，但不早于 max_seen_at 的情况由校验夹到 now）
	PlayerState.last_settle_at = T0 + 999; PlayerState.max_seen_at = T0
	var r3 := OfflineSystem.settle(T0 + 10, _rng())
	eq(r3.minutes, 0, "负时间差按 0")

func test_offline_requires_clear() -> void:
	PlayerState.last_settle_at = T0; PlayerState.max_seen_at = T0
	var r := OfflineSystem.settle(T0 + 3600, _rng())
	eq(r.code, "no_clear", "未通关任何关卡不产生")
	check(PlayerState.pending_offline.is_empty(), "无 pending")

func test_offline_claim_once_and_persist_across_restart() -> void:
	var d := _dir(); _on(d, T0)
	_cleared("LV_1_3")
	SaveSystem.save_now()
	# “关游戏” 2 小时后启动
	SaveSystem.clock_override = T0 + 7200
	SaveSystem.enabled = false
	var b := SaveSystem.boot()
	eq(b.offline.code, "ok", "启动结算")
	var p := PlayerState.pending_offline.duplicate(true)
	check(int(p.minutes) == 120, "120 分钟")
	# 不领取，直接再“重启”：pending 保留，且不会因同一段离线再生成
	SaveSystem.enabled = false
	var b2 := SaveSystem.boot()
	check(b2.offline.code != "ok", "重启不重复生成")
	eq(SaveCodec.canonical_json(PlayerState.pending_offline), SaveCodec.canonical_json(p), "pending 跨重启保留，随机结果不变")
	var ls := PlayerState.lingshi
	var c := OfflineSystem.claim()
	eq(c.code, "ok", "领取")
	eq(PlayerState.lingshi, ls + int(p.lingshi), "发放灵石")
	check(PlayerState.pending_offline.is_empty(), "领取后清空")
	await runner.get_tree().process_frame
	eq(SaveSystem.last_reason, "offline_claim", "领取后立即存档")
	eq(OfflineSystem.claim().code, "none", "重复领取 → none")
	SaveSystem.enabled = false
	SaveSystem.boot()
	check(PlayerState.pending_offline.is_empty() and PlayerState.lingshi == ls + int(p.lingshi), "重启后不能再领")
	_off()

## 背包满：按策划表 equip_per_min 说明“溢出转材料”——放不下的装备转为炼器材料（与在线 add_gear 规则一致）
func test_offline_bag_full_overflow_to_refine() -> void:
	_cleared("LV_1_3")
	while PlayerState.bag.size() < PlayerState.bag_capacity():
		PlayerState.bag.append(GearSystem.make_item("EQB_WEAPON_T1", "Q_WHITE", PlayerState.rng))
	PlayerState.last_settle_at = T0; PlayerState.max_seen_at = T0
	OfflineSystem.settle(T0 + 480 * 60, _rng())
	var n := (PlayerState.pending_offline.gear as Array).size()
	check(n > 0, "8 小时有装备掉落（%d 件）" % n)
	eq(OfflineSystem.overflow_preview(), n, "预览：全部溢出")
	var refine := PlayerState.item_count("MAT_REFINE")
	var pend_refine := int(PlayerState.pending_offline.items.get("MAT_REFINE", 0))
	var c := OfflineSystem.claim()
	eq(c.gear_overflow, n, "全部溢出")
	eq(PlayerState.bag.size(), PlayerState.bag_capacity(), "背包不超容量")
	check(c.refine_from_gear > 0, "溢出装备转炼器材料 %d" % c.refine_from_gear)
	eq(PlayerState.item_count("MAT_REFINE"), refine + pend_refine + int(c.refine_from_gear), "材料 = 原有 + 离线材料 + 溢出转换")
	check(PlayerState.pending_offline.is_empty(), "不留在 pending")

func test_offline_paused_time_not_counted() -> void:
	# 在线（含面板暂停）每次自动存档都把 last_settle_at 推到现在 → 关游戏时只剩最后一个存档间隔
	var d := _dir(); _on(d, T0)
	_cleared("LV_1_3")
	runner.get_tree().paused = true
	SaveSystem.clock_override = T0 + 600
	SaveSystem._process(SaveSystem.autosave_interval() + 0.1)
	runner.get_tree().paused = false
	eq(PlayerState.last_settle_at, T0 + 600, "暂停中自动存档照常推进 last_settle_at")
	eq(SaveSystem.last_reason, "autosave", "10 秒自动存档")
	_off()

# ---------- 自动存档 / 防抖 ----------
func test_autosave_interval_from_table() -> void:
	var d := _dir(); _on(d)
	near(SaveSystem.autosave_interval(), GameData.const_f("AUTOSAVE_INTERVAL", -1), 0.001, "间隔读表 AUTOSAVE_INTERVAL")
	SaveSystem._autosave_t = 0.0
	SaveSystem._process(SaveSystem.autosave_interval() - 0.5)
	eq(SaveSystem.save_count, 0, "未到间隔不存")
	SaveSystem._process(0.6)
	eq(SaveSystem.save_count, 1, "到间隔存一次")
	_off()

func test_important_actions_trigger_debounced_save() -> void:
	var d := _dir(); _on(d)
	# 同一帧多个重要操作只写一次
	PlayerState.learn_skill_debug("SK_SWORD_COMBO", 1)
	PlayerState.add_book("BK_SWORD_PIERCE", 1)
	PlayerState.learn_book("BK_SWORD_PIERCE")
	PlayerState.lingshi = 999999
	PlayerState.upgrade_skill("SK_SWORD_PIERCE")
	PlayerState.place_skill(3, "SK_SWORD_PIERCE")
	PlayerState.set_telegraph_alt(true)
	eq(SaveSystem.save_count, 0, "同帧内尚未写盘")
	await runner.get_tree().process_frame
	eq(SaveSystem.save_count, 1, "帧末合并为一次写盘")
	for r in ["learn", "upgrade", "loadout", "settings"]:
		check(SaveSystem.last_reason.contains(r), "原因含 %s（%s）" % [r, SaveSystem.last_reason])
	# 其余触发点：换装 / 首通 / 三选一 / 突破 / 自动失败标记
	var cases := {
		"equip": func() -> void:
			var g := GearSystem.make_item("EQB_WEAPON_T2", "Q_BLUE", PlayerState.rng); PlayerState.add_gear(g); PlayerState.equip_gear(g.uid),
		"first_clear": func() -> void: PlayerState.mark_cleared("LV_1_1"),
		"orange_pick": func() -> void:
			PlayerState.add_orange_choice(["EQB_CORE_SWORD", "EQB_CORE_THUNDER", "EQB_CORE_GANG"]); PlayerState.choose_orange(0, "EQB_CORE_SWORD"),
		"breakthrough": func() -> void:
			var nx := PlayerState.next_realm()
			PlayerState.xiuwei = nx.xiuwei_cost; PlayerState.lingshi = nx.lingshi_cost
			if nx.material_id != "": PlayerState.add_item(nx.material_id, nx.material_count)
			PlayerState.breakthrough(),
		"auto_fail_mark": func() -> void: PlayerState.record_auto_failure("LV_1_2"),
	}
	for k in cases:
		var n := SaveSystem.save_count
		(cases[k] as Callable).call()
		await runner.get_tree().process_frame
		eq(SaveSystem.save_count, n + 1, "%s 触发一次存档" % k)
		check(SaveSystem.last_reason.contains(k), "原因 %s（%s）" % [k, SaveSystem.last_reason])
	_off()

func test_disabled_by_default_in_headless() -> void:
	check(not SaveSystem.should_boot(), "无头测试运行不启用存档（不碰 user://）")
	check(not SaveSystem.enabled, "默认未启用")
	var n := SaveSystem.save_count
	PlayerState.mark_cleared("LV_1_1")
	await runner.get_tree().process_frame
	eq(SaveSystem.save_count, n, "未启用时重要操作不写盘")

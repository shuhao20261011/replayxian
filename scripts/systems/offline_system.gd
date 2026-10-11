class_name OfflineSystem
extends RefCounted
## 离线收益（阶段6，dev_plan 第9节 + offline_rewards.csv + 后端审查第3节；规则全文见 docs/SAVE_FORMAT.md 第5节）。
## - settle(now)：读档时调用一次。delta = clamp(now - last_settle_at, 0, 上限)；now < max_seen_at（时钟回拨）→ 本次 0，max_seen_at 不回改。
##   按“最近已通关关卡”的 offline_rewards 行把收益（含随机装备 / 概率技能书）一次算定写进 PlayerState.pending_offline，
##   同时 last_settle_at = now（调用方随后立即存档）→ 重开游戏不会重复生成；未领取的 pending 跨重启保留，合并后总分钟数不超过上限。
## - claim()：发放 pending 并清空（之后立即存档）；pending 为空返回 "none"（防重复领取）。
## - 背包满：策划表 equip_per_min 说明“配合背包100件与溢出转材料” → 领取时按 add_gear 的溢出规则把放不下的装备转为炼器材料
##   （自动分解设置同样生效；橙装不会出现在离线掉落里）。是否改为“留在 pending”待策划确认（docs/SAVE_FORMAT.md 5.6）。
## - 在线时每次存档都把 last_settle_at 推到 now（SaveSystem），养成面板暂停期间也照常推进 → 暂停不额外产生离线收益。

const MIN_MINUTES_DEFAULT := 1

static func cap_minutes(row: Dictionary = {}) -> int:
	var cap := GameData.const_i("OFFLINE_CAP_MINUTES", 480)
	if not row.is_empty() and CsvUtil.i(row, "cap_minutes", 0) > 0:
		cap = mini(cap, CsvUtil.i(row, "cap_minutes", cap))
	return maxi(cap, 0)

static func min_minutes() -> int:
	return maxi(GameData.const_i("OFFLINE_MIN_MINUTES", MIN_MINUTES_DEFAULT), 1)

static func row_for_level(level_id: String) -> Dictionary:
	for r in GameData.tables.get("offline_rewards", []):
		if CsvUtil.s(r, "level_id") == level_id:
			return r
	return {}

## 关卡普通怪掉落表里装备行的档位（离线装备与在线普通怪同档、同品质权重组 = 表里 weight_set_id）
static func gear_tier_for(level: LevelDef) -> int:
	for r in GameData.drop_tables.get(level.normal_drop_table_id, []):
		if CsvUtil.s(r, "entry_type") == "equipment":
			return GameData.tier_from_ref(CsvUtil.s(r, "ref_id"))
	return 1

static func pending_minutes() -> int:
	return int(PlayerState.pending_offline.get("minutes", 0))

## 读档结算。返回 {code: ok|none|no_clear|rollback|too_short, minutes(本次新增), capped, delta_s}
static func settle(now: int, rng: RandomNumberGenerator) -> Dictionary:
	var ps := PlayerState
	var res := {"code": "none", "minutes": 0, "capped": false, "delta_s": 0}
	if now < ps.max_seen_at:
		res.code = "rollback"
		ps.last_settle_at = now
		return res
	var delta := maxi(now - ps.last_settle_at, 0) if ps.last_settle_at > 0 else 0
	ps.max_seen_at = maxi(ps.max_seen_at, now)
	ps.last_settle_at = now
	res.delta_s = delta
	var level := ps.last_cleared_level()
	if level == null:
		res.code = "no_clear"
		return res
	var row := row_for_level(level.id)
	if row.is_empty():
		return res
	var cap := cap_minutes(row)
	var mins := delta / 60
	var room := maxi(cap - pending_minutes(), 0)
	if mins > room:
		mins = room
		res.capped = true
	if mins < min_minutes():
		res.code = "too_short" if not res.capped else "capped_full"
		return res
	var add := roll(level, row, mins, rng)
	_merge_pending(add, now, res.capped or pending_minutes() + mins >= cap)
	res.code = "ok"; res.minutes = mins
	ps.offline_changed.emit()
	return res

## 按分钟数生成一份收益（纯函数；随机在此确定）
static func roll(level: LevelDef, row: Dictionary, minutes: int, rng: RandomNumberGenerator) -> Dictionary:
	var out := {"level_id": level.id, "minutes": minutes, "lingshi": 0, "xiuwei": 0, "items": {}, "books": {}, "gear": []}
	out.lingshi = int(floor(CsvUtil.f(row, "lingshi_per_min") * minutes))
	out.xiuwei = int(floor(CsvUtil.f(row, "xiuwei_per_min") * minutes))
	var refine := int(floor(CsvUtil.f(row, "refine_per_min") * minutes))
	if refine > 0:
		out.items["MAT_REFINE"] = refine
	var expect := CsvUtil.f(row, "equip_per_min") * minutes
	var n_gear := int(floor(expect)) + (1 if rng.randf() < expect - floor(expect) else 0)
	var tier := gear_tier_for(level)
	var ws := CsvUtil.s(row, "weight_set_id")
	for i in n_gear:
		var g := GearSystem.generate(tier, ws, rng)
		if g:
			g.uid = 0   # 领取时 add_gear 分配
			out.gear.append(g.to_dict())
	var p := CsvUtil.f(row, "book_chance_per_min")
	var pool := CsvUtil.s(row, "book_pool_id")
	for i in minutes:
		if rng.randf() < p:
			var bid := LootSystem.roll_book(pool, rng)
			if bid != "":
				out.books[bid] = int(out.books.get(bid, 0)) + 1
	return out

static func _merge_pending(add: Dictionary, now: int, capped: bool) -> void:
	var p: Dictionary = PlayerState.pending_offline
	if p.is_empty():
		p = {"level_id": add.level_id, "minutes": 0, "lingshi": 0, "xiuwei": 0, "items": {}, "books": {}, "gear": []}
	p.level_id = add.level_id
	p.minutes = int(p.minutes) + int(add.minutes)
	p.lingshi = int(p.lingshi) + int(add.lingshi)
	p.xiuwei = int(p.xiuwei) + int(add.xiuwei)
	for k in add.items:
		p.items[k] = int(p.items.get(k, 0)) + int(add.items[k])
	for k in add.books:
		p.books[k] = int(p.books.get(k, 0)) + int(add.books[k])
	(p.gear as Array).append_array(add.gear)
	p.capped = capped or bool(p.get("capped", false))
	p.settled_at = now
	PlayerState.pending_offline = p

## 领取预览：背包放不下（将转炼器材料）的件数（自动分解设置命中的不算溢出）
static func overflow_preview(p: Dictionary = PlayerState.pending_offline) -> int:
	var free := maxi(PlayerState.bag_capacity() - PlayerState.bag.size(), 0)
	var n := 0
	for gd in p.get("gear", []):
		var g := GearItem.from_dict(gd)
		var q := g.quality()
		var protected := q != null and not q.auto_decompose_allowed
		if not protected and bool(PlayerState.auto_decompose.get(g.quality_id, false)):
			continue
		if protected:
			continue
		if free > 0:
			free -= 1
		else:
			n += 1
	return n

## 领取：发放并清空 pending；返回 {code, lingshi, xiuwei, gear_in, gear_overflow, gear_auto, refine_from_gear, books, items}
static func claim() -> Dictionary:
	var p: Dictionary = PlayerState.pending_offline
	if p.is_empty() or int(p.get("minutes", 0)) <= 0:
		return {"code": "none"}
	PlayerState.pending_offline = {}   # 先清空再发放：发放中途出错也不会被领两次
	var res := {"code": "ok", "minutes": int(p.minutes), "lingshi": int(p.lingshi), "xiuwei": int(p.xiuwei),
		"gear_in": 0, "gear_overflow": 0, "gear_auto": 0, "refine_from_gear": 0, "books": (p.books as Dictionary).duplicate(), "items": (p.items as Dictionary).duplicate()}
	PlayerState.add_rewards(int(p.lingshi), int(p.xiuwei))
	for k in p.items:
		PlayerState.add_item(str(k), int(p.items[k]))
	for k in p.books:
		PlayerState.add_book(str(k), int(p.books[k]))
	for gd in p.gear:
		var g := GearItem.from_dict(gd)
		g.uid = 0
		var before := PlayerState.item_count("MAT_REFINE")
		match PlayerState.add_gear(g):
			"ok": res.gear_in += 1
			"overflow":
				res.gear_overflow += 1; res.refine_from_gear += PlayerState.item_count("MAT_REFINE") - before
			"auto_decomposed":
				res.gear_auto += 1; res.refine_from_gear += PlayerState.item_count("MAT_REFINE") - before
	PlayerState.offline_changed.emit()
	PlayerState.important_change.emit("offline_claim")
	return res

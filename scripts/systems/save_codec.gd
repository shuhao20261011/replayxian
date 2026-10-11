class_name SaveCodec
extends RefCounted
## 存档编解码（阶段6，纯函数，无文件读写）：信封 / 校验和 / 链式迁移 / 严格校验。规则全文：docs/SAVE_FORMAT.md。
## 信封：{save_version:int, game_version:String, saved_at:int(unix秒), checksum:"sha256:<hex>", data:{PlayerState.to_dict()}}
## checksum = sha256(canonical_json(data))，canonical = 整数值的浮点转 int + 键排序 + 默认精度（Godot JSON 读回 17 位浮点不精确，故不用 full_precision）；只用于发现损坏，不是防作弊。
## 迁移：migrations() = {n: Callable(data)->data}，把版本 n 升到 n+1，逐级执行，每步纯函数；高于 SAVE_VERSION 的存档拒读。
## v0 = 阶段1-5 的裸 PlayerState.to_dict()（无信封，调试导出 / 测试夹具），由 _v0_to_v1 补离线字段。

const SAVE_VERSION := 1
const MAX_BYTES := 1048576            # 导入 / 读档文件上限 1MB
const MAX_CURRENCY := 1000000000000   # 灵石 / 修为上限 1e12（远超正常游玩）
const MAX_STACK := 1000000            # 书 / 材料单项上限
const MAX_PENDING_GEAR := 2000
const REQUIRED := ["realm_id", "lingshi", "xiuwei", "learned_skills", "active_slots", "equipped", "bag", "cleared_levels"]

static func migrations() -> Dictionary:
	return {0: _v0_to_v1}

## v0 → v1：补离线结算字段（v0 没有时间戳 → 0 = 不产生离线收益）
static func _v0_to_v1(d: Dictionary) -> Dictionary:
	var o := d.duplicate(true)
	if not o.has("last_settle_at"): o["last_settle_at"] = 0
	if not o.has("max_seen_at"): o["max_seen_at"] = 0
	if not o.has("pending_offline"): o["pending_offline"] = {}
	if not o.has("telegraph_alt"): o["telegraph_alt"] = false
	return o

static func game_version() -> String:
	var b := BuildInfo.data()
	if str(b.get("commit", "")) == "":
		return "dev"
	return "stage%s+%s" % [str(b.get("stage", "")), str(b.commit)]

# ---------- 规范化 / 校验和 ----------
static func canon(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			if is_finite(f) and f == floor(f) and absf(f) <= 9.0e15:
				return int(f)
			return f
		TYPE_DICTIONARY:
			var o := {}
			for k in v:
				o[str(k)] = canon(v[k])
			return o
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			var a := []
			for x in v:
				a.append(canon(x))
			return a
		TYPE_STRING_NAME:
			return str(v)
	return v

static func canonical_json(v: Variant) -> String:
	return JSON.stringify(canon(v), "", true, false)

static func checksum(data: Dictionary) -> String:
	return "sha256:" + canonical_json(data).sha256_text()

static func make_envelope(data: Dictionary, saved_at: int) -> Dictionary:
	# 先过一遍 JSON 往返，保证写盘内容与读回后的校验和一致
	var rt: Variant = canon(JSON.parse_string(canonical_json(data)))
	return {"save_version": SAVE_VERSION, "game_version": game_version(), "saved_at": saved_at, "checksum": checksum(rt), "data": rt}

static func serialize(env: Dictionary) -> String:
	return JSON.stringify(canon(env), "\t", true, false)

# ---------- 解码管线：大小 → JSON → 信封 → 版本 → 校验和 → 迁移 → 校验 ----------
## 返回 {ok, code, data, version, saved_at, dropped:Array[String], detail}
## code：ok / too_big / parse / fields / too_new / checksum / migrate / range / ids / rules
static func decode(text: String, now: int, is_import: bool, migs: Dictionary = migrations(), target: int = SAVE_VERSION) -> Dictionary:
	var res := {"ok": false, "code": "parse", "data": {}, "version": -1, "saved_at": 0, "dropped": [], "detail": ""}
	if text.to_utf8_buffer().size() > MAX_BYTES:
		res.code = "too_big"; return res
	var j := JSON.new()
	if j.parse(text) != OK or typeof(j.data) != TYPE_DICTIONARY:
		res.detail = j.get_error_message(); return res
	var env: Dictionary = j.data
	var data: Variant
	var ver := 0
	if not env.has("save_version") and env.has("realm_id"):
		data = env   # v0：裸 PlayerState 字典
	else:
		var v: Variant = as_int(env.get("save_version"))
		if v == null or int(v) < 0:
			res.code = "fields"; res.detail = "save_version"; return res
		ver = int(v)
		data = env.get("data")
		if typeof(data) != TYPE_DICTIONARY:
			res.code = "fields"; res.detail = "data"; return res
		if ver > target:
			res.code = "too_new"; res.version = ver; return res
		if ver >= 1 and str(env.get("checksum", "")) != checksum(data):
			res.code = "checksum"; res.version = ver; return res
		var sa: Variant = as_int(env.get("saved_at", 0))
		res.saved_at = int(sa) if sa != null else 0
	res.version = ver
	var m := migrate(data, ver, migs, target)
	if not m.ok:
		res.code = "migrate"; res.detail = m.detail; return res
	var val := validate_data(m.data, now, is_import)
	res.dropped = val.dropped
	if not val.ok:
		res.code = val.code; res.detail = val.detail; return res
	res.ok = true; res.code = "ok"; res.data = val.data
	return res

## 链式迁移：from → target，逐级调用 migs[v]（纯函数，输入深拷贝）
static func migrate(data: Dictionary, from: int, migs: Dictionary, target: int = SAVE_VERSION) -> Dictionary:
	var d := data.duplicate(true)
	var v := from
	while v < target:
		if not migs.has(v):
			return {"ok": false, "detail": "no migration from v%d" % v, "data": {}}
		var out: Variant = (migs[v] as Callable).call(d.duplicate(true))
		if typeof(out) != TYPE_DICTIONARY:
			return {"ok": false, "detail": "migration v%d returned %s" % [v, type_string(typeof(out))], "data": {}}
		d = out
		v += 1
	return {"ok": true, "detail": "", "data": d}

# ---------- 严格校验（读档与导入共用） ----------
## JSON 数字是 float：只接受有限、无小数、|x|≤9e15 的数；其余（字符串、bool、NaN、小数）返回 null
static func as_int(v: Variant) -> Variant:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT:
		var f: float = v
		if is_finite(f) and f == floor(f) and absf(f) <= 9.0e15:
			return int(f)
	return null

static func _as_bool(v: Variant) -> Variant:
	if typeof(v) == TYPE_BOOL:
		return v
	var i: Variant = as_int(v)
	if i != null and (int(i) == 0 or int(i) == 1):
		return int(i) == 1
	return null

## 返回 {ok, code, detail, data(清洗后), dropped}。未知 ID 丢弃并记入 dropped（表更新后旧存档仍可读）；
## 类型错误 = fields，数值越界 = range，违反规则（未学技能上槽、同技能占两槽、境界不存在）= rules / ids。
static func validate_data(d: Dictionary, now: int, is_import: bool) -> Dictionary:
	var V := _Val.new()
	V.now = now
	V.is_import = is_import
	V.run(d)
	return {"ok": V.code == "ok", "code": V.code, "detail": V.detail, "data": V.out, "dropped": V.dropped}

class _Val:
	var now := 0
	var is_import := false
	var code := "ok"
	var detail := ""
	var out := {}
	var dropped: Array[String] = []
	var _uids := {}

	func fail(c: String, why: String) -> void:
		if code == "ok":
			code = c; detail = why

	func num(d: Dictionary, k: String, lo: int, hi: int, def: Variant = null) -> int:
		if not d.has(k):
			if def == null:
				fail("fields", "missing " + k)
				return 0
			return int(def)
		var v: Variant = SaveCodec.as_int(d[k])
		if v == null:
			fail("fields", "%s not integer" % k)
			return 0
		if int(v) < lo or int(v) > hi:
			fail("range", "%s=%d out of [%d,%d]" % [k, int(v), lo, hi])
			return 0
		return int(v)

	func boolean(d: Dictionary, k: String, def: bool) -> bool:
		if not d.has(k):
			return def
		var b: Variant = SaveCodec._as_bool(d[k])
		if b == null:
			fail("fields", "%s not bool" % k)
			return def
		return bool(b)

	func typed(d: Dictionary, k: String, t: int, def: Variant) -> Variant:
		if not d.has(k):
			if def == null:
				fail("fields", "missing " + k)
			return def
		if typeof(d[k]) != t:
			fail("fields", "%s wrong type" % k)
			return def
		return d[k]

	func count_map(src: Variant, exists: Callable, what: String) -> Dictionary:
		var o := {}
		if typeof(src) != TYPE_DICTIONARY:
			fail("fields", what + " not object")
			return o
		for k in src:
			var v: Variant = SaveCodec.as_int(src[k])
			if v == null:
				fail("fields", "%s.%s not integer" % [what, k]); continue
			if int(v) < 0 or int(v) > SaveCodec.MAX_STACK:
				fail("range", "%s.%s=%d" % [what, k, int(v)]); continue
			if not exists.call(str(k)):
				dropped.append("%s:%s" % [what, k]); continue
			o[str(k)] = int(v)
		return o

	## 装备：未知底子 / 品质 → 丢弃（返回 {}）；词条未知 → 丢该词条；数值非有限 → fields
	func gear(g: Variant, where: String) -> Dictionary:
		if typeof(g) != TYPE_DICTIONARY:
			fail("fields", where + " gear not object"); return {}
		var base_id := str(g.get("base_id", ""))
		var q_id := str(g.get("quality_id", ""))
		if GameData.get_base(base_id) == null or GameData.get_quality(q_id) == null:
			dropped.append("%s:%s/%s" % [where, base_id, q_id]); return {}
		var uid: Variant = SaveCodec.as_int(g.get("uid", 0))
		if uid == null or int(uid) < 0:
			fail("fields", where + " uid"); return {}
		var affs := []
		var src: Variant = g.get("affixes", [])
		if typeof(src) != TYPE_ARRAY or (src as Array).size() > 8:
			fail("fields", where + " affixes"); return {}
		for a in src:
			if typeof(a) != TYPE_DICTIONARY or not (typeof(a.get("value")) in [TYPE_INT, TYPE_FLOAT]) or not is_finite(float(a.get("value"))):
				fail("fields", where + " affix"); return {}
			if not GameData.affixes.has(str(a.get("affix_id", ""))):
				dropped.append("%s affix:%s" % [where, a.get("affix_id", "")]); continue
			affs.append({"affix_id": str(a.affix_id), "value": float(a.value)})
		var u := int(uid)
		if u == 0 or _uids.has(u):
			u = 0   # 重复 / 缺失 uid：稍后重新分配
		else:
			_uids[u] = true
		return {"uid": u, "base_id": base_id, "quality_id": q_id, "affixes": affs}

	func run(d: Dictionary) -> void:
		for k in SaveCodec.REQUIRED:
			if not d.has(k):
				fail("fields", "missing " + k); return
		var realm := str(d.realm_id) if typeof(d.realm_id) == TYPE_STRING else ""
		if GameData.get_realm(realm) == null:
			fail("ids", "realm_id " + str(d.realm_id)); return
		out.realm_id = realm
		out.lingshi = num(d, "lingshi", 0, SaveCodec.MAX_CURRENCY)
		out.xiuwei = num(d, "xiuwei", 0, SaveCodec.MAX_CURRENCY)
		# 技能
		var maxlv := GameData.const_i("SKILL_MAX_LEVEL", 10)
		var learned := {}
		var ls: Variant = typed(d, "learned_skills", TYPE_DICTIONARY, {})
		for k in ls:
			var lv: Variant = SaveCodec.as_int(ls[k])
			if lv == null:
				fail("fields", "learned_skills.%s" % k); continue
			if int(lv) < 1 or int(lv) > maxlv:
				fail("range", "learned_skills.%s=%d" % [k, int(lv)]); continue
			if GameData.get_skill(str(k)) == null:
				dropped.append("skill:%s" % k); continue
			learned[str(k)] = int(lv)
		out.learned_skills = learned
		var n_slots := PlayerState.slot_count()
		var slots: Variant = typed(d, "active_slots", TYPE_ARRAY, [])
		if (slots as Array).size() != n_slots:
			fail("fields", "active_slots size %d != %d" % [(slots as Array).size(), n_slots]); return
		var seen := {}
		var so: Array = []
		for x in slots:
			var sid := str(x) if typeof(x) == TYPE_STRING else "?"
			if sid == "?":
				fail("fields", "active_slots item"); return
			if sid == "":
				so.append(""); continue
			var sk := GameData.get_skill(sid)
			if sk == null:
				dropped.append("slot:%s" % sid); so.append(""); continue
			if not learned.has(sid) or not sk.is_active():
				fail("rules", "slot skill %s not learned/active" % sid); return
			if seen.has(sid):
				fail("rules", "skill %s in two slots" % sid); return
			seen[sid] = true
			so.append(sid)
		out.active_slots = so
		var sa: Variant = typed(d, "slot_auto", TYPE_ARRAY, [])
		var sao: Array = []
		for i in n_slots:
			var b: Variant = SaveCodec._as_bool((sa as Array)[i]) if i < (sa as Array).size() else true
			if b == null:
				fail("fields", "slot_auto"); b = true
			sao.append(bool(b))
		out.slot_auto = sao
		var ps := str(d.get("passive_skill", "")) if typeof(d.get("passive_skill", "")) == TYPE_STRING else "?"
		if ps == "?":
			fail("fields", "passive_skill"); ps = ""
		if ps != "":
			var sk := GameData.get_skill(ps)
			if sk == null:
				dropped.append("passive:%s" % ps); ps = ""
			elif sk.is_active() or not learned.has(ps):
				fail("rules", "passive %s" % ps)
		out.passive_skill = ps
		# 装备
		var slot_ids := {}
		for s in GameData.equip_slots:
			slot_ids[str(s.slot_id)] = true
		var eq := {}
		var eqs: Variant = typed(d, "equipped", TYPE_DICTIONARY, {})
		for k in eqs:
			if not slot_ids.has(str(k)):
				dropped.append("equip_slot:%s" % k); continue
			var g := gear(eqs[k], "equipped")
			if g.is_empty():
				continue
			if GameData.get_base(g.base_id).slot_id != str(k):
				fail("rules", "equipped %s in slot %s" % [g.base_id, k]); continue
			eq[str(k)] = g
		var bag := []
		var bs: Variant = typed(d, "bag", TYPE_ARRAY, [])
		if (bs as Array).size() > PlayerState.bag_capacity():
			fail("range", "bag size %d > %d" % [(bs as Array).size(), PlayerState.bag_capacity()])
		for g in bs:
			var gg := gear(g, "bag")
			if not gg.is_empty():
				bag.append(gg)
		out.books = count_map(d.get("books", {}), func(id: String) -> bool: return GameData.get_book(id) != null, "books")
		out.items = count_map(d.get("items", {}), func(id: String) -> bool: return GameData.materials.has(id), "items")
		var ad := {}
		var ads: Variant = typed(d, "auto_decompose", TYPE_DICTIONARY, {})
		for k in ads:
			var b: Variant = SaveCodec._as_bool(ads[k])
			if b == null:
				fail("fields", "auto_decompose"); continue
			if GameData.get_quality(str(k)) == null:
				dropped.append("auto_decompose:%s" % k); continue
			ad[str(k)] = bool(b)
		out.auto_decompose = ad
		var poc := []
		for grp in typed(d, "pending_orange_choices", TYPE_ARRAY, []):
			if typeof(grp) != TYPE_ARRAY:
				fail("fields", "pending_orange_choices"); continue
			var gg: Array = []
			for b in grp:
				if GameData.get_base(str(b)) != null:
					gg.append(str(b))
				else:
					dropped.append("orange:%s" % b)
			if not gg.is_empty():
				poc.append(gg)
		out.pending_orange_choices = poc
		out.cleared_levels = _level_list(typed(d, "cleared_levels", TYPE_ARRAY, []), "cleared")
		out.unstable_levels = _level_list(typed(d, "unstable_levels", TYPE_ARRAY, []), "unstable")
		var afc := {}
		var afs: Variant = typed(d, "auto_fail_counts", TYPE_DICTIONARY, {})
		for k in afs:
			var v: Variant = SaveCodec.as_int(afs[k])
			if v == null or int(v) < 0 or int(v) > 1000000:
				fail("range", "auto_fail_counts.%s" % k); continue
			if GameData.get_level(str(k)) == null:
				dropped.append("auto_fail:%s" % k); continue
			afc[str(k)] = int(v)
		out.auto_fail_counts = afc
		out.auto_battle = boolean(d, "auto_battle", true)
		out.telegraph_alt = boolean(d, "telegraph_alt", false)
		out.tutorial = typed(d, "tutorial", TYPE_DICTIONARY, {})
		# 时间：last_settle_at 晚于现在 → 改成现在（导入 / 读档都防“未来时间”制造离线收益）；导入时 max_seen_at 同样夹到现在
		var lsa := num(d, "last_settle_at", 0, 9000000000000, 0)
		out.last_settle_at = mini(lsa, now)
		var msa := num(d, "max_seen_at", 0, 9000000000000, 0)
		out.max_seen_at = mini(msa, now) if is_import else msa
		out.pending_offline = _pending(d.get("pending_offline", {}))
		# uid：保留合法且不重复的，其余重新分配；next_uid 至少为最大 uid + 1
		var nu := num(d, "next_uid", 1, 9000000000000, 1)
		var mx := 0
		for u in _uids:
			mx = maxi(mx, int(u))
		nu = maxi(nu, mx + 1)
		for g in eq.values() + bag:
			if int(g.uid) == 0:
				g.uid = nu; nu += 1
		out.equipped = eq
		out.bag = bag
		out.next_uid = nu

	func _level_list(src: Variant, what: String) -> Array:
		var o := []
		for x in src:
			if GameData.get_level(str(x)) == null:
				dropped.append("%s:%s" % [what, x]); continue
			if not o.has(str(x)):
				o.append(str(x))
		return o

	func _pending(p: Variant) -> Dictionary:
		if typeof(p) != TYPE_DICTIONARY:
			fail("fields", "pending_offline"); return {}
		if (p as Dictionary).is_empty():
			return {}
		if GameData.get_level(str(p.get("level_id", ""))) == null:
			dropped.append("pending_offline:%s" % p.get("level_id", "")); return {}
		var cap := GameData.const_i("OFFLINE_CAP_MINUTES", 480)
		var o := {"level_id": str(p.level_id)}
		o.minutes = num(p, "minutes", 0, cap, 0)
		o.lingshi = num(p, "lingshi", 0, SaveCodec.MAX_CURRENCY, 0)
		o.xiuwei = num(p, "xiuwei", 0, SaveCodec.MAX_CURRENCY, 0)
		o.items = count_map(p.get("items", {}), func(id: String) -> bool: return GameData.materials.has(id), "pending.items")
		o.books = count_map(p.get("books", {}), func(id: String) -> bool: return GameData.get_book(id) != null, "pending.books")
		var gs: Variant = p.get("gear", [])
		if typeof(gs) != TYPE_ARRAY or (gs as Array).size() > SaveCodec.MAX_PENDING_GEAR:
			fail("range", "pending_offline.gear"); return {}
		var go := []
		for g in gs:
			var before := _uids.duplicate()
			var gg := gear(g, "pending")
			_uids = before   # pending 装备领取时才分配 uid
			if not gg.is_empty():
				gg.uid = 0
				go.append(gg)
		o.gear = go
		o.capped = boolean(p, "capped", false)
		o.settled_at = num(p, "settled_at", 0, 9000000000000, 0)
		return o

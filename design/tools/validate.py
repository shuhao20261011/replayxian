# -*- coding: utf-8 -*-
"""校验 design/data 下所有 CSV：可解析、主键唯一、ID 全局唯一、跨表引用无断链、计划硬性规则。
运行：python3 tools/validate.py   失败时退出码=1。"""
import os, sys, csv, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import load, index, DATA

errors, warns = [], []
def err(m): errors.append(m)

# 1) 全部可解析，列数一致
for p in sorted(glob.glob(os.path.join(DATA, "*.csv"))):
    with open(p, encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f))
    if not rows: err("%s 为空" % p); continue
    n = len(rows[0])
    for i, r in enumerate(rows[1:], 2):
        if len(r) != n: err("%s 第%d行列数%d≠表头%d" % (os.path.basename(p), i, len(r), n))

T = {os.path.basename(p)[:-4]: load(os.path.basename(p)) for p in glob.glob(os.path.join(DATA, "*.csv"))}

# 2) 主键唯一 & 全局唯一
PK = {"gongfa": "gongfa_id", "skills": "skill_id", "skill_books": "book_id", "enemies": "enemy_id", "boss_attacks": "attack_id",
      "maps": "map_id", "levels": "level_id", "realms": "realm_id", "materials": "item_id", "equip_slots": "slot_id",
      "qualities": "quality_id", "equip_bases": "base_id", "affixes": "affix_id", "orange_effects": "orange_effect_id",
      "quality_weights": "weight_set_id", "offline_rewards": "offline_id", "tutorial_steps": "step_id", "constants": "key"}
MULTI = {"drop_tables": "drop_table_id", "first_clear_rewards": "reward_id", "book_pools": "book_pool_id"}
glob_ids = {}
for t, k in PK.items():
    seen = set()
    for r in T[t]:
        v = r[k]
        if v in seen: err("%s 主键重复 %s" % (t, v))
        seen.add(v)
        if t != "constants":
            if v in glob_ids and glob_ids[v] != t: err("ID %s 同时出现在 %s 与 %s" % (v, glob_ids[v], t))
            glob_ids[v] = t
for t, k in MULTI.items():
    for v in {r[k] for r in T[t]}:
        if v in glob_ids and glob_ids[v] != t: err("ID %s 同时出现在 %s 与 %s" % (v, glob_ids[v], t))
        glob_ids[v] = t
# 联合主键
for t, keys in {"skill_levels": ("skill_id", "level"), "waves": ("level_id", "wave_index", "enemy_id"),
                "drop_tables": ("drop_table_id", "seq"), "first_clear_rewards": ("reward_id", "seq"),
                "book_pools": ("book_pool_id", "book_id")}.items():
    seen = set()
    for r in T[t]:
        kk = tuple(r[k] for k in keys)
        if kk in seen: err("%s 联合主键重复 %s" % (t, kk))
        seen.add(kk)

I = {t: index(T[t], k) for t, k in PK.items()}
tiers = {"TIER_%d" % r["gear_tier"] for r in T["gear_tiers"]}
def ref(tbl, val, where, allow_empty=False):
    if val in ("", None):
        if not allow_empty: err("%s: 引用为空" % where)
        return
    if val not in I[tbl]: err("%s: 引用 %s 不存在于 %s" % (where, val, tbl))

# 3) 引用
for s in T["skills"]:
    ref("gongfa", s["gongfa_id"], "skills.%s.gongfa_id" % s["skill_id"])
    ref("skill_books", s["book_id"], "skills.%s.book_id" % s["skill_id"])
for b in T["skill_books"]:
    ref("skills", b["skill_id"], "skill_books.%s.skill_id" % b["book_id"])
    ref("gongfa", b["gongfa_id"], "skill_books.%s.gongfa_id" % b["book_id"])
    ref("maps", b["region_map_id"], "skill_books.%s.region_map_id" % b["book_id"])
    sk_ = I["skills"].get(b["skill_id"], {})
    if sk_.get("book_id") != b["book_id"]: err("书-技能不是一一对应：%s" % b["book_id"])
    if sk_.get("gongfa_id") != b["gongfa_id"]: err("书的功法与技能不一致：%s" % b["book_id"])
if len({b["skill_id"] for b in T["skill_books"]}) != len(T["skills"]): err("技能书未一一覆盖全部技能")
for g in T["gongfa"]:
    sk = [s for s in T["skills"] if s["gongfa_id"] == g["gongfa_id"]]
    na = sum(1 for s in sk if s["slot_type"] == "active"); npv = sum(1 for s in sk if s["slot_type"] == "passive")
    if (na, npv) != (4, 1): err("功法%s 主动/被动数量=%d/%d，应为4/1" % (g["gongfa_id"], na, npv))
    ref("maps", g["book_map_id"], "gongfa.%s.book_map_id" % g["gongfa_id"])
if len(T["skills"]) != 15: err("技能总数应为15")
lv = {}
for r in T["skill_levels"]:
    ref("skills", r["skill_id"], "skill_levels")
    lv.setdefault(r["skill_id"], set()).add(r["level"])
for s in T["skills"]:
    if lv.get(s["skill_id"]) != set(range(1, 11)): err("skill_levels 缺少 %s 的1-10级" % s["skill_id"])
for r in T["skill_levels"]:
    if r["level"] == 10 and r["upgrade_cost_lingshi"] != 0: err("10级升级消耗应为0：%s" % r["skill_id"])
    if r["level"] < 10 and r["upgrade_cost_lingshi"] <= 0: err("升级消耗应>0：%s lv%d" % (r["skill_id"], r["level"]))

for e in T["enemies"]:
    ref("maps", e["map_id"], "enemies.%s.map_id" % e["enemy_id"])
    if e["kind"] == "boss":
        p = dict(x.split("=") for x in str(e["behavior_param"]).split(";") if "=" in x)
        for a in p.get("attack_ids", "").split("|"):
            ref("boss_attacks", a, "enemies.%s.attack_ids" % e["enemy_id"])
nn = sum(1 for e in T["enemies"] if e["kind"] == "normal"); nb = sum(1 for e in T["enemies"] if e["kind"] == "boss")
if (nn, nb) != (6, 3): err("普通怪/首领数=%d/%d，应为6/3" % (nn, nb))
for a in T["boss_attacks"]:
    ref("enemies", a["boss_id"], "boss_attacks.%s.boss_id" % a["attack_id"])
    if I["enemies"].get(a["boss_id"], {}).get("kind") != "boss": err("boss_attacks.%s 指向非首领" % a["attack_id"])
    if a["is_danger"] == "true" and float(a["warn_s"]) != 0.8: err("危险攻击预警须0.8秒：%s" % a["attack_id"])
for b in {e["enemy_id"] for e in T["enemies"] if e["kind"] == "boss"}:
    if not any(a["boss_id"] == b and a["is_danger"] == "true" for a in T["boss_attacks"]): err("首领%s无危险攻击" % b)

for m in T["maps"]:
    w = "maps.%s" % m["map_id"]
    last_map = m["order"] == max(x["order"] for x in T["maps"])
    ref("realms", m["realm_required"], w); ref("enemies", m["boss_id"], w)
    ref("materials", m["breakthrough_mat_id"], w, allow_empty=last_map)   # 最后一张图无更高境界，不产突破材料
    ref("gongfa", m["book_gongfa_id"], w)
    for e in m["normal_enemy_ids"].split("|"): ref("enemies", e, w)
for r in T["realms"]:
    ref("maps", r["unlock_map_id"], "realms.%s" % r["realm_id"])
    ref("realms", r["prev_realm_id"], "realms.%s.prev" % r["realm_id"], allow_empty=r["order"] == 1)
    ref("materials", r["material_id"], "realms.%s.material" % r["realm_id"], allow_empty=r["order"] == 1)

if len(T["levels"]) != 15: err("关卡数应为15")
for L in T["levels"]:
    w = "levels.%s" % L["level_id"]
    ref("maps", L["map_id"], w); ref("enemies", L["boss_id"], w)
    if I["maps"].get(L["map_id"], {}).get("boss_id") != L["boss_id"]: err("%s 首领与地图不符" % w)
    if L["boss_time_limit_s"] != 60: err("%s 首领限时须60秒" % w)
    if L["normal_drop_table_id"] not in {r["drop_table_id"] for r in T["drop_tables"]}: err("%s normal_drop_table断链" % w)
    if L["boss_drop_table_id"] not in {r["drop_table_id"] for r in T["drop_tables"]}: err("%s boss_drop_table断链" % w)
    if L["first_clear_reward_id"] not in {r["reward_id"] for r in T["first_clear_rewards"]}: err("%s 首通奖励断链" % w)
    ref("offline_rewards", L["offline_reward_id"], w)
    ref("levels", L["unlock_level_id"], w + ".unlock_level_id", allow_empty=L["global_index"] == 1)
    ref("realms", L["unlock_realm_id"], w + ".unlock_realm_id", allow_empty=L["index"] != 1)
    ws = {r["wave_index"] for r in T["waves"] if r["level_id"] == L["level_id"]}
    if ws != {1, 2, 3, 4}: err("%s 波次应为1-4，实际%s" % (w, sorted(ws)))
for r in T["waves"]:
    ref("levels", r["level_id"], "waves"); ref("enemies", r["enemy_id"], "waves.%s" % r["level_id"])
    e = I["enemies"].get(r["enemy_id"])
    if e is None or r["level_id"] not in I["levels"]: continue
    if e["kind"] != "normal": err("waves.%s 波次中不应出现首领" % r["level_id"])
    if e["map_id"] != I["levels"][r["level_id"]]["map_id"]: warns.append("waves.%s 出现跨地图怪 %s" % (r["level_id"], r["enemy_id"]))
    if int(r["count"]) <= 0: err("waves 数量须>0")

qids = [q["quality_id"] for q in T["qualities"]]
if [q["affix_count"] for q in sorted(T["qualities"], key=lambda q: q["order"])] != [0, 1, 2, 3, 4]: err("品质词条数应为0/1/2/3/4")
for q in T["quality_weights"]:
    for qq in qids:
        if qq not in q: err("quality_weights 缺列 %s" % qq)
    if abs(sum(float(q[qq]) for qq in qids)) <= 0: err("权重组%s 总和为0" % q["weight_set_id"])
for b in T["equip_bases"]:
    ref("equip_slots", b["slot_id"], "equip_bases.%s" % b["base_id"])
    if "TIER_%d" % b["gear_tier"] not in tiers: err("equip_bases.%s gear_tier 不存在" % b["base_id"])
    if b["is_core"] == "true":
        ref("orange_effects", b["orange_effect_id"], "equip_bases.%s" % b["base_id"]); ref("gongfa", b["gongfa_id"], "equip_bases.%s" % b["base_id"])
if len({b["slot_id"] for b in T["equip_bases"]}) != 6 or len(T["equip_slots"]) != 6: err("装备槽应为6")
cores = [b for b in T["equip_bases"] if b["is_core"] == "true"]
if sorted(b["gongfa_id"] for b in cores) != sorted(g["gongfa_id"] for g in T["gongfa"]): err("每个流派应有且仅有1件核心橙装")
for o in T["orange_effects"]:
    ref("equip_bases", o["base_id"], "orange_effects.%s" % o["orange_effect_id"]); ref("gongfa", o["gongfa_id"], "orange_effects")
for a in T["affixes"]:
    for s in a["allowed_slots"].split("|"): ref("equip_slots", s, "affixes.%s.allowed_slots" % a["affix_id"])
    ref("qualities", a["min_quality"], "affixes.%s.min_quality" % a["affix_id"])
    for q in ("green", "blue", "purple", "orange"):
        if float(a[q + "_min"]) > float(a[q + "_max"]): err("affixes.%s %s min>max" % (a["affix_id"], q))
    if float(a["orange_max"]) <= 0: err("affixes.%s 橙色区间为0" % a["affix_id"])

def ref_any(entry_type, rid, w):
    if entry_type in ("book",): ref("skill_books", rid, w)
    elif entry_type in ("equipment",):
        if rid not in tiers and rid not in I["equip_bases"]: err("%s 装备引用 %s 无效" % (w, rid))
    elif entry_type in ("material", "lingshi", "xiuwei"): ref("materials", rid, w)
    elif entry_type == "orange_choice":
        ref("equip_bases", rid, w)
        if I["equip_bases"].get(rid, {}).get("is_core") != "true": err("%s 三选一应为核心橙装" % w)
    elif entry_type == "book_pool":
        if rid not in {r["book_pool_id"] for r in T["book_pools"]}: err("%s 书池 %s 不存在" % (w, rid))
    else: err("%s 未知类型 %s" % (w, entry_type))
for r in T["drop_tables"]:
    ref_any(r["entry_type"], r["ref_id"], "drop_tables.%s#%s" % (r["drop_table_id"], r["seq"]))
    if r["weight_set_id"] != "": ref("quality_weights", r["weight_set_id"], "drop_tables.%s" % r["drop_table_id"])
    if not (0 < float(r["chance"]) <= 1): err("drop_tables.%s 概率越界" % r["drop_table_id"])
for r in T["first_clear_rewards"]:
    w = "first_clear_rewards.%s#%s" % (r["reward_id"], r["seq"])
    ref("levels", r["level_id"], w); ref_any(r["reward_type"], r["ref_id"], w)
    if r["weight_set_id"] != "": ref("quality_weights", r["weight_set_id"], w)
    if r["reward_type"] == "equipment":
        ws = I["quality_weights"].get(r["weight_set_id"], {"Q_WHITE": 1, "Q_GREEN": 0})
        if float(ws["Q_WHITE"]) + float(ws["Q_GREEN"]) > 0: err("%s 首通装备须蓝装以上" % w)
for L in T["levels"]:
    rs = [r for r in T["first_clear_rewards"] if r["level_id"] == L["level_id"]]
    if not any(r["reward_type"] == "equipment" for r in rs): err("%s 首通无保底装备" % L["level_id"])
last = max(T["levels"], key=lambda L: L["global_index"])["level_id"]
if len([r for r in T["first_clear_rewards"] if r["level_id"] == last and r["reward_type"] == "orange_choice"]) != 3: err("终关首通须三选一橙装")
for r in T["book_pools"]:
    ref("skill_books", r["book_id"], "book_pools.%s" % r["book_pool_id"])
for o in T["offline_rewards"]:
    ref("levels", o["level_id"], "offline_rewards.%s" % o["offline_id"]); ref("quality_weights", o["weight_set_id"], "offline_rewards")
    if o["book_pool_id"] not in {r["book_pool_id"] for r in T["book_pools"]}: err("offline_rewards 书池断链")
    if int(o["cap_minutes"]) != 480: err("离线上限须480分钟")
for t in T["tutorial_steps"]:
    w = "tutorial_steps.%s" % t["step_id"]
    for rid in str(t["reward_ref_ids"]).split("|"):
        if rid == "": continue
        if t["reward_type"] == "book": ref("skill_books", rid, w)
        elif t["reward_type"] in ("lingshi", "material"): ref("materials", rid, w)
        elif t["reward_type"] == "first_clear":
            if rid not in {r["reward_id"] for r in T["first_clear_rewards"]}: err("%s 首通引用断链" % w)
# 引导步骤结构检查（v3）
TUT_REWARD_TYPES = {"none", "book", "lingshi", "material", "first_clear"}
orders = sorted(int(t["order"]) for t in T["tutorial_steps"])
if orders != list(range(1, len(orders) + 1)): err("tutorial_steps.order 须从1连续且不重复：%s" % orders)
main_names = [t["name"] for t in sorted(T["tutorial_steps"], key=lambda t: int(t["order"])) if t["category"] == "main"]
if main_names != ["领书", "学习", "装配", "释放", "换装", "首领"]: err("主线引导须按序覆盖 领书→学习→装配→释放→换装→首领（计划已定），实际 %s" % main_names)
any_id = {}
for tbl in ("tutorial_steps", "levels", "boss_attacks", "enemies", "equip_bases", "skills", "skill_books"):
    for k in I[tbl]: any_id[k] = tbl
for t in T["tutorial_steps"]:
    w = "tutorial_steps.%s" % t["step_id"]
    if t["category"] not in ("main", "contextual"): err("%s category 须为 main/contextual" % w)
    if t["reward_type"] not in TUT_REWARD_TYPES: err("%s reward_type 非法：%s" % (w, t["reward_type"]))
    if t["reward_type"] == "none" and (str(t["reward_ref_ids"]) != "" or int(t["reward_count"]) != 0): err("%s 无奖励时引用须为空、数量须为0" % w)
    if t["reward_type"] != "none" and str(t["reward_ref_ids"]) == "": err("%s 有奖励类型但无引用" % w)
    if not (0 <= float(t["time_scale"]) <= 1): err("%s time_scale 须在0~1" % w)
    if float(t["time_scale_duration_s"]) < 0: err("%s time_scale_duration_s 须≥0" % w)
    if int(t["max_show_count"]) < 1: err("%s max_show_count 须≥1" % w)
    for rid in str(t["trigger_ref_ids"]).split("|"):
        if rid and rid not in any_id: err("%s trigger_ref_ids 引用 %s 不存在" % (w, rid))
        if rid.startswith("BA_") and I["boss_attacks"].get(rid, {}).get("is_danger") != "true": err("%s 触发的首领招式须为危险攻击" % w)
sky = [a["attack_id"] for a in T["boss_attacks"] if a["damage_type"] == "true_maxhp"]
for a in sky:   # 每个 true_maxhp 危险攻击都应有首次闪避提示
    if not any(a in str(t["trigger_ref_ids"]).split("|") for t in T["tutorial_steps"]): err("危险攻击 %s 缺少首次闪避引导步骤" % a)
for k in T["start_kit"]:
    ref("equip_bases", k["ref_id"], "start_kit"); ref("qualities", k["quality_id"], "start_kit")

# 4) 技能书获取覆盖
src = {}
for t in T["tutorial_steps"]:
    if t["reward_type"] == "book":
        for b in t["reward_ref_ids"].split("|"): src.setdefault(b, []).append("新手引导")
for r in T["first_clear_rewards"]:
    if r["reward_type"] == "book": src.setdefault(r["ref_id"], []).append("首通" + r["level_id"])
used_pools = {r["ref_id"] for r in T["drop_tables"] if r["entry_type"] == "book_pool"} | {o["book_pool_id"] for o in T["offline_rewards"]}
for r in T["book_pools"]:
    if r["book_pool_id"] in used_pools and float(r["weight"]) > 0: src.setdefault(r["book_id"], []).append("书池" + r["book_pool_id"])
for b in T["skill_books"]:
    if b["book_id"] not in src: err("技能书 %s 没有任何获取途径" % b["book_id"])
    elif not any(x.startswith("书池") for x in src[b["book_id"]]): err("技能书 %s 没有首领概率掉落" % b["book_id"])
basic = [s["book_id"] for s in T["skills"] if s["is_basic"] == "true"]
tut_books = [b for t in T["tutorial_steps"] if t["reward_type"] == "book" for b in str(t["reward_ref_ids"]).split("|")]
if sorted(basic) != sorted(tut_books): err("新手赠书应为且仅为3本基础书")

print("表数量:", len(T), " 行数:", sum(len(v) for v in T.values()))
print("技能书获取途径:")
for b in T["skill_books"]:
    print("  %-20s %s" % (b["book_id"], "、".join(src.get(b["book_id"], []))))
for w in warns: print("WARN", w)
if errors:
    print("FAILED: %d 个错误" % len(errors))
    for e in errors: print("  ERR", e)
    sys.exit(1)
print("OK: 全部校验通过，0 错误")

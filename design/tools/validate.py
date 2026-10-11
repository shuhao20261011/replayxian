# -*- coding: utf-8 -*-
"""校验 design/data 下所有 CSV：可解析、主键唯一、ID 全局唯一、跨表引用无断链、计划硬性规则。
运行：python3 tools/validate.py   失败时退出码=1。"""
import os, sys, csv, glob, re
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
      "quality_weights": "weight_set_id", "offline_rewards": "offline_id", "tutorial_steps": "step_id", "constants": "key", "ui_texts": "key"}
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

# v4：反伤/反震防御开关与节奏常量（前端同名常量、balance.py 依赖）
CK = {r["key"]: r["value"] for r in T["constants"]}
for k in ("REFLECT_IGNORE_DEF", "COUNTER_IGNORE_DEF"):
    if k not in CK: err("constants 缺少 %s" % k)
    elif CK[k] not in (0, 1): err("constants.%s 只能是 0 或 1，当前 %s" % (k, CK[k]))
for k in ("RUN_START_WALK_TIME", "WAVE_ENTER_WALK_TIME", "SPAWN_DISTANCE_PX", "BOSS_SPAWN_DISTANCE_PX", "AUTO_ENGAGE_RANGE_PX",
          "PLAYER_MOVE_SPEED", "BOSS_INTRO_TIME", "RESULT_SHOW_TIME", "AUTO_SHIELD_RESERVE_CD"):
    if k not in CK: err("constants 缺少节奏常量 %s" % k)
    elif not isinstance(CK[k], (int, float)) or CK[k] < 0: err("constants.%s 应为非负数，当前 %s" % (k, CK[k]))
if all(isinstance(CK.get(k), (int, float)) for k in ("SPAWN_DISTANCE_PX", "BOSS_SPAWN_DISTANCE_PX", "AUTO_ENGAGE_RANGE_PX", "PLAYER_NORMAL_ATK_RANGE")):
    if CK["AUTO_ENGAGE_RANGE_PX"] < CK["PLAYER_NORMAL_ATK_RANGE"]: err("AUTO_ENGAGE_RANGE_PX 不应小于普攻射程")
    if CK["SPAWN_DISTANCE_PX"] <= CK["PLAYER_NORMAL_ATK_RANGE"] or CK["BOSS_SPAWN_DISTANCE_PX"] <= CK["PLAYER_NORMAL_ATK_RANGE"]:
        err("刷怪距离应大于普攻射程，否则敌人刷在脸上")

# ================================================================ v5 文案规范（README「文案规范」）
from common import render_tpl, PH_RE
# 渲染后最大字数（按字符计）。依据：1280×720 基准、正文 14–15px，功法详情区 520px≈34字/行、装备提示区 440px≈31字/行
TEXT_LIMITS = {
    ("gongfa", "name"): 3, ("gongfa", "role"): 6, ("gongfa", "build_dir"): 16, ("gongfa", "desc"): 24,
    ("skills", "name"): 4, ("skills", "desc"): 56, ("skill_books", "name"): 6, ("skill_books", "source_desc"): 28,
    ("enemies", "name"): 4, ("enemies", "desc"): 22, ("boss_attacks", "name"): 4, ("boss_attacks", "desc"): 32,
    ("maps", "name"): 3, ("maps", "desc"): 22, ("levels", "name"): 4, ("levels", "desc"): 16,
    ("realms", "name"): 2, ("realms", "desc"): 14, ("materials", "name"): 4, ("materials", "desc"): 20,
    ("equip_slots", "name"): 2, ("equip_bases", "name"): 4, ("equip_bases", "desc"): 16, ("affixes", "name"): 5,
    ("orange_effects", "name"): 4, ("orange_effects", "desc"): 56, ("qualities", "name"): 1,
    ("tutorial_steps", "name"): 4, ("tutorial_steps", "hint_text"): 12, ("tutorial_steps", "sub_text"): 24,
    ("tutorial_steps", "button_text"): 4, ("tutorial_steps", "success_text"): 16,
}
BOSS_NAME_LIMIT = 7          # 首领名形如“青竹山主·竹魅”
DESC_FIELDS = {"gongfa", "skills", "enemies", "boss_attacks", "maps", "levels", "realms", "materials", "equip_bases", "orange_effects"}
NO_DIGIT = {("gongfa", "desc"), ("gongfa", "role"), ("gongfa", "build_dir"), ("enemies", "desc"), ("boss_attacks", "desc_tpl"),
            ("maps", "desc"), ("levels", "desc"), ("realms", "desc"), ("materials", "desc"), ("equip_bases", "desc"),
            ("skills", "desc_tpl"), ("orange_effects", "desc_tpl")}
FORBIDDEN = ["Boss", "BOSS", "boss", "CD", "DPS", "HP", "ATK", "DEF", "像素", "效果值", "效果2", "系数", "货币", "金币", "经验",
             "法力", "怪物", "几率", "攻击力", "近战", "接触", "伤害值", "Buff", "buff", "BUFF", "红色区域",
             "朱红", "朱痕", "红圈", "白圈", "红框", "白框"]   # v5.1：预警色按地图不同，文案不得用颜色指代预警
VERBS = ["领取", "打开", "学习", "装配", "按", "换上", "点击", "击败", "闪避", "前往", "选择", "拖动", "升级", "装备", "分解"]
ASCII_PUNCT = re.compile(r"[,;:()!?\"'\[\]]")
PANEL_BG = "#232C25"         # 美术 v2 实测 UI 墨底
def _lum(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
def contrast(a, b): return (max(_lum(a), _lum(b)) + 0.05) / (min(_lum(a), _lum(b)) + 0.05)
HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")

def check_text(where, txt, limit=None, no_digit=False):
    txt = str(txt)
    if limit is not None and len(txt) > limit: err("%s 超长：%d>%d「%s」" % (where, len(txt), limit, txt))
    bare = PH_RE.sub("", txt)
    for w in FORBIDDEN:
        if w in bare: err("%s 含不规范用语「%s」：%s" % (where, w, txt))
    if ASCII_PUNCT.search(bare): err("%s 含半角标点，应使用全角：%s" % (where, txt))
    for m in re.finditer(" ", bare):
        a, b = bare[m.start() - 1:m.start()], bare[m.end():m.end() + 1]
        if not (re.match(r"[A-Za-z0-9]", a) or re.match(r"[A-Za-z0-9]", b)): err("%s 含多余半角空格（只允许包住按键名，如“按 Q 恢复”）：%s" % (where, txt))
    if no_digit and re.search(r"[0-9]", bare): err("%s 数值须用占位符（{字段}/{字段:pct}），不能写死数字：%s" % (where, txt))
    if "{" in bare or "}" in bare: err("%s 占位符格式错误：%s" % (where, txt))

SL1 = {(r["skill_id"], r["level"]): r for r in T["skill_levels"]}
for t in sorted({k[0] for k in TEXT_LIMITS} | {"ui_texts"}):
    if t == "ui_texts": continue
    for r in T[t]:
        rid = next(iter(r.values()))
        for (tt, col), lim in TEXT_LIMITS.items():
            if tt != t or col not in r: continue
            if t == "enemies" and col == "name" and r["kind"] == "boss": lim = BOSS_NAME_LIMIT
            val = r[col]
            if t == "tutorial_steps" and col in ("hint_text", "sub_text", "button_text", "success_text"):
                try: val = render_tpl(str(val), r)
                except KeyError as e: err("tutorial_steps %s.%s 占位符 %s 不是本行字段" % (rid, col, e)); continue
            check_text("%s %s.%s" % (t, rid, col), val, lim, (t, col) in NO_DIGIT)
        if "desc_tpl" in r:
            check_text("%s %s.desc_tpl" % (t, rid), str(r["desc_tpl"]), None, (t, "desc_tpl") in NO_DIGIT)
            ctx_rows = [dict(r)]
            if t == "skills":
                ctx_rows = [dict(r, **SL1[(r["skill_id"], 1)]), dict(r, **SL1[(r["skill_id"], 10)])]
            for i, ctx in enumerate(ctx_rows):
                try: out = render_tpl(str(r["desc_tpl"]), ctx)
                except KeyError as e: err("%s %s.desc_tpl 占位符 %s 不是表字段" % (t, rid, e)); break
                if i == 0 and out != r["desc"]: err("%s %s.desc 与 desc_tpl 的1级渲染不一致，请重新生成" % (t, rid))
                if i == 1: check_text("%s %s.desc(Lv10)" % (t, rid), out, TEXT_LIMITS[(t, "desc")])
        if t in DESC_FIELDS and "desc" in r and not str(r["desc"]).endswith("。"): err("%s %s.desc 应以句号结尾" % (t, rid))
        if "icon" in r and not re.match(r"^ui_icon_[a-z0-9_]+$", str(r["icon"])): err("%s %s.icon 命名不规范：%s" % (t, rid, r["icon"]))
# 术语一致：功法培养方向必须是词条原名
aff_names = {a["name"] for a in T["affixes"]}
for g in T["gongfa"]:
    for x in str(g["build_dir"]).split("、"):
        if x not in aff_names: err("gongfa %s.build_dir「%s」不是词条名（术语须与 affixes.name 一致）" % (g["gongfa_id"], x))
# 名称唯一（玩家看到的同类名称不能重名）
for t in ("skills", "enemies", "levels", "maps", "equip_bases", "affixes", "orange_effects", "materials", "boss_attacks"):
    ns = [r["name"] for r in T[t]]
    for n in {x for x in ns if ns.count(x) > 1}: err("%s 玩家可见名称重复：%s" % (t, n))
# 引导文案
for r in T["tutorial_steps"]:
    sid = r["step_id"]
    if not any(str(r["hint_text"]).startswith(v) for v in VERBS): err("tutorial_steps %s.hint_text 应以动词开头：%s" % (sid, r["hint_text"]))
    m = re.search("“([^”]*)”", str(r["ui_target"]))
    if not m or m.group(1) != r["hint_text"]: err("tutorial_steps %s.ui_target 中第一个“……”须与 hint_text 一致（前端兼容解析）" % sid)
    if r["category"] == "contextual":
        m2 = re.search("小字“([^”]*)”", str(r["ui_target"]))
        if m2 and m2.group(1) != r["sub_text"]: err("tutorial_steps %s.ui_target 小字“……”须与 sub_text 一致" % sid)
# ui_texts：占位符声明、来源、渲染长度
for r in T["ui_texts"]:
    k = r["key"]; decl = {}
    for d in [x for x in str(r["placeholders"]).split(";") if x]:
        n, _, psrc = d.partition(":")
        decl[n] = psrc
        if re.match(r"^int\d$", psrc): continue
        tb, _, fd = psrc.partition(".")
        if tb not in T or not T[tb] or fd not in T[tb][0]: err("ui_texts %s 占位符 %s 来源 %s 不存在" % (k, n, psrc))
    used = [m.group(1) for m in PH_RE.finditer(str(r["text"]))]
    for n in used:
        if n not in decl: err("ui_texts %s 使用了未声明的占位符 {%s}" % (k, n))
    for n in decl:
        if n not in used: err("ui_texts %s 声明了未使用的占位符 %s" % (k, n))
    def longest(src):
        if re.match(r"^int\d$", src): return "9" * int(src[3])
        tb, _, fd = src.partition(".")
        return max((str(x[fd]) for x in T.get(tb, []) if fd in x), key=len, default="")
    try: out = PH_RE.sub(lambda m: longest(decl[m.group(1)]), str(r["text"]))
    except KeyError: continue
    check_text("ui_texts %s" % k, out, r["max_chars"])
# 颜色：文字色在 UI 墨底上对比度≥4.5；表现色为合法 HEX
for t, col, rid in (("qualities", "color", "quality_id"), ("gongfa", "color", "gongfa_id")):
    for r in T[t]:
        if not HEX.match(str(r[col])): err("%s %s.%s 不是 #RRGGBB" % (t, r[rid], col)); continue
        c = contrast(str(r[col]), PANEL_BG)
        if c < 4.5: err("%s %s.%s=%s 在面板底色 %s 上对比度 %.2f<4.5，文字看不清" % (t, r[rid], col, r[col], PANEL_BG, c))
for t, col, rid in (("qualities", "beam_color", "quality_id"), ("gongfa", "fx_color", "gongfa_id")):
    for r in T[t]:
        if not HEX.match(str(r.get(col, ""))): err("%s %s.%s 不是 #RRGGBB" % (t, r[rid], col))

# v5 BUG-005：危险招式间隔 ≥ 闪避冷却 + 余量（逐帧复刻 boss.gd 排招，模拟每关首领出现后60秒）
from common import danger_gap_violations
_min_gap = CK.get("DODGE_COOLDOWN", 3.0) + CK.get("DANGER_MIN_GAP_MARGIN_S", 0.5)
for lv, a1, a2, gap, t1, t2, order in danger_gap_violations(T, _min_gap):
    err("%s 首领危险招式间隔不足：%s（末段判定 %.2f 秒）→ %s（判定 %.2f 秒）只隔 %.2f 秒 < 闪避冷却+余量 %.1f 秒（优先顺序：%s）"
        % (lv, a1, t1, a2, t2, gap, _min_gap, order))
# v5.1 预警色：以美术 v2 规范为唯一来源，按地图配置
ART_TELEGRAPH = {"#B8382C", "#F4F1EA"}          # style_guide：朱砂 / 预警白
_tdef, _talt = str(CK.get("TELEGRAPH_DEFAULT_COLOR", "")).upper(), str(CK.get("TELEGRAPH_ALT_COLOR", "")).upper()
if _tdef != "#B8382C": err("constants.TELEGRAPH_DEFAULT_COLOR 应为美术规范朱砂 #B8382C，现为 %s" % _tdef)
if _talt != "#F4F1EA": err("constants.TELEGRAPH_ALT_COLOR 应为美术规范预警白 #F4F1EA，现为 %s" % _talt)
for k in ("TELEGRAPH_OUTLINE_PX", "TELEGRAPH_OUTLINE_COLOR", "TELEGRAPH_OUTLINE_ALPHA", "TELEGRAPH_FILL_ALPHA"):
    if k not in CK: err("constants 缺少 %s" % k)
if not HEX.match(str(CK.get("TELEGRAPH_OUTLINE_COLOR", ""))): err("constants.TELEGRAPH_OUTLINE_COLOR 不是 #RRGGBB")
if not (isinstance(CK.get("TELEGRAPH_OUTLINE_PX"), (int, float)) and CK.get("TELEGRAPH_OUTLINE_PX") > 0): err("TELEGRAPH_OUTLINE_PX 须 >0")
for k in ("TELEGRAPH_OUTLINE_ALPHA", "TELEGRAPH_FILL_ALPHA"):
    if not (isinstance(CK.get(k), (int, float)) and 0 <= CK.get(k) <= 1): err("%s 须在 0~1" % k)
_mapcol = {}
for m in T["maps"]:
    c = str(m.get("telegraph_color", "")).upper()
    if c not in (_tdef, _talt): err("maps %s.telegraph_color=%s 只能取 TELEGRAPH_DEFAULT_COLOR 或 TELEGRAPH_ALT_COLOR" % (m["map_id"], c))
    _mapcol[m["map_id"]] = c
_EN = {e["enemy_id"]: e for e in T["enemies"]}
for a in T["boss_attacks"]:
    c = str(a["telegraph_color"]).upper()
    if str(a["is_danger"]) != "true":
        if c: err("boss_attacks %s 非危险招式不应有 telegraph_color" % a["attack_id"])
        continue
    mc = _mapcol.get(_EN[a["boss_id"]]["map_id"])
    if c and c != mc: err("boss_attacks %s.telegraph_color=%s 与所属地图预警色 %s 不一致（留空=取地图值）" % (a["attack_id"], c, mc))
    if c and c not in ART_TELEGRAPH: err("boss_attacks %s.telegraph_color 不是美术规范色" % a["attack_id"])

# v5.1 图标清单：design/icon_list.csv 必须与各表 icon 列 + 按键图标完全一致
_ip = os.path.join(os.path.dirname(DATA), "icon_list.csv")
KEY_ICONS = {"ui_icon_key_space", "ui_icon_key_q", "ui_icon_key_1", "ui_icon_key_2", "ui_icon_key_3", "ui_icon_key_4"}
ICON_TABLES = {"gongfa": "gongfa_id", "skills": "skill_id", "skill_books": "book_id", "materials": "item_id", "equip_bases": "base_id"}
if not os.path.exists(_ip): err("缺少 icon_list.csv（由 gen_tables.py 生成）")
else:
    with open(_ip, encoding="utf-8", newline="") as f: IL = list(csv.DictReader(f))
    need = {}
    for t, k in ICON_TABLES.items():
        for r in T[t]:
            if not r.get("icon"): err("%s %s 缺少 icon" % (t, r[k])); continue
            need.setdefault(r["icon"], set()).add("%s:%s" % (t, r[k]))
    keys = [r["icon_key"] for r in IL]
    if len(keys) != len(set(keys)): err("icon_list.csv icon_key 有重复")
    for r in IL:
        for c in ("icon_key", "category", "refs", "name", "prompt", "size"):
            if not str(r.get(c, "")).strip(): err("icon_list %s.%s 为空" % (r.get("icon_key"), c))
        if not re.match(r"^ui_icon_[a-z0-9_]+$", r["icon_key"]): err("icon_list %s 命名不规范" % r["icon_key"])
        refs = {x for x in r["refs"].split("|") if not x.startswith(("key:", "tutorial_steps:"))}
        if r["icon_key"] in KEY_ICONS:
            if r["category"] != "按键": err("icon_list %s 类别应为 按键" % r["icon_key"])
            for x in r["refs"].split("|"):
                if x.startswith("tutorial_steps:") and x.split(":")[1] not in {s_["step_id"] for s_ in T["tutorial_steps"]}:
                    err("icon_list %s 引用了不存在的引导步骤 %s" % (r["icon_key"], x))
        elif r["icon_key"] not in need: err("icon_list %s 在各表 icon 列中不存在（多余）" % r["icon_key"])
        elif refs != need[r["icon_key"]]: err("icon_list %s 的 refs 与表不一致：%s ≠ %s" % (r["icon_key"], sorted(refs), sorted(need[r["icon_key"]])))
    for k in set(need) | KEY_ICONS:
        if k not in keys: err("icon_list.csv 缺少 %s" % k)
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

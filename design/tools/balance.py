# -*- coding: utf-8 -*-
"""主线时长与三流派差异估算。读取 data/*.csv，输出 balance_report.csv 与控制台摘要。
运行：python3 tools/balance.py [--md]   （--md 额外输出可粘贴到 balance.md 的表格）
模型说明见 balance.md。所有“假设”集中在下方 ASSUME 中，可直接改。
v4：节奏参数（开局/波间前进、刷怪距离、接敌距离、首领登场、结算展示、护盾预留冷却）和
反伤/反震是否无视防御，改为从 constants.csv 读取（与前端同名常量一致），不再写在 ASSUME 里。"""
import os, sys, math, csv
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import load, index, DATA

ASSUME = dict(
    UPTIME_WAVE=0.85,        # 清怪时有效输出占比（走位/前摇/目标切换）
    UPTIME_BOSS=0.80,        # 首领战有效输出占比（躲预警、首领位移）
    AOE_EFF=0.85,            # 群伤溢出/残血浪费系数（只作用于多目标部分）
    MAX_CLUSTER=6,           # 同时被范围技能覆盖的敌人上限
    SPREAD_DENSITY=0.5,      # spread 阵型（远程/冲锋/游击）计入密度的权重
    LEVEL_OVERHEAD=60.0,     # 每关结算、看掉落、换装、升级技能、读新书的操作秒数（首通）
    TUTORIAL_OVERHEAD=150.0, # 新手引导阅读/点击额外秒数（1-1）
    BREAK_OVERHEAD=60.0,     # 突破+切换地图操作秒数
    AFFIX_OFF=0.025,         # 每条词条折算的攻击类增益（约半数词条为输出词条，均值约5%）
    AFFIX_DEF=0.025,         # 每条词条折算的生命类增益
    LINGSHI_SPEND=0.85,      # 灵石用于技能升级的比例（其余用于重铸等）
    FARM_SPEEDUP=0.85,       # 已通关关卡挂机一轮：击杀耗时×该值（行进/接敌/登场/结算等固定节奏不缩短）
    DANGER_DODGE_MANUAL=0.8, # 手动玩家闪避危险攻击的成功率；自动模式为0（计划：自动不闪避）
)
# 从 constants.csv 读取的节奏常量（v4）：RUN_START_WALK_TIME / WAVE_ENTER_WALK_TIME / SPAWN_DISTANCE_PX /
# BOSS_SPAWN_DISTANCE_PX / AUTO_ENGAGE_RANGE_PX / PLAYER_MOVE_SPEED / BOSS_INTRO_TIME / RESULT_SHOW_TIME / AUTO_SHIELD_RESERVE_CD
PACING_KEYS = ["RUN_START_WALK_TIME", "WAVE_ENTER_WALK_TIME", "SPAWN_DISTANCE_PX", "BOSS_SPAWN_DISTANCE_PX", "AUTO_ENGAGE_RANGE_PX",
               "PLAYER_MOVE_SPEED", "BOSS_INTRO_TIME", "RESULT_SHOW_TIME", "AUTO_SHIELD_RESERVE_CD", "REFLECT_IGNORE_DEF", "COUNTER_IGNORE_DEF"]
# 装备进度假设：每关开打时的(等效装备档位, 等效品质序号 1白..5橙)
GEAR = {1: [(1, 1.3), (1, 2.0), (1, 2.4), (1, 2.7), (1, 3.0)],
        2: [(1.5, 2.8), (1.8, 2.8), (2, 2.9), (2, 3.0), (2, 3.2)],
        3: [(2.5, 3.0), (2.8, 3.0), (3, 3.1), (3, 3.2), (3, 3.4)]}

T = {n[:-4]: load(n) for n in os.listdir(DATA) if n.endswith(".csv")}
C = {r["key"]: r["value"] for r in T["constants"]}
SK = index(T["skills"], "skill_id"); EN = index(T["enemies"], "enemy_id")
SL = {(r["skill_id"], r["level"]): r for r in T["skill_levels"]}
REALM = sorted(T["realms"], key=lambda r: r["order"]); RI = index(T["realms"], "realm_id")
Q = sorted(T["qualities"], key=lambda q: q["order"])
TIER = index(T["gear_tiers"], "gear_tier"); MAPS = index(T["maps"], "map_id")
BASES = [b for b in T["equip_bases"] if b["is_core"] == "false"]
DEFK = C["DEF_CONST"]
_miss = [k for k in PACING_KEYS if k not in C]
if _miss: sys.exit("constants.csv 缺少节奏常量：" + ",".join(_miss))

def lerp_q(qf, key):
    i = min(int(qf), 5); f = qf - i
    a = Q[i - 1][key]; b = Q[min(i, 5) - 1 + (1 if i < 5 else 0)][key] if i < 5 else a
    return a + (b - a) * f

def tier_mult(tf):
    lo = int(math.floor(tf)); hi = min(lo + 1, 3); f = tf - lo
    return TIER[lo]["flat_mult"] * (1 - f) + TIER[hi]["flat_mult"] * f

def player_stats(realm, tf, qf, passive=None, plv=1):
    tm, bm, ac = tier_mult(tf), lerp_q(qf, "base_mult"), lerp_q(qf, "affix_count")
    g = {k: sum(b[k] for b in BASES if b["gear_tier"] == 1) * tm * bm for k in ("atk", "hp", "def")}
    crit_g = sum(b["crit_rate"] for b in BASES if b["gear_tier"] == 1)
    naff = ac * 6
    st = dict(atk=(realm["atk"] + g["atk"]) * (1 + ASSUME["AFFIX_OFF"] * naff), hp=(realm["hp"] + g["hp"]) * (1 + ASSUME["AFFIX_DEF"] * naff),
              df=realm["def"] + g["def"], cr=realm["crit_rate"] + crit_g, cd=realm["crit_dmg"], thunder=0, tcdr=0, xs=0, reflect=0)
    if passive:
        r = SL[(passive, plv)]
        e = SK[passive]["effect_type"]; e2 = SK[passive]["effect2_type"]
        if e == "crit_rate_add": st["cr"] += r["effect_value"]
        if e2 == "extra_sword_chance": st["xs"] += r["effect2_value"]
        if e == "thunder_dmg_pct": st["thunder"] += r["effect_value"]
        if e2 == "thunder_cdr": st["tcdr"] += r["effect2_value"]
        if e == "hp_pct": st["hp"] *= 1 + r["effect_value"]
        if e2 == "reflect_add": st["reflect"] += r["effect2_value"]
    return st

def targets(s, n, lvl_chain):
    sh = s["shape"]
    if n <= 1 or sh in ("projectile", "none"): return 1.0
    if sh == "line": return 1 + (n - 1) * 0.5 * ASSUME["AOE_EFF"]
    if sh == "chain":
        k = min(lvl_chain, int(n) - 1) if n >= 2 else 0
        frac = n - int(n)
        tot = sum((1 - s["chain_decay"]) ** j for j in range(k + 1))
        return 1 + (tot - 1) * ASSUME["AOE_EFF"]
    if sh in ("circle", "aura", "self_buff"):
        cover = min(1.0, s["radius_px"] / 220.0)
        return 1 + (n - 1) * cover * ASSUME["AOE_EFF"]
    if sh == "rect": return 1.0   # 九霄神雷：9道雷锁定敌人，总伤与人数无关
    return 1.0

def guard_uptime(slv):
    g = SL[("SK_GANG_GUARD", slv["SK_GANG_GUARD"])]
    return min(1.0, SK["SK_GANG_GUARD"]["duration_s"] / g["cd_s"])

def dps(build, passive, slv, st, n, boss, hit_rate=0.0):
    """返回 (总DPS, 明细dict)。n=同时目标数；boss=是否首领战；
    hit_rate=每秒受到的近战/接触攻击次数（用于护体反震），已按全局内置间隔封顶。"""
    crit = 1 + min(st["cr"], C["CRIT_RATE_CAP"]) * (st["cd"] - 1)
    out = {"normal": st["atk"] * C["PLAYER_NORMAL_ATK_COEF"] / C["PLAYER_NORMAL_ATK_INTERVAL"] * crit}
    for sid in build:
        s = SK[sid]; r = SL[(sid, slv[sid])]
        cdr = min(C["CDR_CAP"], st["tcdr"] if s["gongfa_id"] == "GF_THUNDER" else 0)
        cd = r["cd_s"] * (1 - cdr)
        mult = 1 + (st["thunder"] if s["gongfa_id"] == "GF_THUNDER" else 0)
        per = r["damage_coef"] * max(s["hits"], 1) * targets(s, n, r["chain_count"])
        if sid == "SK_GANG_GUARD":   # v2：护体不再增伤，改为护盾期间反震（攻击×系数/次，不暴击）
            out[sid] = st["atk"] * r["damage_coef"] * hit_rate * guard_uptime(slv)
            continue
        if sid == "SK_SWORD_EXECUTE" and boss: per *= 1 + r["effect_value"]
        if sid == "SK_GANG_VAJRA":  # 爆发=攻击×系数×目标 + 吸收量×比例（假设吸收护盾60%）
            per = r["damage_coef"] * targets(s, n, 0)
            per += (st["hp"] * r["effect_value"] * 0.6 * r["effect2_value"]) / st["atk"]
        if s["gongfa_id"] == "GF_SWORD" and st["xs"] > 0:
            per += st["xs"] * max(s["hits"], 1) * 0.8
        out[sid] = st["atk"] * per / cd * mult * crit
    return sum(out.values()), out

def pdr(df): return 1 - df / (df + DEFK)

def choose_build(owned, level, st_fn, slv, n, w_boss=0.4):
    """模拟“会动脑的普通玩家”：在已拥有技能中，先保证首领战能活下来（手动存活≥首领耗时×1.2），
    再选 综合DPS=60%群体+40%单体 最高的4主动+1被动。"""
    import itertools
    best = None
    act = sorted(s for s in owned if SK[s]["slot_type"] == "active")
    pas = [None] + sorted(p for p in owned if SK[p]["slot_type"] == "passive")
    for p in pas:
        st = st_fn(p)
        for comb in itertools.combinations(act, min(4, len(act))):
            v = (1 - w_boss) * dps(comb, p, slv, st, n, False)[0] + w_boss * dps(comb, p, slv, st, 1, True)[0]
            tb = level_combat(level, comb, p, slv, st)[1]
            ok = survival(level, st, comb, slv)[1] >= tb * 1.2 and tb <= 55
            key = (ok, v)
            if best is None or key > best[0]: best = (key, comb, p)
    return best[1], best[2]

def approach_time(spawn_px, enemy_speed):
    """接敌时间：敌人刷在 spawn_px 外，玩家（自动前进）与敌人相向而行，直到距离进入 AUTO_ENGAGE_RANGE_PX 开始稳定输出。"""
    return max(0.0, spawn_px - C["AUTO_ENGAGE_RANGE_PX"]) / (C["PLAYER_MOVE_SPEED"] + enemy_speed)

def wave_info(level):
    """每波：(等效血量, 密度, 数量, 接敌s, 后续组出场延迟s, 原始血量)。"""
    rows = [w for w in T["waves"] if w["level_id"] == level["level_id"]]
    res = []
    for wi in sorted({w["wave_index"] for w in rows}):
        ws = [w for w in rows if w["wave_index"] == wi]
        hp_raw = sum(EN[w["enemy_id"]]["hp"] * level["enemy_hp_mult"] * w["count"] for w in ws)
        hp_eff = sum(EN[w["enemy_id"]]["hp"] * level["enemy_hp_mult"] / pdr(EN[w["enemy_id"]]["def"]) * w["count"] for w in ws)
        dens = sum(w["count"] * (1 if w["formation"] == "cluster" else ASSUME["SPREAD_DENSITY"]) for w in ws)
        appr = approach_time(C["SPAWN_DISTANCE_PX"], max(EN[w["enemy_id"]]["move_speed"] for w in ws))   # 最快的一组先接敌
        stag = max(w["spawn_delay_s"] for w in ws)   # 后到的一组（waves.spawn_delay_s）按全额计入，偏保守
        res.append((hp_eff, min(dens, ASSUME["MAX_CLUSTER"]), sum(w["count"] for w in ws), appr, stag, hp_raw))
    return res

def wave_hit_rate(level, wi):
    """清怪时每秒受到的近战/接触攻击次数：最多3只近战怪同时贴身（远程怪不计）。"""
    ms = []
    for w in T["waves"]:
        if w["level_id"] == level["level_id"] and w["wave_index"] == wi and EN[w["enemy_id"]]["behavior"] != "ranged":
            ms += [EN[w["enemy_id"]]["attack_interval_s"]] * w["count"]
    return min(sum(1 / i for i in sorted(ms)[:3]), 1 / C["REFLECT_COUNTER_ICD"])

def boss_hit_rate(level):
    b = EN[level["boss_id"]]
    return min(sum(a["count"] / a["cd_s"] for a in T["boss_attacks"] if a["boss_id"] == b["enemy_id"] and a["is_danger"] == "false"),
               1 / C["REFLECT_COUNTER_ICD"])

def level_combat(level, build, passive, slv, st, detail=False):
    """返回 (tw 清怪含行进/接敌, tb 首领战=首领出现到倒下（与60秒限时同口径）, bd 首领有效DPS)；
    detail=True 时另返回 (kill_s 纯击杀耗时, fixed_s 固定节奏耗时：行进+接敌+出场延迟+首领登场+结算)。
    伤害按“等效血量=血量/(1−减伤率)”结算，即默认所有伤害吃防御；
    REFLECT_IGNORE_DEF / COUNTER_IGNORE_DEF=1 时，把反伤/反震部分按 1/(1−减伤率) 放大（等价于无视防御）。"""
    kill = fixed = 0.0
    waves = wave_info(level)
    fixed += C["RUN_START_WALK_TIME"] + C["WAVE_ENTER_WALK_TIME"] * (len(waves) - 1)
    for wi, (hp_eff, n, cnt, appr, stag, hp_raw) in enumerate(waves, 1):
        tot, parts = dps(build, passive, slv, st, max(n, 1), False, wave_hit_rate(level, wi))
        if C["COUNTER_IGNORE_DEF"] and "SK_GANG_GUARD" in parts:
            tot += parts["SK_GANG_GUARD"] * (hp_eff / hp_raw - 1)
        kill += hp_eff / (tot * ASSUME["UPTIME_WAVE"]); fixed += appr + stag
    tw = kill + fixed
    b = EN[level["boss_id"]]; k = 1 / pdr(b["def"])
    bhp = b["hp"] * level["boss_hp_mult"] * k
    tot, parts = dps(build, passive, slv, st, 1, True, boss_hit_rate(level))
    if C["COUNTER_IGNORE_DEF"] and "SK_GANG_GUARD" in parts:
        tot += parts["SK_GANG_GUARD"] * (k - 1)
    bd = tot * ASSUME["UPTIME_BOSS"] + reflect_dps(level, st, build, slv) * (k if C["REFLECT_IGNORE_DEF"] else 1)
    b_appr = approach_time(C["BOSS_SPAWN_DISTANCE_PX"], b["move_speed"])
    tb = bhp / bd + b_appr
    kill += bhp / bd; fixed += b_appr + C["BOSS_INTRO_TIME"] + C["RESULT_SHOW_TIME"]
    return (tw, tb, bd, kill, fixed) if detail else (tw, tb, bd)

def boss_melee_dps(level):
    b = EN[level["boss_id"]]; atk = b["atk"] * level["boss_atk_mult"]
    return sum(atk * a["damage_coef"] * a["count"] / a["cd_s"] for a in T["boss_attacks"]
               if a["boss_id"] == b["enemy_id"] and a["is_danger"] == "false")

def reflect_dps(level, st, build, slv):
    """反伤：首领普通近战攻击（减伤前）×反伤比例（被动/词条 + 护体护盾期间按覆盖率折算）。"""
    r = st["reflect"]
    if "SK_GANG_GUARD" in build:
        r += SL[("SK_GANG_GUARD", slv["SK_GANG_GUARD"])]["effect2_value"] * guard_uptime(slv)
    return boss_melee_dps(level) * min(r, C["REFLECT_CAP"])

def survival(level, st, build, slv, detail=False):
    """首领战存活时间（秒），0.1秒步长模拟，上限300秒（超过记∞）。
    - 普攻与按攻击系数结算的危险攻击按速率持续结算（×减伤）；自动模式危险攻击全中，手动按80%闪避。
    - true_maxhp 类（玄岩天坠）按 first_cast_s + k×cd_s 离散结算：最大生命×比例的真实伤害，无视防御/减伤，先扣护盾；
      手动按期望 (1−闪避率) 结算。
    - 护盾技能（护体/金刚不坏）按“为天坠预留”的AI释放（见 sim 注释），护盾值=最大生命×比例，持续 duration_s。"""
    b = EN[level["boss_id"]]; atk = b["atk"] * level["boss_atk_mult"]
    normal = danger = 0; burst = []
    for a in T["boss_attacks"]:
        if a["boss_id"] != b["enemy_id"] or a["min_level_index"] > level["index"]: continue
        if a["damage_type"] == "true_maxhp":
            burst.append(a); continue
        v = atk * a["damage_coef"] * a["count"] / a["cd_s"]
        if a["is_danger"] == "true": danger += v
        else: normal += v
    red = pdr(st["df"])
    if "SK_GANG_GALE" in build:
        r = SL[("SK_GANG_GALE", slv["SK_GANG_GALE"])]; red *= 1 - r["effect_value"] * SK["SK_GANG_GALE"]["duration_s"] / r["cd_s"]
    shields = [(SK[sid], SL[(sid, slv[sid])]) for sid in build if SK[sid]["effect_type"] == "shield_maxhp_pct"]
    warn = C["BOSS_WARN_TIME"]
    def sim(dodge):
        hp = st["hp"]; dt = 0.1; low = 1.0
        pools = [[0.0, -1.0] for _ in shields]   # [护盾值, 到期时间]
        ready = [0.0 for _ in shields]           # 技能可再次释放的时间
        rate = (normal + danger * (1 - dodge)) * red
        nxt = [a["first_cast_s"] for a in burst]
        for k in range(int(300 / dt)):
            t = k * dt
            # 护盾AI（自动/手动相同）：短冷却护盾（护体）按冷却释放；长冷却护盾（金刚不坏）在天坠预警期间可用就立刻开，
            # 否则只有“冷却好之前不会撞上下一次天坠预警”时才按冷却释放
            tel = any(n_ - warn - 1e-9 <= t < n_ for n_ in nxt)
            to_next = min([n_ - warn - t for n_ in nxt], default=999)
            for j, (s_, r_) in enumerate(shields):
                hold = r_["cd_s"] >= C["AUTO_SHIELD_RESERVE_CD"]   # 只有长冷却护盾（金刚不坏）会为天坠预留
                if t + 1e-9 >= ready[j] and (not hold or tel or to_next >= r_["cd_s"] or to_next < 0):
                    pools[j] = [st["hp"] * r_["effect_value"], t + s_["duration_s"]]; ready[j] = t + r_["cd_s"]
            dmg = rate * dt
            for j, a in enumerate(burst):
                if t + 1e-9 >= nxt[j]:
                    dmg += st["hp"] * a["damage_maxhp_pct"] * (1 - dodge); nxt[j] += a["cd_s"]
            for pl in pools:
                if pl[1] > t and dmg > 0:
                    use = min(pl[0], dmg); pl[0] -= use; dmg -= use
            hp -= dmg; low = min(low, hp / st["hp"])
            if hp <= 0: return t, 0.0
        return float("inf"), low
    a_t, a_low = sim(0.0); m_t, m_low = sim(ASSUME["DANGER_DODGE_MANUAL"])
    return (a_t, m_t, a_low, m_low) if detail else (a_t, m_t)

def spend(lingshi, slv, build, passive):
    eq = list(build) + ([passive] if passive else [])
    while True:
        cands = [(SL[(s, slv[s])]["upgrade_cost_lingshi"], s) for s in eq if slv[s] < 10]
        if not cands: return lingshi
        c, s = min(cands)
        if c > lingshi: return lingshi
        lingshi -= c; slv[s] += 1

def run_rewards(level):
    ls = xw = 0
    for w in T["waves"]:
        if w["level_id"] == level["level_id"]:
            e = EN[w["enemy_id"]]; ls += e["lingshi"] * w["count"] * level["enemy_hp_mult"]; xw += e["xiuwei"] * w["count"] * level["enemy_hp_mult"]
    b = EN[level["boss_id"]]; ls += b["lingshi"] * level["boss_hp_mult"]; xw += b["xiuwei"] * level["boss_hp_mult"]
    return ls, xw

def main(md=False):
    owned = {"SK_SWORD_FLYING", "SK_THUNDER_STRIKE", "SK_GANG_GUARD"}
    slv = {s: 1 for s in SK}
    lingshi = 100 + 100  # 新手引导奖励
    xiuwei = 0; realm_i = 0; total = 0.0
    levels = sorted(T["levels"], key=lambda L: L["global_index"])
    fcr = T["first_clear_rewards"]
    report = []; map_time = {}
    for L in levels:
        m = MAPS[L["map_id"]]; tier = m["gear_tier"]; tf, qf = GEAR[tier][L["index"] - 1]
        realm = REALM[realm_i]
        st_fn = lambda p: player_stats(realm, tf, qf, p, slv.get(p, 1) if p else 1)
        waves = wave_info(L); n_avg = sum(w[1] for w in waves) / 4
        build, passive = choose_build(owned, L, st_fn, slv, n_avg)
        # 先花灵石（保留下一次突破所需灵石的一部分）
        nxt = REALM[realm_i + 1] if realm_i + 1 < len(REALM) else None
        reserve = (nxt["lingshi_cost"] * (L["index"] - 1) / 4) if nxt else 0
        budget = max(0, lingshi - reserve) * ASSUME["LINGSHI_SPEND"]
        left = spend(budget, slv, build, passive); lingshi -= budget - left
        st = st_fn(passive)
        tw, tb, bd, kill_s, fixed_s = level_combat(L, build, passive, slv, st, detail=True)
        ttd_a, ttd_m = survival(L, st, build, slv)
        over = ASSUME["LEVEL_OVERHEAD"] + (ASSUME["TUTORIAL_OVERHEAD"] if L["global_index"] == 1 else 0)
        show = C["BOSS_INTRO_TIME"] + C["RESULT_SHOW_TIME"]   # 首领登场 + 结算展示
        t = tw + tb + show + over
        ls, xw = run_rewards(L)
        lingshi += ls; xiuwei += xw
        for r in fcr:
            if r["level_id"] != L["level_id"]: continue
            if r["reward_type"] == "lingshi": lingshi += r["count"]
            if r["reward_type"] == "xiuwei": xiuwei += r["count"]
            if r["reward_type"] == "book": owned.add(SK_BY_BOOK[r["ref_id"]])
        grind = 0.0; runs = 0
        if L["index"] == 5 and nxt:
            run_t = kill_s * ASSUME["FARM_SPEEDUP"] + fixed_s
            while xiuwei < nxt["xiuwei_cost"] or lingshi < nxt["lingshi_cost"]:
                runs += 1; grind += run_t; lingshi += ls; xiuwei += xw
            xiuwei -= nxt["xiuwei_cost"]; lingshi -= nxt["lingshi_cost"]; realm_i += 1
            grind += ASSUME["BREAK_OVERHEAD"]
        t += grind
        total += t; map_time[m["name"]] = map_time.get(m["name"], 0) + t
        report.append(dict(level_id=L["level_id"], name=L["name"], realm=realm["name"], gear="T%.1f/Q%.1f" % (tf, qf),
                           build="、".join(SK[s]["name"] for s in build) + ("+" + SK[passive]["name"] if passive else ""),
                           skill_lv="/".join(str(slv[s]) for s in build), atk=round(st["atk"]), hp=round(st["hp"]),
                           wave_s=round(tw, 1), boss_s=round(tb, 1), show_s=show, boss_dps=round(bd), overhead_s=over, grind_runs=runs,
                           grind_s=round(grind), level_total_s=round(t), cum_min=round(total / 60, 1),
                           ttd_auto=("inf" if ttd_a == float("inf") else round(ttd_a, 1)),
                           ttd_manual=("inf" if ttd_m == float("inf") else round(ttd_m, 1)),
                           lingshi_left=round(lingshi), xiuwei_left=round(xiuwei)))
        L["_st"] = st; L["_slv_avg"] = sum(slv[s] for s in build) / len(build)
    out = os.path.join(os.path.dirname(DATA), "balance_report.csv")
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(report[0].keys()), lineterminator="\n"); w.writeheader(); w.writerows(report)
    # 三流派对比（同关、同装备、同技能等级=该关主线平均技能等级取整，全书已获得的理论对比）
    schools = {"飞剑诀": ("GF_SWORD", "SK_SWORD_PASSIVE"), "御雷诀": ("GF_THUNDER", "SK_THUNDER_PASSIVE"), "玄罡诀": ("GF_GANG", "SK_GANG_PASSIVE")}
    comp = []
    for L in levels:
        lvv = max(1, round(L["_slv_avg"]))
        tier = MAPS[L["map_id"]]["gear_tier"]; tf, qf = GEAR[tier][L["index"] - 1]
        realm = REALM[min(tier - 1, 2)]
        row = dict(level_id=L["level_id"], skill_lv=lvv)
        for nm, (gf, ps) in schools.items():
            b = [s for s in SK if SK[s]["gongfa_id"] == gf and SK[s]["slot_type"] == "active"]
            sl2 = {s: lvv for s in SK}
            st = player_stats(realm, tf, qf, ps, lvv)
            tw, tb, bd = level_combat(L, b, ps, sl2, st)
            ta, tm = survival(L, st, b, sl2)
            gd = dps(b, ps, sl2, st, 5, False, 1 / C["REFLECT_COUNTER_ICD"])[0]   # 5目标：近战贴身，反震按上限计
            sd = dps(b, ps, sl2, st, 1, True, boss_hit_rate(L))[0] + reflect_dps(L, st, b, sl2) / ASSUME["UPTIME_BOSS"]
            row[nm] = dict(single=round(sd), group5=round(gd), wave=round(tw), boss=round(tb),
                           ttd_auto=("∞" if ta == float("inf") else round(ta)), ttd_manual=("∞" if tm == float("inf") else round(tm)))
        comp.append(row)
    # 打印
    print("节奏常量(constants.csv):", {k: C[k] for k in PACING_KEYS})
    print("关卡 | 境界 | 装备 | 配置 | 技能等级 | ATK | HP | 清波s | 首领s | 首领DPS | 突破挂机轮数 | 本关s | 累计min | 首领战存活s(自动/手动)")
    for r in report:
        print("%s %s | %s | %s | %s | %s | %d | %d | %.0f | %.0f | %d | %d | %d | %.1f | %s/%s" % (
            r["level_id"], r["name"], r["realm"], r["gear"], r["build"], r["skill_lv"], r["atk"], r["hp"], r["wave_s"], r["boss_s"],
            r["boss_dps"], r["grind_runs"], r["level_total_s"], r["cum_min"], r["ttd_auto"], r["ttd_manual"]))
    print("分地图(min):", {k: round(v / 60, 1) for k, v in map_time.items()}, " 主线总计 %.1f min" % (total / 60))
    print("\n三流派同关对比（单体DPS/5目标DPS/清波s/首领s/存活s 自动|手动）")
    for r in comp:
        print(r["level_id"], "Lv%d" % r["skill_lv"], " | ".join("%s %s/%s/%s/%s/%s|%s" % (k, v["single"], v["group5"], v["wave"], v["boss"], v["ttd_auto"], v["ttd_manual"]) for k, v in r.items() if isinstance(v, dict)))
    if md:
        print("\n<!--MD-->")
        print("| 关卡 | 境界 | 等效装备 | 主线配置(4主动+被动) | 技能等级 | 攻击 | 生命 | 4波清怪(s) | 首领(s) | 登场+结算(s) | 操作/引导(s) | 突破补刷(s) | 本关合计(s) | 累计(min) | 首领战存活s 自动/手动 |")
        print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
        for r in report:
            print("| %s %s | %s | %s | %s | %s | %d | %d | %.0f | %.0f | %.0f | %.0f | %d | %d | %.1f | %s / %s |" % (r["level_id"], r["name"], r["realm"], r["gear"], r["build"], r["skill_lv"], r["atk"], r["hp"], r["wave_s"], r["boss_s"], r["show_s"], r["overhead_s"], r["grind_s"], r["level_total_s"], r["cum_min"], r["ttd_auto"], r["ttd_manual"]))
        print("\n| 关卡 | 技能等级 | 飞剑诀 单体/5目标DPS | 御雷诀 单体/5目标DPS | 玄罡诀 单体/5目标DPS | 清怪s 剑/雷/罡 | 首领s 剑/雷/罡 | 首领存活s(自动) 剑/雷/罡 | 首领存活s(手动) 剑/雷/罡 |")
        print("|---|---|---|---|---|---|---|---|---|")
        for r in comp:
            a, b, c = r["飞剑诀"], r["御雷诀"], r["玄罡诀"]
            print("| %s | %d | %s/%s | %s/%s | %s/%s | %s/%s/%s | %s/%s/%s | %s/%s/%s | %s/%s/%s |" % (r["level_id"], r["skill_lv"], a["single"], a["group5"], b["single"], b["group5"], c["single"], c["group5"], a["wave"], b["wave"], c["wave"], a["boss"], b["boss"], c["boss"], a["ttd_auto"], b["ttd_auto"], c["ttd_auto"], a["ttd_manual"], b["ttd_manual"], c["ttd_manual"]))
    # 玄岩天坠：自动挂机 vs 手动闪避 vs 护盾 对比（LV_3_4 / LV_3_5，同装备同技能等级）
    print("\n<!--SKYFALL-->")
    print("| 关卡 | 配置 | 首领耗时(s) | 自动：存活s / 最低血量 | 手动闪避80%：存活s / 最低血量 | 结论 |")
    print("|---|---|---|---|---|---|")
    fmt = lambda t, lo: ("∞ / %d%%" % round(lo * 100)) if t == float("inf") else ("%.0f / 阵亡" % t)
    for L in levels:
        if L["level_id"] not in ("LV_3_4", "LV_3_5"): continue
        lvv = max(1, round(L["_slv_avg"])); tf, qf = GEAR[3][L["index"] - 1]
        cases = [("纯飞剑诀", [s_ for s_ in SK if SK[s_]["gongfa_id"] == "GF_SWORD" and SK[s_]["slot_type"] == "active"], "SK_SWORD_PASSIVE"),
                 ("纯御雷诀", [s_ for s_ in SK if SK[s_]["gongfa_id"] == "GF_THUNDER" and SK[s_]["slot_type"] == "active"], "SK_THUNDER_PASSIVE"),
                 ("纯玄罡诀", [s_ for s_ in SK if SK[s_]["gongfa_id"] == "GF_GANG" and SK[s_]["slot_type"] == "active"], "SK_GANG_PASSIVE"),
                 ("飞剑+护体+金刚不坏", ["SK_SWORD_FLYING", "SK_SWORD_COMBO", "SK_GANG_GUARD", "SK_GANG_VAJRA"], "SK_SWORD_PASSIVE"),
                 ("飞剑+护体（仅短盾）", ["SK_SWORD_FLYING", "SK_SWORD_COMBO", "SK_SWORD_EXECUTE", "SK_GANG_GUARD"], "SK_SWORD_PASSIVE")]
        for nm, b, ps in cases:
            sl2 = {s_: lvv for s_ in SK}; st = player_stats(REALM[2], tf, qf, ps, lvv)
            tb = level_combat(L, b, ps, sl2, st)[1]
            at, mt, alo, mlo = survival(L, st, b, sl2, detail=True)
            # v4：首领耗时不再含登场3秒，自动存活只比首领耗时多不到10%的记为“临界”（实战波动足以翻车）
            verdict = ("自动可过" if at > tb * 1.1 else ("自动临界，建议手动闪避" if at > tb else ("需手动闪避" if mt > tb else "需提升装备/换配置"))) + ("" if tb <= 60 else "（超时）")
            print("| %s | %s | %.0f | %s | %s | %s |" % (L["level_id"], nm, tb, fmt(at, alo), fmt(mt, mlo), verdict))
    return total

SK_BY_BOOK = {s["book_id"]: s["skill_id"] for s in T["skills"]}
if __name__ == "__main__":
    main("--md" in sys.argv)

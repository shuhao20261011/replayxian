# -*- coding: utf-8 -*-
"""读取 design/data 下全部 CSV 的公共函数。"""
import csv, os
DATA = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")

def num(v):
    if v is None:
        return v
    s = str(v).strip()
    if s == "":
        return s
    try:
        f = float(s)
        return int(f) if f.is_integer() and "." not in s else f
    except ValueError:
        return s

def load(name):
    with open(os.path.join(DATA, name), encoding="utf-8", newline="") as f:
        return [{k: num(v) for k, v in r.items()} for r in csv.DictReader(f)]

def index(rows, key):
    return {r[key]: r for r in rows}

# ---------------------------------------------------------------- v5 文案占位符
import re
# 占位符语法：{字段} 或 {字段:格式}。格式：pct=×100 后加 %（最多1位小数）；num=原值去尾零（默认）；int=四舍五入取整
PH_RE = re.compile(r"\{([a-z_][a-z0-9_]*)(?::(pct|num|int))?\}")

def fmt_num(v):
    v = round(float(v), 2)
    return str(int(v)) if v.is_integer() else ("%g" % v)

def fmt_ph(v, f):
    if f == "pct":
        p = round(float(v) * 100, 1)
        return (str(int(p)) if p.is_integer() else "%g" % p) + "%"
    if f == "int":
        return str(int(round(float(v))))
    return fmt_num(v)

def render_tpl(tpl, row):
    """把模板中的占位符替换为 row 中同名字段的值；字段缺失抛 KeyError。"""
    return PH_RE.sub(lambda m: fmt_ph(row[m.group(1)], m.group(2)), tpl)

# ---------------------------------------------------------------- BUG-005 首领危险招式时间轴（复刻前端 boss.gd 排招逻辑）
def danger_schedule(attacks, level_index, horizon=60.0, multi_interval=0.4, default_warn=0.8, dt=1.0 / 60, order=None):
    """attacks：按 enemies.behavior_param.attack_ids 顺序的 boss_attacks 行。逐帧（默认60帧/秒）复刻 boss.gd：
    - 首领出现时危险招式计时器=first_cast_s，每帧减 dt；
    - 首领不在前摇（busy=warn_s）且场上没有任何预警时，按列表顺序释放第一个计时器≤0的危险招式，计时器重置为 cd_s
      （从实际释放时刻算，被挡住而延后的招式会把自己后续整体推迟）；
    - anchor=player 的多段招式第 i 段延迟 i×BOSS_MULTI_AREA_INTERVAL 出现；每段在 出现+warn_s 时判定并移除；
    - order：可传入另一种优先顺序（attack_id 列表），用来检验“两招同时就绪时谁先放”的偶然性。
    返回 [(attack_id, 释放时刻, 首个判定, 末个判定)]（首个判定 ≤ horizon）。不考虑眩晕等打断。"""
    act = [a for a in attacks if str(a["is_danger"]) == "true" and a["min_level_index"] <= level_index]
    if order: act.sort(key=lambda a: order.index(a["attack_id"]))
    timer = {a["attack_id"]: float(a["first_cast_s"]) for a in act}
    busy, t, tele, out = 0.0, 0.0, [], []
    for _ in range(int(horizon / dt) + 1):
        t += dt
        tele = [x for x in tele if x > t]                        # 本帧到点的预警判定并移除
        for k in timer: timer[k] -= dt
        busy = max(busy - dt, 0.0)
        if busy > 0 or tele: continue
        a = next((x for x in act if timer[x["attack_id"]] <= 0.0), None)   # 与 boss.gd 一致：严格 <= 0（浮点残差会让个别招式晚1帧）
        if a is None: continue
        warn = float(a["warn_s"]) or default_warn
        n = int(a["count"]) if a["anchor"] == "player" else 1
        hits = [t + i * multi_interval + warn for i in range(n)]
        tele = hits; busy = warn; timer[a["attack_id"]] = float(a["cd_s"])
        if hits[0] <= horizon: out.append((a["attack_id"], round(t, 2), round(hits[0], 2), round(hits[-1], 2)))
    return out

def danger_gap_violations(T, min_gap, horizon=60.0):
    """每关首领：相邻两次危险招式，后者首个判定 − 前者末个判定 必须 ≥ min_gap（=闪避冷却+余量）。
    除按表中顺序外，还把危险招式的优先顺序全排列各跑一遍（防止两招恰好同帧就绪时顺序翻转），取最差。
    返回 [(level_id, 前招, 后招, 间隔, 前末判定, 后首判定, 优先顺序)]。"""
    import itertools
    C = {r["key"]: r["value"] for r in T["constants"]}
    BA = {a["attack_id"]: a for a in T["boss_attacks"]}
    EN = {e["enemy_id"]: e for e in T["enemies"]}
    bad = []
    for L in sorted(T["levels"], key=lambda x: x["global_index"]):
        ids = dict(kv.split("=") for kv in str(EN[L["boss_id"]]["behavior_param"]).split(";"))["attack_ids"].split("|")
        rows = [BA[i] for i in ids]
        dang = [a["attack_id"] for a in rows if str(a["is_danger"]) == "true"]
        hz = min(horizon, float(L["boss_time_limit_s"] or horizon))
        for perm in [None] + list(itertools.permutations(dang)):
            sch = danger_schedule(rows, L["index"], hz, float(C.get("BOSS_MULTI_AREA_INTERVAL", 0.4)),
                                  float(C.get("BOSS_WARN_TIME", 0.8)), order=list(perm) if perm else None)
            found = [(L["level_id"], p[0], q[0], round(q[2] - p[3], 2), p[3], q[2], "表中顺序" if perm is None else "|".join(perm))
                     for p, q in zip(sch, sch[1:]) if q[2] - p[3] < min_gap - 1e-9]
            if found: bad += found; break
    return bad

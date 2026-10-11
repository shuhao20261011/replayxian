#!/usr/bin/env python3
"""用策划工具 design/tools/common.py 的 render_tpl() 生成占位符渲染对照用例 → tests/fixtures/render_tpl_cases.json。
test_ui_text.gd 用它校验 GDScript 版 UiText.render() 与 Python 版逐字一致。设计表更新后重跑：python3 tools/gen_render_cases.py"""
import json, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "design", "tools"))
from common import load, render_tpl  # noqa: E402

cases = []
# 1) 数值边界：pct/num/int 与舍入（含恰好一半、浮点表示误差、负数、大数）
vals = [0, 1, -1, 0.5, 1.5, 2.5, -2.5, 0.125, 0.375, 2.675, 1.005, 0.0125, 0.015, 0.08, 0.155, 0.333333, 1.6, 2.4, 3.3,
        12.0, 99.995, 123456.78, 100000.5, 0.001, 0.004, 0.005, 0.006, 7.25, 0.07, 0.29, 0.57, 1e-7, 1234567.891]
for v in vals:
    for f in ("", ":num", ":pct", ":int"):
        tpl = "a{x%s}b" % f
        cases.append({"tpl": tpl, "row": {"x": str(v)}, "out": render_tpl(tpl, {"x": v})})
# 2) 真表：skills 按1–10级（skill_levels 覆盖 skills 同名字段），orange_effects / boss_attacks 取本行
def strs(r):
    return {k: ("" if v is None else str(v)) for k, v in r.items()}
skills = load("skills.csv"); SL = {(r["skill_id"], r["level"]): r for r in load("skill_levels.csv")}
for s in skills:
    for lv in range(1, 11):
        if (s["skill_id"], lv) in SL:
            ctx = dict(s, **SL[(s["skill_id"], lv)])
            cases.append({"skill_id": s["skill_id"], "level": lv, "out": render_tpl(str(s["desc_tpl"]), ctx)})
for t in ("orange_effects.csv", "boss_attacks.csv"):
    for r in load(t):
        if str(r.get("desc_tpl", "")).strip():
            cases.append({"tpl": str(r["desc_tpl"]), "row": strs(r), "out": render_tpl(str(r["desc_tpl"]), r)})
json.dump(cases, open(os.path.join(ROOT, "tests", "fixtures", "render_tpl_cases.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
print(len(cases), "cases")

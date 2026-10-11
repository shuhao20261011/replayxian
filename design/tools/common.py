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

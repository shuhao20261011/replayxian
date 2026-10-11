# -*- coding: utf-8 -*-
"""《重走修仙路》配置表生成器（首版数值源）。
运行：python3 tools/gen_tables.py   （在 design/ 目录下）
输出：design/data/*.csv（UTF-8，无BOM，逗号分隔，首行字段名）。
说明：本脚本是首版数值的“种子”。之后若直接手改 CSV，请不要再运行本脚本覆盖；
或者把修改同步回本脚本后再生成。改完务必运行 validate.py 与 balance.py。
"""
import csv, os, math

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "data")
os.makedirs(OUT, exist_ok=True)

def write(name, fields, rows):
    with open(os.path.join(OUT, name), "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields, lineterminator="\n")
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in fields})

def rnd(x, n=3):
    v = round(x, n)
    return int(v) if float(v).is_integer() else v

# ---------------------------------------------------------------- constants
constants = [
    ("PLAYER_NORMAL_ATK_COEF", 1.0, "倍率", "普攻伤害系数（×攻击力）"),
    ("PLAYER_NORMAL_ATK_INTERVAL", 0.8, "秒", "普攻基础间隔，受攻速词条缩短：间隔/(1+攻速)"),
    ("PLAYER_NORMAL_ATK_RANGE", 150, "像素", "普攻射程，敌人进入后自动触发"),
    ("PLAYER_MOVE_SPEED", 220, "像素/秒", "角色移动速度"),
    ("PLAYER_BASE_CRIT_RATE", 0.05, "比例", "基础暴击率"),
    ("PLAYER_BASE_CRIT_DMG", 1.5, "倍率", "基础暴击伤害倍率"),
    ("DODGE_DURATION", 0.3, "秒", "闪避持续时间，期间免伤（计划已定）"),
    ("DODGE_COOLDOWN", 3.0, "秒", "闪避冷却（计划已定）"),
    ("DODGE_DISTANCE", 160, "像素", "闪避位移距离"),
    ("BOSS_WARN_TIME", 0.8, "秒", "首领危险攻击预警时长（计划已定）"),
    ("BOSS_TIME_LIMIT", 60, "秒", "首领战限时（计划已定）"),
    ("TELEGRAPH_DEFAULT_COLOR", "#C8312B", "颜色", "首领危险攻击预警默认颜色：朱砂（美术建议）"),
    ("TELEGRAPH_ALT_COLOR", "#FFFFFF", "颜色", "预警可选颜色：白色（设置项/美术切换用）"),
    ("TELEGRAPH_DEFAULT_STYLE", "dashed", "枚举", "预警描边样式：dashed 虚线（默认）/ solid 实线"),
    ("REFLECT_COUNTER_ICD", 0.8, "秒", "护体反震：全局内置触发间隔（每0.8秒最多反震1次）"),
    ("WAVES_PER_LEVEL", 4, "波", "每关普通怪波数（计划已定）"),
    ("DEF_CONST", 100, "点", "减伤公式常数：减伤率=DEF/(DEF+DEF_CONST)"),
    ("CDR_CAP", 0.4, "比例", "冷却缩减上限"),
    ("CRIT_RATE_CAP", 0.75, "比例", "暴击率上限"),
    ("REFLECT_CAP", 0.6, "比例", "反伤比例上限"),
    ("SKILL_MAX_LEVEL", 10, "级", "技能等级上限（计划已定）"),
    ("ACTIVE_SLOT_COUNT", 4, "格", "主动技能栏格数（计划已定）"),
    ("PASSIVE_SLOT_COUNT", 1, "格", "被动技能槽数（计划已定）"),
    ("PAGE_PER_BOOK_DECOMPOSE", 1, "张", "分解1本重复技能书获得悟道残页数"),
    ("PAGE_EXCHANGE_COST", 10, "张", "兑换1本已解锁区域内指定技能书所需残页（计划已定）"),
    ("BAG_EQUIP_CAPACITY", 100, "件", "装备背包容量（计划已定）"),
    ("OFFLINE_CAP_MINUTES", 480, "分钟", "离线收益上限8小时（计划已定）"),
    ("AUTOSAVE_INTERVAL", 10, "秒", "自动存档间隔（计划已定）"),
    ("WAVE_ENTER_WALK_TIME", 3.0, "秒", "两波之间自动前进时间（表现用，估算时长用）"),
    ("FAIL_RETURN_POLICY", "last_cleared", "枚举", "失败后返回最近已通关关卡挂机；未通关时刷第一关普通怪（计划已定）；自动模式另见AUTO_FAIL_RETREAT_*"),
    ("AUTO_FAIL_RETREAT_COUNT", 1, "次", "v3：自动模式下同一关连续失败达到该次数，即把该关标记为“当前配置不稳定”，回退到已通关且未被标记的最高关卡继续自动挂机"),
    ("AUTO_FAIL_RETREAT_RESET_ON", "loadout_change|skill_level_up|realm_up|manual_clear", "枚举", "v3：清除“不稳定”标记的时机：更换技能栏/被动或装备（含重铸）、任一技能升级、境界突破、玩家手动挑战该关成功"),
]
write("constants.csv", ["key", "value", "unit", "desc"],
      [dict(key=k, value=v, unit=u, desc=d) for k, v, u, d in constants])

# ---------------------------------------------------------------- items: currency & materials
materials = [
    ("CUR_LINGSHI", "灵石", "currency", "", "通用货币：技能升级、突破、重铸"),
    ("CUR_XIUWEI", "修为", "currency", "", "境界突破消耗，击杀与通关获得"),
    ("MAT_REFINE", "炼器材料", "material", "", "装备分解/背包溢出获得，用于重铸词条"),
    ("MAT_PAGE", "悟道残页", "material", "", "重复技能书分解获得，10张兑换一本已解锁区域指定技能书"),
    ("MAT_BT_QINGZHU", "青竹灵髓", "breakthrough", "MAP_QINGZHU", "青竹山首领首次击败（第1-5关首通）掉落，炼气→筑基突破材料"),
    ("MAT_BT_LEIZE", "雷泽雷晶", "breakthrough", "MAP_LEIZE", "雷泽谷首领首次击败（第2-5关首通）掉落，筑基→金丹突破材料"),
]
write("materials.csv", ["item_id", "name", "item_type", "map_id", "desc"],
      [dict(item_id=a, name=b, item_type=c, map_id=d, desc=e) for a, b, c, d, e in materials])

# ---------------------------------------------------------------- realms
realms = [
    dict(realm_id="RL_LIANQI", name="炼气", order=1, hp=500, atk=20, def_=10, crit_rate=0.05, crit_dmg=1.5,
         prev_realm_id="", xiuwei_cost=0, lingshi_cost=0, material_id="", material_count=0, unlock_map_id="MAP_QINGZHU",
         desc="初始境界，开放青竹山"),
    dict(realm_id="RL_ZHUJI", name="筑基", order=2, hp=1250, atk=50, def_=25, crit_rate=0.05, crit_dmg=1.6,
         prev_realm_id="RL_LIANQI", xiuwei_cost=2200, lingshi_cost=1500, material_id="MAT_BT_QINGZHU", material_count=1,
         unlock_map_id="MAP_LEIZE", desc="通关青竹山后突破，开放雷泽谷"),
    dict(realm_id="RL_JINDAN", name="金丹", order=3, hp=3000, atk=120, def_=55, crit_rate=0.05, crit_dmg=1.7,
         prev_realm_id="RL_ZHUJI", xiuwei_cost=7500, lingshi_cost=6000, material_id="MAT_BT_LEIZE", material_count=1,
         unlock_map_id="MAP_XUANYAN", desc="通关雷泽谷后突破，开放玄岩洞"),
]
for r in realms:
    r["def"] = r.pop("def_")
write("realms.csv", ["realm_id", "name", "order", "hp", "atk", "def", "crit_rate", "crit_dmg", "prev_realm_id",
                     "xiuwei_cost", "lingshi_cost", "material_id", "material_count", "unlock_map_id", "desc"], realms)

# ---------------------------------------------------------------- gongfa
gongfa = [
    dict(gongfa_id="GF_SWORD", name="飞剑诀", role="高频单体攻击、首领输出", build_dir="攻速、暴击、追加飞剑",
         book_map_id="MAP_QINGZHU", color="#7FD3FF", desc="以飞剑高频点杀单体，首领战输出最高"),
    dict(gongfa_id="GF_THUNDER", name="御雷诀", role="连锁攻击、群体清怪", build_dir="雷伤、连锁目标、冷却缩减",
         book_map_id="MAP_LEIZE", color="#C9A2FF", desc="雷法连锁与范围伤害，成群敌人清怪最快"),
    dict(gongfa_id="GF_GANG", name="玄罡诀", role="护盾、反伤、持续作战", build_dir="生命、护盾、反伤",
         book_map_id="MAP_XUANYAN", color="#FFD27F", desc="护盾与反伤，容错最高，输出偏低但持续稳定"),
]
write("gongfa.csv", ["gongfa_id", "name", "role", "build_dir", "book_map_id", "color", "desc"], gongfa)

# ---------------------------------------------------------------- skills
# tier: basic / normal / ultimate / passive
S = []
def sk(**k):
    base = dict(range_px=0, width_px=0, height_px=0, radius_px=0, max_targets=1, hits=1, damage_coef=0, cd_s=0,
                duration_s=0, tick_interval_s=0, chain_count=0, chain_radius_px=0, chain_decay=0,
                effect_type="none", effect_value=0, effect_duration_s=0, effect2_type="none", effect2_value=0,
                coef_growth=0.10, cd_reduce=0.02, effect_growth=0, effect2_growth=0, default_auto="true")
    base.update(k)
    S.append(base)

# 飞剑诀
sk(skill_id="SK_SWORD_FLYING", gongfa_id="GF_SWORD", name="飞剑", slot_type="active", tier="basic", is_basic="true",
   shape="projectile", anchor="facing", range_px=600, width_px=40, max_targets=1, hits=1, damage_coef=1.6, cd_s=2.0,
   desc="朝面向射出1把飞剑，命中首个敌人造成攻击×系数伤害。基础技能。")
sk(skill_id="SK_SWORD_COMBO", gongfa_id="GF_SWORD", name="连环剑", slot_type="active", tier="normal", is_basic="false",
   shape="projectile", anchor="facing", range_px=600, width_px=40, max_targets=1, hits=3, damage_coef=1.0, cd_s=5.0,
   desc="0.4秒内连续射出3把飞剑，均命中同一目标，每把造成攻击×系数伤害。")
sk(skill_id="SK_SWORD_PIERCE", gongfa_id="GF_SWORD", name="破甲剑", slot_type="active", tier="normal", is_basic="false",
   shape="line", anchor="facing", range_px=700, width_px=60, max_targets=99, hits=1, damage_coef=2.2, cd_s=8.0,
   effect_type="def_down_pct", effect_value=0.30, effect_duration_s=5, effect_growth=0.01,
   desc="贯穿飞剑，命中直线上所有敌人，并使其防御降低（效果值）5秒。")
sk(skill_id="SK_SWORD_EXECUTE", gongfa_id="GF_SWORD", name="诛仙剑", slot_type="active", tier="ultimate", is_basic="false",
   shape="projectile", anchor="facing", range_px=800, width_px=80, max_targets=1, hits=1, damage_coef=5.0, cd_s=15.0,
   effect_type="boss_dmg_bonus", effect_value=0.50, effect_growth=0.05,
   desc="蓄力0.3秒后斩出巨剑，对单体造成高额伤害，对首领额外增伤（效果值）。")
sk(skill_id="SK_SWORD_PASSIVE", gongfa_id="GF_SWORD", name="剑心通明", slot_type="passive", tier="passive", is_basic="false",
   shape="none", anchor="none", max_targets=0, hits=0, damage_coef=0.8, cd_s=0, coef_growth=0, cd_reduce=0,
   effect_type="crit_rate_add", effect_value=0.08, effect_growth=0.01,
   effect2_type="extra_sword_chance", effect2_value=0.15, effect2_growth=0.015, default_auto="",
   desc="被动：暴击率提高（效果值）；飞剑诀主动技能每次命中有（效果2）概率追加1把飞剑，造成攻击×0.8伤害。")
# 御雷诀
sk(skill_id="SK_THUNDER_STRIKE", gongfa_id="GF_THUNDER", name="雷击", slot_type="active", tier="basic", is_basic="true",
   shape="chain", anchor="nearest_front", range_px=500, max_targets=3, hits=1, damage_coef=1.3, cd_s=3.0,
   chain_count=2, chain_radius_px=200, chain_decay=0.15,
   desc="落雷击中前方最近敌人，并向半径内其他敌人连锁，每跳伤害衰减15%。基础技能；5级/10级各+1连锁。")
sk(skill_id="SK_THUNDER_CLOUD", gongfa_id="GF_THUNDER", name="雷云", slot_type="active", tier="normal", is_basic="false",
   shape="circle", anchor="nearest_front", range_px=450, radius_px=180, max_targets=99, hits=6, damage_coef=0.55, cd_s=9.0,
   duration_s=3.0, tick_interval_s=0.5, effect_type="slow_pct", effect_value=0.30, effect_duration_s=1.0,
   desc="在最近敌人处召唤雷云，3秒内每0.5秒对圆形范围内敌人造成伤害并减速30%。")
sk(skill_id="SK_THUNDER_PALM", gongfa_id="GF_THUNDER", name="掌心雷", slot_type="active", tier="normal", is_basic="false",
   shape="circle", anchor="self", radius_px=220, max_targets=99, hits=1, damage_coef=2.2, cd_s=6.0,
   effect_type="stun_s", effect_value=0.5, effect_growth=0.05,
   desc="以自身为中心炸开雷光，对周身敌人造成伤害并眩晕（效果值）秒；首领只受50%时长。")
sk(skill_id="SK_THUNDER_NINE", gongfa_id="GF_THUNDER", name="九霄神雷", slot_type="active", tier="ultimate", is_basic="false",
   shape="rect", anchor="facing", range_px=800, width_px=800, height_px=300, max_targets=99, hits=9, damage_coef=0.9, cd_s=18.0,
   duration_s=1.5, desc="朝面向矩形区域1.5秒内降下9道神雷，每道随机锁定区域内一个敌人（可重复锁定同一敌人），区域内无敌人时不消耗冷却。")
sk(skill_id="SK_THUNDER_PASSIVE", gongfa_id="GF_THUNDER", name="引雷之体", slot_type="passive", tier="passive", is_basic="false",
   shape="none", anchor="none", max_targets=0, hits=0, coef_growth=0, cd_reduce=0,
   effect_type="thunder_dmg_pct", effect_value=0.10, effect_growth=0.02,
   effect2_type="thunder_cdr", effect2_value=0.05, effect2_growth=0.005, default_auto="",
   desc="被动：御雷诀技能伤害提高（效果值），御雷诀主动技能冷却缩减（效果2）。")
# 玄罡诀
sk(skill_id="SK_GANG_GUARD", gongfa_id="GF_GANG", name="护体", slot_type="active", tier="basic", is_basic="true",
   shape="self_buff", anchor="self", max_targets=1, hits=1, damage_coef=0.6, cd_s=8.0, duration_s=6.0, coef_growth=0.10,
   effect_type="shield_maxhp_pct", effect_value=0.08, effect_duration_s=6, effect_growth=0.005,
   effect2_type="reflect_add", effect2_value=0.30, effect2_growth=0.02,
   desc="获得最大生命×（效果值）的护盾，持续6秒。护盾存在期间：反伤比例额外+（效果2）；每受到一次近战/接触攻击，对该攻击者反震造成攻击×系数伤害（全局内置间隔0.8秒，不暴击）。基础技能。")
sk(skill_id="SK_GANG_QUAKE", gongfa_id="GF_GANG", name="震岳", slot_type="active", tier="normal", is_basic="false",
   shape="circle", anchor="self", radius_px=170, max_targets=99, hits=1, damage_coef=2.2, cd_s=6.0,
   effect_type="knockback_px", effect_value=120,
   desc="以自身为中心震地，对周身敌人造成伤害并击退（效果值）像素；首领不被击退。")
sk(skill_id="SK_GANG_GALE", gongfa_id="GF_GANG", name="罡风护身", slot_type="active", tier="normal", is_basic="false",
   shape="aura", anchor="self", radius_px=130, max_targets=99, hits=8, damage_coef=0.55, cd_s=10.0,
   duration_s=4.0, tick_interval_s=0.5, effect_type="dmg_reduce_pct", effect_value=0.15, effect_duration_s=4, effect_growth=0.01,
   desc="4秒罡风环绕，每0.5秒伤害周身敌人，期间受到伤害降低（效果值）。")
sk(skill_id="SK_GANG_VAJRA", gongfa_id="GF_GANG", name="金刚不坏", slot_type="active", tier="ultimate", is_basic="false",
   shape="self_buff", anchor="self", radius_px=200, max_targets=99, hits=1, damage_coef=6.0, cd_s=15.0, duration_s=8.0,
   effect_type="shield_maxhp_pct", effect_value=0.20, effect_duration_s=8, effect_growth=0.01,
   effect2_type="burst_absorb_pct", effect2_value=1.5, effect2_growth=0.05,
   desc="获得最大生命×（效果值）护盾8秒；护盾破碎或结束时以自身为中心半径200爆发，伤害=攻击×系数+已吸收量×（效果2）。")
sk(skill_id="SK_GANG_PASSIVE", gongfa_id="GF_GANG", name="玄罡护体", slot_type="passive", tier="passive", is_basic="false",
   shape="none", anchor="none", max_targets=0, hits=0, coef_growth=0, cd_reduce=0,
   effect_type="hp_pct", effect_value=0.10, effect_growth=0.02,
   effect2_type="reflect_add", effect2_value=0.25, effect2_growth=0.02, default_auto="",
   desc="被动：最大生命提高（效果值）；受到近战/接触伤害时反弹（效果2）比例的伤害。")

SKILL_FIELDS = ["skill_id", "gongfa_id", "name", "slot_type", "tier", "is_basic", "shape", "anchor", "range_px", "width_px",
                "height_px", "radius_px", "max_targets", "hits", "damage_coef", "cd_s", "duration_s", "tick_interval_s",
                "chain_count", "chain_radius_px", "chain_decay", "effect_type", "effect_value", "effect_duration_s",
                "effect2_type", "effect2_value", "coef_growth", "cd_reduce", "effect_growth", "effect2_growth",
                "upgrade_cost_mult", "book_id", "default_auto", "desc"]
COST_MULT = dict(basic=1.0, normal=1.3, ultimate=1.8, passive=1.5)
UPGRADE_BASE = [60, 120, 200, 320, 480, 700, 1000, 1400, 1900]  # 升到 lv2..lv10 的灵石
for s in S:
    s["upgrade_cost_mult"] = COST_MULT[s["tier"]]
    s["book_id"] = s["skill_id"].replace("SK_", "BK_")
write("skills.csv", SKILL_FIELDS, S)

lv_rows = []
for s in S:
    cum = 0
    for lv in range(1, 11):
        coef = s["damage_coef"] * (1 + s["coef_growth"] * (lv - 1))
        cd = s["cd_s"] * (1 - s["cd_reduce"] * (lv - 1))
        ev = s["effect_value"] + s["effect_growth"] * (lv - 1)
        e2 = s["effect2_value"] + s["effect2_growth"] * (lv - 1)
        chain = s["chain_count"] + (lv // 5 if s["shape"] == "chain" else 0)
        cost = round(UPGRADE_BASE[lv - 1] * s["upgrade_cost_mult"] / 10) * 10 if lv < 10 else 0
        lv_rows.append(dict(skill_id=s["skill_id"], level=lv, damage_coef=rnd(coef), cd_s=rnd(cd, 2),
                            effect_value=rnd(ev), effect2_value=rnd(e2), chain_count=chain,
                            upgrade_cost_lingshi=cost, cum_cost_lingshi=cum))
        cum += cost
write("skill_levels.csv", ["skill_id", "level", "damage_coef", "cd_s", "effect_value", "effect2_value", "chain_count",
                           "upgrade_cost_lingshi", "cum_cost_lingshi"], lv_rows)

# ---------------------------------------------------------------- skill books
BOOK_SOURCE = {
    "BK_SWORD_FLYING": "新手引导赠送；青竹山首领概率掉落（重复书可分解残页）",
    "BK_THUNDER_STRIKE": "新手引导赠送；雷泽谷首领概率掉落",
    "BK_GANG_GUARD": "新手引导赠送；玄岩洞首领概率掉落",
    "BK_SWORD_COMBO": "青竹山1-2首通保底；青竹山首领概率掉落",
    "BK_SWORD_PASSIVE": "青竹山1-3首通保底；青竹山首领概率掉落",
    "BK_SWORD_PIERCE": "青竹山1-4首通保底；青竹山首领概率掉落",
    "BK_SWORD_EXECUTE": "青竹山1-5首通保底；青竹山首领概率掉落；离线概率；残页兑换",
    "BK_THUNDER_CLOUD": "雷泽谷2-2首通保底；雷泽谷首领概率掉落",
    "BK_THUNDER_PASSIVE": "雷泽谷2-3首通保底；雷泽谷首领概率掉落",
    "BK_THUNDER_PALM": "雷泽谷2-4首通保底；雷泽谷首领概率掉落",
    "BK_THUNDER_NINE": "雷泽谷2-5首通保底；雷泽谷首领概率掉落；离线概率；残页兑换",
    "BK_GANG_QUAKE": "玄岩洞3-2首通保底；玄岩洞首领概率掉落",
    "BK_GANG_PASSIVE": "玄岩洞3-3首通保底；玄岩洞首领概率掉落",
    "BK_GANG_GALE": "玄岩洞3-4首通保底；玄岩洞首领概率掉落",
    "BK_GANG_VAJRA": "玄岩洞3-5首通保底；玄岩洞首领概率掉落；离线概率；残页兑换",
}
GF_MAP = {"GF_SWORD": "MAP_QINGZHU", "GF_THUNDER": "MAP_LEIZE", "GF_GANG": "MAP_XUANYAN"}
books = []
for s in S:
    books.append(dict(book_id=s["book_id"], skill_id=s["skill_id"], name="《%s》" % s["name"], gongfa_id=s["gongfa_id"],
                      region_map_id=GF_MAP[s["gongfa_id"]], rarity={"basic": "common", "normal": "rare", "passive": "rare", "ultimate": "epic"}[s["tier"]],
                      decompose_pages=1, exchange_pages=10, source_desc=BOOK_SOURCE[s["book_id"]]))
write("skill_books.csv", ["book_id", "skill_id", "name", "gongfa_id", "region_map_id", "rarity", "decompose_pages",
                          "exchange_pages", "source_desc"], books)

# ---------------------------------------------------------------- maps
maps = [
    dict(map_id="MAP_QINGZHU", name="青竹山", order=1, realm_required="RL_LIANQI", gear_tier=1, book_gongfa_id="GF_SWORD",
         boss_id="BOSS_ZHUMEI", breakthrough_mat_id="MAT_BT_QINGZHU", normal_enemy_ids="EN_BAMBOO_IMP|EN_MOUNTAIN_APE",
         desc="基础教学与配装入门；技能书方向：飞剑诀"),
    dict(map_id="MAP_LEIZE", name="雷泽谷", order=2, realm_required="RL_ZHUJI", gear_tier=2, book_gongfa_id="GF_THUNDER",
         boss_id="BOSS_KUINIU", breakthrough_mat_id="MAT_BT_LEIZE", normal_enemy_ids="EN_MARSH_WISP|EN_THUNDER_TOAD",
         desc="群体清怪与技能组合；技能书方向：御雷诀"),
    dict(map_id="MAP_XUANYAN", name="玄岩洞", order=3, realm_required="RL_JINDAN", gear_tier=3, book_gongfa_id="GF_GANG",
         boss_id="BOSS_YANMO", breakthrough_mat_id="", normal_enemy_ids="EN_CAVE_BAT|EN_ROCK_GOLEM",
         desc="生存、闪避与首领输出；技能书方向：玄罡诀"),
]
write("maps.csv", ["map_id", "name", "order", "realm_required", "gear_tier", "book_gongfa_id", "boss_id",
                   "breakthrough_mat_id", "normal_enemy_ids", "desc"], maps)

# ---------------------------------------------------------------- enemies（数值为“该地图第5关基准=1.0”，关卡倍率另乘）
enemies = [
    dict(enemy_id="EN_BAMBOO_IMP", name="竹灵", kind="normal", map_id="MAP_QINGZHU", hp=300, atk=10, def_=2, move_speed=90,
         attack_interval_s=1.2, attack_range_px=60, behavior="melee_chase", behavior_param="", lingshi=4, xiuwei=3,
         desc="基础近战小怪，直线靠近后挥砍"),
    dict(enemy_id="EN_MOUNTAIN_APE", name="山魈", kind="normal", map_id="MAP_QINGZHU", hp=520, atk=16, def_=4, move_speed=140,
         attack_interval_s=1.5, attack_range_px=70, behavior="charge", behavior_param="dash_trigger_px=280;dash_px=260;dash_coef=1.5",
         lingshi=7, xiuwei=5, desc="距离280像素内蓄力0.5秒后冲撞，冲撞伤害1.5倍"),
    dict(enemy_id="EN_MARSH_WISP", name="泽灵", kind="normal", map_id="MAP_LEIZE", hp=860, atk=26, def_=6, move_speed=120,
         attack_interval_s=1.0, attack_range_px=50, behavior="swarm", behavior_param="group_spacing_px=40",
         lingshi=9, xiuwei=7, desc="成群贴身的鬼火，彼此间距小，易被连锁/范围技能成片清除"),
    dict(enemy_id="EN_THUNDER_TOAD", name="雷蟾", kind="normal", map_id="MAP_LEIZE", hp=1560, atk=40, def_=10, move_speed=60,
         attack_interval_s=2.0, attack_range_px=380, behavior="ranged", behavior_param="keep_distance_px=300;projectile_speed=350",
         lingshi=15, xiuwei=11, desc="远程吐雷球，保持300像素距离，逼迫玩家推进或用远程技能"),
    dict(enemy_id="EN_CAVE_BAT", name="洞蝠", kind="normal", map_id="MAP_XUANYAN", hp=3000, atk=60, def_=12, move_speed=180,
         attack_interval_s=1.0, attack_range_px=60, behavior="hit_and_run", behavior_param="retreat_px=200;retreat_after_hits=2",
         lingshi=20, xiuwei=16, desc="高速飞行，咬两口后后撤再扑，单体技能易落空"),
    dict(enemy_id="EN_ROCK_GOLEM", name="岩傀", kind="normal", map_id="MAP_XUANYAN", hp=8000, atk=95, def_=35, move_speed=50,
         attack_interval_s=2.2, attack_range_px=90, behavior="tank", behavior_param="super_armor=true;smash_coef=1.3",
         lingshi=40, xiuwei=30, desc="高防高血，霸体不受击退/眩晕（首领规则同），破甲剑与持续伤害克制"),
    dict(enemy_id="BOSS_ZHUMEI", name="青竹山主·竹魅", kind="boss", map_id="MAP_QINGZHU", hp=7000, atk=24, def_=6, move_speed=100,
         attack_interval_s=1.6, attack_range_px=120, behavior="boss_pattern", behavior_param="attack_ids=BA_ZHUMEI_SLASH|BA_ZHUMEI_THORN|BA_ZHUMEI_LEAF",
         lingshi=120, xiuwei=80, desc="青竹山区域首领：竹刺直线突刺、竹叶旋风"),
    dict(enemy_id="BOSS_KUINIU", name="雷泽谷主·夔牛", kind="boss", map_id="MAP_LEIZE", hp=18000, atk=66, def_=14, move_speed=90,
         attack_interval_s=1.8, attack_range_px=140, behavior="boss_pattern", behavior_param="attack_ids=BA_KUINIU_HORN|BA_KUINIU_STOMP|BA_KUINIU_BOLTS",
         lingshi=300, xiuwei=220, desc="雷泽谷区域首领：雷霆践踏、天雷三连"),
    dict(enemy_id="BOSS_YANMO", name="玄岩洞主·岩魔", kind="boss", map_id="MAP_XUANYAN", hp=55000, atk=240, def_=40, move_speed=80,
         attack_interval_s=2.0, attack_range_px=150, behavior="boss_pattern", behavior_param="attack_ids=BA_YANMO_FIST|BA_YANMO_CHARGE|BA_YANMO_QUAKE|BA_YANMO_SKYFALL",
         lingshi=700, xiuwei=500, desc="玄岩洞区域首领：碎岩冲撞（全屏横向）、地裂、玄岩天坠（第4关起，全场真实伤害，需闪避或护盾），生存与闪避考验"),
]
for e in enemies:
    e["def"] = e.pop("def_")
write("enemies.csv", ["enemy_id", "name", "kind", "map_id", "hp", "atk", "def", "move_speed", "attack_interval_s",
                      "attack_range_px", "behavior", "behavior_param", "lingshi", "xiuwei", "desc"], enemies)

# ---------------------------------------------------------------- boss attacks
TELEGRAPH_DEFAULT_COLOR = "#C8312B"   # 朱砂（美术建议），可选 #FFFFFF 白色
TELEGRAPH_DEFAULT_STYLE = "dashed"     # dashed 虚线 / solid 实线
SKYFALL_PCT, SKYFALL_CD, SKYFALL_FIRST = 0.7, 20.0, 15.0   # 玄岩天坠：最大生命比例真实伤害 / 冷却 / 开战后首次释放
ba = [
    dict(attack_id="BA_ZHUMEI_SLASH", boss_id="BOSS_ZHUMEI", name="竹鞭横扫", is_danger="false", warn_s=0, shape="rect", anchor="facing",
         offset_x=0, width_px=140, height_px=100, radius_px=0, count=1, damage_coef=1.0, cd_s=1.6, min_level_index=1,
         desc="普通近战攻击，无预警"),
    dict(attack_id="BA_ZHUMEI_THORN", boss_id="BOSS_ZHUMEI", name="竹刺突", is_danger="true", warn_s=0.8, shape="rect", anchor="facing",
         offset_x=0, width_px=520, height_px=80, radius_px=0, count=1, damage_coef=3.0, cd_s=8.0, min_level_index=1,
         desc="地面显示前方长条预警0.8秒后竹刺破土，可闪避或走出范围"),
    dict(attack_id="BA_ZHUMEI_LEAF", boss_id="BOSS_ZHUMEI", name="竹叶旋风", is_danger="true", warn_s=0.8, shape="circle", anchor="self",
         offset_x=0, width_px=0, height_px=0, radius_px=220, count=1, damage_coef=2.5, cd_s=12.0, min_level_index=3,
         desc="以自身为中心圆形预警0.8秒后旋风爆发；第3关起出现"),
    dict(attack_id="BA_KUINIU_HORN", boss_id="BOSS_KUINIU", name="角顶", is_danger="false", warn_s=0, shape="rect", anchor="facing",
         offset_x=0, width_px=160, height_px=110, radius_px=0, count=1, damage_coef=1.0, cd_s=1.8, min_level_index=1,
         desc="普通近战攻击，无预警"),
    dict(attack_id="BA_KUINIU_STOMP", boss_id="BOSS_KUINIU", name="雷霆践踏", is_danger="true", warn_s=0.8, shape="circle", anchor="self",
         offset_x=0, width_px=0, height_px=0, radius_px=260, count=1, damage_coef=3.0, cd_s=9.0, min_level_index=1,
         desc="以自身为中心大圆预警0.8秒后践踏"),
    dict(attack_id="BA_KUINIU_BOLTS", boss_id="BOSS_KUINIU", name="天雷三连", is_danger="true", warn_s=0.8, shape="circle", anchor="player",
         offset_x=0, width_px=0, height_px=0, radius_px=90, count=3, damage_coef=1.6, cd_s=12.0, min_level_index=3,
         desc="在玩家当前位置依次标记3个小圆（间隔0.4秒），各自预警0.8秒后落雷；第3关起出现"),
    dict(attack_id="BA_YANMO_FIST", boss_id="BOSS_YANMO", name="岩拳", is_danger="false", warn_s=0, shape="rect", anchor="facing",
         offset_x=0, width_px=170, height_px=120, radius_px=0, count=1, damage_coef=1.0, cd_s=2.0, min_level_index=1,
         desc="普通近战攻击，无预警"),
    dict(attack_id="BA_YANMO_CHARGE", boss_id="BOSS_YANMO", name="碎岩冲撞", is_danger="true", warn_s=0.8, shape="rect", anchor="facing",
         offset_x=0, width_px=900, height_px=120, radius_px=0, count=1, damage_coef=3.5, cd_s=10.0, min_level_index=1,
         desc="横贯战场的长条预警0.8秒后冲撞，只能靠闪避免伤（宽度覆盖可走动区域）"),
    dict(attack_id="BA_YANMO_QUAKE", boss_id="BOSS_YANMO", name="地裂", is_danger="true", warn_s=0.8, shape="circle", anchor="player",
         offset_x=0, width_px=0, height_px=0, radius_px=150, count=2, damage_coef=2.2, cd_s=13.0, min_level_index=3,
         desc="玩家脚下及其前方各一个圆形预警0.8秒后地裂；第3关起出现"),
    dict(attack_id="BA_YANMO_SKYFALL", boss_id="BOSS_YANMO", name="玄岩天坠", is_danger="true", warn_s=0.8, shape="rect", anchor="arena",
         offset_x=0, width_px=1280, height_px=720, radius_px=0, count=1, damage_coef=0, cd_s=SKYFALL_CD, min_level_index=4,
         damage_type="true_maxhp", damage_maxhp_pct=SKYFALL_PCT, first_cast_s=SKYFALL_FIRST,
         desc="岩魔举岩蓄力，全场预警0.8秒后巨岩坠落：造成玩家最大生命×（damage_maxhp_pct）的真实伤害（无视防御与减伤，先扣护盾），走位无法躲开，只能闪避免伤或靠护盾硬扛；第4关起出现"),
]
for a in ba:
    a.setdefault("damage_type", "atk_coef"); a.setdefault("damage_maxhp_pct", 0)
    a.setdefault("first_cast_s", round(a["cd_s"] * (0.5 if a["is_danger"] == "true" else 0.5), 1))
    a["telegraph_color"] = TELEGRAPH_DEFAULT_COLOR if a["is_danger"] == "true" else ""
    a["telegraph_style"] = TELEGRAPH_DEFAULT_STYLE if a["is_danger"] == "true" else ""
write("boss_attacks.csv", ["attack_id", "boss_id", "name", "is_danger", "warn_s", "shape", "anchor", "offset_x", "width_px",
                           "height_px", "radius_px", "count", "damage_type", "damage_coef", "damage_maxhp_pct", "cd_s",
                           "first_cast_s", "min_level_index", "telegraph_color", "telegraph_style", "desc"], ba)

# ---------------------------------------------------------------- equipment
slots = [
    ("SLOT_WEAPON", "武器", 1), ("SLOT_ROBE", "衣袍", 2), ("SLOT_CROWN", "冠", 3),
    ("SLOT_SHOES", "鞋", 4), ("SLOT_RING", "戒指", 5), ("SLOT_ARTIFACT", "法器", 6)]
write("equip_slots.csv", ["slot_id", "name", "order"], [dict(slot_id=a, name=b, order=c) for a, b, c in slots])

qualities = [
    dict(quality_id="Q_WHITE", name="白", order=1, color="#E6E6E6", affix_count=0, base_mult=1.0, decompose_refine=1,
         reroll_refine=0, reroll_lingshi=0, can_reroll="false", auto_decompose_allowed="true", beam="none"),
    dict(quality_id="Q_GREEN", name="绿", order=2, color="#6BD66B", affix_count=1, base_mult=1.1, decompose_refine=2,
         reroll_refine=4, reroll_lingshi=100, can_reroll="true", auto_decompose_allowed="true", beam="none"),
    dict(quality_id="Q_BLUE", name="蓝", order=3, color="#4FA3FF", affix_count=2, base_mult=1.25, decompose_refine=4,
         reroll_refine=8, reroll_lingshi=300, can_reroll="true", auto_decompose_allowed="true", beam="short"),
    dict(quality_id="Q_PURPLE", name="紫", order=4, color="#B36BFF", affix_count=3, base_mult=1.4, decompose_refine=8,
         reroll_refine=16, reroll_lingshi=800, can_reroll="true", auto_decompose_allowed="true", beam="tall"),
    dict(quality_id="Q_ORANGE", name="橙", order=5, color="#FF9A2E", affix_count=4, base_mult=1.6, decompose_refine=25,
         reroll_refine=30, reroll_lingshi=2000, can_reroll="true", auto_decompose_allowed="false", beam="tall_gold"),
]
write("qualities.csv", ["quality_id", "name", "order", "color", "affix_count", "base_mult", "decompose_refine",
                        "reroll_refine", "reroll_lingshi", "can_reroll", "auto_decompose_allowed", "beam"], qualities)

tiers = [dict(gear_tier=1, map_id="MAP_QINGZHU", flat_mult=1.0, decompose_mult=1, reroll_lingshi_mult=1, desc="青竹山装备"),
         dict(gear_tier=2, map_id="MAP_LEIZE", flat_mult=2.4, decompose_mult=2, reroll_lingshi_mult=2, desc="雷泽谷装备"),
         dict(gear_tier=3, map_id="MAP_XUANYAN", flat_mult=5.5, decompose_mult=3, reroll_lingshi_mult=4, desc="玄岩洞装备")]
write("gear_tiers.csv", ["gear_tier", "map_id", "flat_mult", "decompose_mult", "reroll_lingshi_mult", "desc"], tiers)

# 基础属性（tier1）
SLOT_BASE = {
    "SLOT_WEAPON": dict(atk=8), "SLOT_ROBE": dict(hp=60, def_=4), "SLOT_CROWN": dict(hp=40, def_=2),
    "SLOT_SHOES": dict(hp=20, def_=3, move_speed=10), "SLOT_RING": dict(atk=4, crit_rate=0.02), "SLOT_ARTIFACT": dict(atk=5, hp=20)}
NAMES = {
    "SLOT_WEAPON": ["青竹剑", "雷纹剑", "玄铁剑"], "SLOT_ROBE": ["竹叶袍", "雷云袍", "玄岩甲衣"],
    "SLOT_CROWN": ["竹簪冠", "紫电冠", "玄石冠"], "SLOT_SHOES": ["芒鞋", "踏雷靴", "镇岳履"],
    "SLOT_RING": ["竹节戒", "雷蟾戒", "玄晶戒"], "SLOT_ARTIFACT": ["竹笛", "雷珠", "岩心印"]}
bases = []
for t in tiers:
    for sid, _, _ in slots:
        b = SLOT_BASE[sid]
        m = t["flat_mult"]
        bases.append(dict(base_id="EQB_%s_T%d" % (sid[5:], t["gear_tier"]), slot_id=sid, gear_tier=t["gear_tier"],
                          name=NAMES[sid][t["gear_tier"] - 1], atk=rnd(b.get("atk", 0) * m), hp=rnd(b.get("hp", 0) * m),
                          def_=rnd(b.get("def_", 0) * m), crit_rate=b.get("crit_rate", 0), move_speed=b.get("move_speed", 0),
                          is_core="false", orange_effect_id="", gongfa_id="", desc="普通装备底子，品质决定基础属性倍率与词条数"))
for bid, sid, nm, eff, gf in [("EQB_CORE_SWORD", "SLOT_WEAPON", "青冥剑", "OE_SWORD_CORE", "GF_SWORD"),
                               ("EQB_CORE_THUNDER", "SLOT_ARTIFACT", "雷音鼓", "OE_THUNDER_CORE", "GF_THUNDER"),
                               ("EQB_CORE_GANG", "SLOT_ROBE", "玄罡宝衣", "OE_GANG_CORE", "GF_GANG")]:
    b = SLOT_BASE[sid]; m = 5.5
    bases.append(dict(base_id=bid, slot_id=sid, gear_tier=3, name=nm, atk=rnd(b.get("atk", 0) * m), hp=rnd(b.get("hp", 0) * m),
                      def_=rnd(b.get("def_", 0) * m), crit_rate=b.get("crit_rate", 0), move_speed=b.get("move_speed", 0),
                      is_core="true", orange_effect_id=eff, gongfa_id=gf, desc="流派核心橙装，只以橙色品质生成"))
for b in bases:
    b["def"] = b.pop("def_")
write("equip_bases.csv", ["base_id", "slot_id", "gear_tier", "name", "atk", "hp", "def", "crit_rate", "move_speed",
                          "is_core", "orange_effect_id", "gongfa_id", "desc"], bases)

ALL = "SLOT_WEAPON|SLOT_ROBE|SLOT_CROWN|SLOT_SHOES|SLOT_RING|SLOT_ARTIFACT"
affixes = [
    # id, name, stat, value_type, scale_by_tier, allowed_slots, weight, min_quality, g, b, p, o
    ("AF_ATK_FLAT", "攻击", "atk", "flat", "true", "SLOT_WEAPON|SLOT_RING|SLOT_ARTIFACT|SLOT_CROWN", 100, "Q_GREEN", (2, 4), (3, 6), (5, 8), (7, 10)),
    ("AF_ATK_PCT", "攻击%", "atk_pct", "pct", "false", ALL, 80, "Q_GREEN", (0.02, 0.04), (0.03, 0.06), (0.05, 0.08), (0.07, 0.10)),
    ("AF_HP_FLAT", "生命", "hp", "flat", "true", ALL, 100, "Q_GREEN", (20, 40), (30, 60), (50, 80), (70, 100)),
    ("AF_HP_PCT", "生命%", "hp_pct", "pct", "false", ALL, 80, "Q_GREEN", (0.03, 0.05), (0.04, 0.07), (0.06, 0.09), (0.08, 0.12)),
    ("AF_DEF_FLAT", "防御", "def", "flat", "true", "SLOT_ROBE|SLOT_CROWN|SLOT_SHOES|SLOT_ARTIFACT", 90, "Q_GREEN", (2, 3), (3, 5), (4, 6), (6, 8)),
    ("AF_CRIT_RATE", "暴击率", "crit_rate", "pct", "false", "SLOT_WEAPON|SLOT_RING|SLOT_CROWN", 60, "Q_GREEN", (0.01, 0.02), (0.02, 0.03), (0.03, 0.04), (0.04, 0.05)),
    ("AF_CRIT_DMG", "暴击伤害", "crit_dmg", "pct", "false", "SLOT_WEAPON|SLOT_RING", 60, "Q_GREEN", (0.05, 0.10), (0.08, 0.14), (0.12, 0.18), (0.16, 0.24)),
    ("AF_ATK_SPEED", "攻速", "atk_speed", "pct", "false", "SLOT_WEAPON|SLOT_SHOES|SLOT_RING", 60, "Q_GREEN", (0.03, 0.05), (0.04, 0.07), (0.06, 0.09), (0.09, 0.12)),
    ("AF_EXTRA_SWORD", "追加飞剑", "extra_sword_chance", "pct", "false", "SLOT_WEAPON|SLOT_ARTIFACT", 40, "Q_BLUE", (0, 0), (0.04, 0.06), (0.06, 0.09), (0.09, 0.12)),
    ("AF_SWORD_DMG", "飞剑诀伤害", "sword_dmg_pct", "pct", "false", ALL, 50, "Q_GREEN", (0.04, 0.06), (0.06, 0.09), (0.09, 0.12), (0.12, 0.16)),
    ("AF_THUNDER_DMG", "雷伤", "thunder_dmg_pct", "pct", "false", ALL, 50, "Q_GREEN", (0.04, 0.06), (0.06, 0.09), (0.09, 0.12), (0.12, 0.16)),
    ("AF_CHAIN_COUNT", "连锁目标", "chain_count", "int", "false", "SLOT_ARTIFACT|SLOT_RING", 25, "Q_PURPLE", (0, 0), (0, 0), (1, 1), (1, 2)),
    ("AF_CDR", "冷却缩减", "cdr", "pct", "false", "SLOT_CROWN|SLOT_ARTIFACT|SLOT_RING", 50, "Q_GREEN", (0.02, 0.03), (0.03, 0.05), (0.04, 0.06), (0.06, 0.08)),
    ("AF_SHIELD_PCT", "护盾强度", "shield_pct", "pct", "false", "SLOT_ROBE|SLOT_CROWN|SLOT_ARTIFACT", 50, "Q_GREEN", (0.04, 0.06), (0.06, 0.09), (0.09, 0.12), (0.12, 0.16)),
    ("AF_REFLECT_PCT", "反伤", "reflect_pct", "pct", "false", "SLOT_ROBE|SLOT_SHOES", 50, "Q_GREEN", (0.03, 0.05), (0.04, 0.07), (0.06, 0.09), (0.09, 0.12)),
    ("AF_LINGSHI_GAIN", "灵石获取", "lingshi_gain_pct", "pct", "false", "SLOT_RING|SLOT_ARTIFACT", 30, "Q_GREEN", (0.03, 0.05), (0.04, 0.07), (0.06, 0.09), (0.09, 0.12)),
]
af_rows = []
for a in affixes:
    r = dict(affix_id=a[0], name=a[1], stat=a[2], value_type=a[3], scale_by_tier=a[4], allowed_slots=a[5], weight=a[6], min_quality=a[7])
    for q, rng in zip(["green", "blue", "purple", "orange"], a[8:]):
        r[q + "_min"], r[q + "_max"] = rng
    af_rows.append(r)
write("affixes.csv", ["affix_id", "name", "stat", "value_type", "scale_by_tier", "allowed_slots", "weight", "min_quality",
                      "green_min", "green_max", "blue_min", "blue_max", "purple_min", "purple_max", "orange_min", "orange_max"], af_rows)

oe = [
    dict(orange_effect_id="OE_SWORD_CORE", base_id="EQB_CORE_SWORD", gongfa_id="GF_SWORD", name="青冥万剑",
         param1_key="extra_sword_chance", param1=0.30, param2_key="extra_sword_coef", param2=0.8, param3_key="boss_dmg_pct", param3=0.15,
         internal_cd_s=0, desc="飞剑诀主动技能每次命中有30%概率追加1把飞剑（攻击×0.8），暴击时必定追加；对首领伤害+15%"),
    dict(orange_effect_id="OE_THUNDER_CORE", base_id="EQB_CORE_THUNDER", gongfa_id="GF_THUNDER", name="雷音震野",
         param1_key="chain_count_add", param1=2, param2_key="kill_cd_refund_s", param2=0.5, param3_key="", param3="",
         internal_cd_s=0, desc="御雷诀技能连锁目标+2；御雷诀技能每击杀1个敌人，所有御雷诀主动技能剩余冷却-0.5秒"),
    dict(orange_effect_id="OE_GANG_CORE", base_id="EQB_CORE_GANG", gongfa_id="GF_GANG", name="玄罡镇岳",
         param1_key="reflect_add_with_shield", param1=0.25, param2_key="shield_break_burst_pct", param2=0.8, param3_key="burst_radius_px", param3=220,
         internal_cd_s=5, desc="护盾存在时反伤+25%；护盾被击破时以自身为中心半径220爆发，伤害=护盾上限×80%（内置冷却5秒）"),
]
write("orange_effects.csv", ["orange_effect_id", "base_id", "gongfa_id", "name", "param1_key", "param1", "param2_key", "param2",
                             "param3_key", "param3", "internal_cd_s", "desc"], oe)

# 品质权重组
qw = [
    ("QW_NORMAL_T1", 70, 25, 5, 0, 0, "青竹山普通怪/离线"),
    ("QW_NORMAL_T2", 55, 32, 11, 2, 0, "雷泽谷普通怪/离线"),
    ("QW_NORMAL_T3", 45, 35, 15, 5, 0, "玄岩洞普通怪/离线"),
    ("QW_BOSS_T1", 20, 45, 30, 5, 0, "青竹山首领"),
    ("QW_BOSS_T2", 10, 40, 38, 11.5, 0.5, "雷泽谷首领"),
    ("QW_BOSS_T3", 5, 30, 43, 20.5, 1.5, "玄岩洞首领"),
    ("QW_FIRST_BLUE", 0, 0, 80, 20, 0, "首通保底：蓝装以上（计划已定）"),
    ("QW_FIRST_PURPLE", 0, 0, 0, 100, 0, "地图终关首通：紫装"),
]
write("quality_weights.csv", ["weight_set_id", "Q_WHITE", "Q_GREEN", "Q_BLUE", "Q_PURPLE", "Q_ORANGE", "desc"],
      [dict(weight_set_id=a, Q_WHITE=b, Q_GREEN=c, Q_BLUE=d, Q_PURPLE=e, Q_ORANGE=f, desc=g) for a, b, c, d, e, f, g in qw])

# ---------------------------------------------------------------- levels & waves
LV35_BOSS_HP_MULT = 0.78
LV24_BOSS_HP_MULT, LV25_BOSS_HP_MULT = 0.74, 0.80
LV_ENEMY_MULT = [0.6, 0.68, 0.8, 0.9, 1.0]      # 普通怪 HP/ATK 关卡倍率
LV_BOSS_MULT = [0.4, 0.52, 0.67, 0.84, 1.0]       # 首领 HP/ATK 关卡倍率
BOSS_HP_OVERRIDE = {("MAP_LEIZE", 4): LV24_BOSS_HP_MULT, ("MAP_LEIZE", 5): LV25_BOSS_HP_MULT,   # v3：2-5首领下调（纯玄罡诀约45-50秒），2-4同步保持递增
                    ("MAP_XUANYAN", 4): 0.72, ("MAP_XUANYAN", 5): LV35_BOSS_HP_MULT}   # v2：终关首领血量下调（纯玄罡诀约45-50秒）；3-4同步下调保持逐关递增
LV_NAMES = {
    "MAP_QINGZHU": ["竹径初行", "听涛竹海", "山魈岭", "断竹崖", "竹魅幽谷"],
    "MAP_LEIZE": ["泽畔雷鸣", "鬼火沼", "雷蟾坡", "裂电滩", "夔牛雷台"],
    "MAP_XUANYAN": ["洞口回风", "蝠影长廊", "岩傀石阵", "地脉深渊", "岩魔玄窟"]}
# (A, B) counts per wave；A=第一种普通怪，B=第二种
WAVES = {
    "MAP_QINGZHU": [[(4, 0), (5, 0), (4, 1), (5, 1)],
                    [(5, 0), (4, 2), (6, 1), (5, 2)],
                    [(4, 2), (5, 2), (2, 4), (5, 3)],
                    [(6, 2), (4, 4), (7, 2), (6, 3)],
                    [(6, 3), (5, 4), (8, 2), (7, 4)]],
    "MAP_LEIZE":   [[(6, 0), (6, 1), (7, 1), (8, 1)],
                    [(8, 0), (7, 2), (9, 1), (8, 2)],
                    [(6, 2), (5, 3), (8, 2), (7, 3)],
                    [(9, 2), (7, 3), (10, 2), (9, 3)],
                    [(10, 2), (8, 3), (11, 2), (10, 4)]],
    "MAP_XUANYAN": [[(4, 0), (4, 1), (5, 1), (4, 2)],
                    [(6, 0), (5, 1), (6, 1), (5, 2)],
                    [(3, 2), (2, 3), (4, 2), (3, 3)],
                    [(5, 2), (4, 3), (6, 2), (5, 3)],
                    [(5, 3), (4, 4), (6, 3), (6, 4)]],
}
# 首通奖励（每关）：书 / 装备品质组 / 灵石 / 修为
FIRST_BOOK = {("MAP_QINGZHU", 2): "BK_SWORD_COMBO", ("MAP_QINGZHU", 3): "BK_SWORD_PASSIVE", ("MAP_QINGZHU", 4): "BK_SWORD_PIERCE",
              ("MAP_LEIZE", 2): "BK_THUNDER_CLOUD", ("MAP_LEIZE", 3): "BK_THUNDER_PASSIVE", ("MAP_LEIZE", 4): "BK_THUNDER_PALM",
              ("MAP_XUANYAN", 2): "BK_GANG_QUAKE", ("MAP_XUANYAN", 3): "BK_GANG_PASSIVE", ("MAP_XUANYAN", 4): "BK_GANG_GALE",
              # v2：终极技能书改为每张地图第5关首通保底
              ("MAP_QINGZHU", 5): "BK_SWORD_EXECUTE", ("MAP_LEIZE", 5): "BK_THUNDER_NINE", ("MAP_XUANYAN", 5): "BK_GANG_VAJRA"}
FIRST_LINGSHI = {1: [150, 200, 250, 300, 400], 2: [500, 600, 700, 800, 1000], 3: [1500, 1800, 2100, 2400, 3000]}
FIRST_XIUWEI = {1: [100, 150, 200, 250, 300], 2: [400, 500, 600, 700, 900], 3: [1000, 1200, 1400, 1600, 2000]}
OFFLINE_EFF = 0.5          # 离线效率=在线挂机的50%
FARM_RUN_S = 130           # 估算：已通关关卡挂机一轮耗时（秒），用于离线表

levels, waves, fcr, offline, droptables = [], [], [], [], []
gidx = 0
for m in maps:
    mid = m["map_id"]; tier = m["gear_tier"]
    ea, eb = m["normal_enemy_ids"].split("|")
    E = {e["enemy_id"]: e for e in enemies}
    for i in range(1, 6):
        gidx += 1
        lid = "LV_%d_%d" % (tier, i)
        nd, bd = "DT_NORMAL_T%d" % tier, "DT_BOSS_T%d" % tier
        levels.append(dict(level_id=lid, map_id=mid, index=i, global_index=gidx, name=LV_NAMES[mid][i - 1],
                           enemy_hp_mult=LV_ENEMY_MULT[i - 1], enemy_atk_mult=LV_ENEMY_MULT[i - 1],
                           boss_id=m["boss_id"], boss_hp_mult=BOSS_HP_OVERRIDE.get((mid, i), LV_BOSS_MULT[i - 1]), boss_atk_mult=LV_BOSS_MULT[i - 1],
                           boss_time_limit_s=60, wave_count=4, unlock_level_id=("" if gidx == 1 else levels[-1]["level_id"]),
                           unlock_realm_id=m["realm_required"] if i == 1 else "", normal_drop_table_id=nd, boss_drop_table_id=bd,
                           first_clear_reward_id="FC_" + lid, offline_reward_id="OFF_" + lid,
                           desc="%s第%d关" % (m["name"], i)))
        run_ls = run_xw = 0; kills = 0
        for w, (na, nb) in enumerate(WAVES[mid][i - 1], 1):
            for eid, n in ((ea, na), (eb, nb)):
                if n:
                    waves.append(dict(level_id=lid, wave_index=w, enemy_id=eid, count=n, spawn_delay_s=0 if eid == ea else 1.5,
                                      spawn_side="right", formation=("cluster" if E[eid]["behavior"] in ("swarm", "melee_chase") else "spread")))
                    run_ls += E[eid]["lingshi"] * n * LV_ENEMY_MULT[i - 1]
                    run_xw += E[eid]["xiuwei"] * n * LV_ENEMY_MULT[i - 1]
                    kills += n
        boss = E[m["boss_id"]]
        run_ls += boss["lingshi"] * LV_BOSS_MULT[i - 1]; run_xw += boss["xiuwei"] * LV_BOSS_MULT[i - 1]
        # 首通奖励
        fid = "FC_" + lid
        fcr.append(dict(reward_id=fid, level_id=lid, seq=1, reward_type="lingshi", ref_id="CUR_LINGSHI", count=FIRST_LINGSHI[tier][i - 1], weight_set_id="", desc="首通灵石"))
        fcr.append(dict(reward_id=fid, level_id=lid, seq=2, reward_type="xiuwei", ref_id="CUR_XIUWEI", count=FIRST_XIUWEI[tier][i - 1], weight_set_id="", desc="首通修为"))
        fcr.append(dict(reward_id=fid, level_id=lid, seq=3, reward_type="equipment", ref_id="TIER_%d" % tier, count=1,
                        weight_set_id="QW_FIRST_PURPLE" if i == 5 else "QW_FIRST_BLUE", desc="首通保底装备：蓝装以上（终关紫装），随机槽位；1-1固定为武器"))
        if (mid, i) in FIRST_BOOK:
            fcr.append(dict(reward_id=fid, level_id=lid, seq=4, reward_type="book", ref_id=FIRST_BOOK[(mid, i)], count=1, weight_set_id="", desc="首通保底技能书"))
        if i == 5 and m["breakthrough_mat_id"]:
            fcr.append(dict(reward_id=fid, level_id=lid, seq=5, reward_type="material", ref_id=m["breakthrough_mat_id"], count=1, weight_set_id="", desc="区域首领首次击败：突破材料"))
        if gidx == 15:
            for k, b in enumerate(["EQB_CORE_SWORD", "EQB_CORE_THUNDER", "EQB_CORE_GANG"]):
                fcr.append(dict(reward_id=fid, level_id=lid, seq=6 + k, reward_type="orange_choice", ref_id=b, count=1,
                                weight_set_id="", desc="终关首通：三件流派核心橙装三选一（choice_group=1）"))
        # 离线（每分钟）
        per_min = 60.0 / FARM_RUN_S * OFFLINE_EFF
        offline.append(dict(offline_id="OFF_" + lid, level_id=lid, lingshi_per_min=rnd(run_ls * per_min, 1), xiuwei_per_min=rnd(run_xw * per_min, 1),
                            equip_per_min=0.2, weight_set_id="QW_NORMAL_T%d" % tier, refine_per_min=rnd(0.3 * tier, 2),
                            book_chance_per_min=0.004, book_pool_id="BP_T%d" % tier, cap_minutes=480,
                            desc="按最近已通关关卡结算；在线挂机效率的%d%%" % int(OFFLINE_EFF * 100)))
    # 掉落表（每地图：普通怪 / 首领）
    droptables += [
        dict(drop_table_id="DT_NORMAL_T%d" % tier, seq=1, roll="per_kill", entry_type="equipment", ref_id="TIER_%d" % tier, chance=0.04,
             count_min=1, count_max=1, weight_set_id="QW_NORMAL_T%d" % tier, desc="普通怪少量装备"),
        dict(drop_table_id="DT_NORMAL_T%d" % tier, seq=2, roll="per_kill", entry_type="material", ref_id="MAT_REFINE", chance=0.05,
             count_min=1, count_max=tier, weight_set_id="", desc="少量炼器材料（灵石/修为见enemies表）"),
        dict(drop_table_id="DT_BOSS_T%d" % tier, seq=1, roll="per_kill", entry_type="equipment", ref_id="TIER_%d" % tier, chance=1.0,
             count_min=1, count_max=1, weight_set_id="QW_BOSS_T%d" % tier, desc="首领保证掉落装备（计划已定）"),
        dict(drop_table_id="DT_BOSS_T%d" % tier, seq=2, roll="per_kill", entry_type="material", ref_id="MAT_REFINE", chance=0.5,
             count_min=2, count_max=2 + 2 * tier, weight_set_id="", desc="炼器材料"),
        dict(drop_table_id="DT_BOSS_T%d" % tier, seq=3, roll="per_kill", entry_type="book_pool", ref_id="BP_T%d" % tier, chance=0.16,
             count_min=1, count_max=1, weight_set_id="", desc="区域技能书（按书池权重抽1本）"),
    ]
write("levels.csv", ["level_id", "map_id", "index", "global_index", "name", "enemy_hp_mult", "enemy_atk_mult", "boss_id",
                     "boss_hp_mult", "boss_atk_mult", "boss_time_limit_s", "wave_count", "unlock_level_id", "unlock_realm_id",
                     "normal_drop_table_id", "boss_drop_table_id", "first_clear_reward_id", "offline_reward_id", "desc"], levels)
write("waves.csv", ["level_id", "wave_index", "enemy_id", "count", "spawn_delay_s", "spawn_side", "formation"], waves)
write("first_clear_rewards.csv", ["reward_id", "level_id", "seq", "reward_type", "ref_id", "count", "weight_set_id", "desc"], fcr)
write("offline_rewards.csv", ["offline_id", "level_id", "lingshi_per_min", "xiuwei_per_min", "equip_per_min", "weight_set_id",
                              "refine_per_min", "book_chance_per_min", "book_pool_id", "cap_minutes", "desc"], offline)
write("drop_tables.csv", ["drop_table_id", "seq", "roll", "entry_type", "ref_id", "chance", "count_min", "count_max",
                          "weight_set_id", "desc"], droptables)

# 书池：区域5本，终极技能权重高、基础书权重低
bp = []
for tier, gf in ((1, "GF_SWORD"), (2, "GF_THUNDER"), (3, "GF_GANG")):
    for s in S:
        if s["gongfa_id"] == gf:
            w = {"basic": 10, "normal": 20, "passive": 20, "ultimate": 30}[s["tier"]]
            bp.append(dict(book_pool_id="BP_T%d" % tier, book_id=s["book_id"], weight=w))
write("book_pools.csv", ["book_pool_id", "book_id", "weight"], bp)

# ---------------------------------------------------------------- tutorial
# 字段 v3：category=main（首5分钟主线引导，计划六步）/ contextual（情境提示）；trigger_ref_ids=触发涉及的ID；
# time_scale=提示期间战斗时间倍率（0=暂停，1=正常）；time_scale_duration_s=慢放持续的游戏内秒数（0=直到本步完成或面板关闭）；
# max_show_count=未完成时最多出现次数（达到后自动标记完成）
tut = [
    dict(step_id="TUT_01_GET_BOOKS", order=1, name="领书", trigger="首次进入游戏且存档无tutorial记录；战斗暂停",
         ui_target="任务气泡→【领取】按钮", complete_condition="点击领取，背包获得3本基础技能书",
         reward_type="book", reward_ref_ids="BK_SWORD_FLYING|BK_THUNDER_STRIKE|BK_GANG_GUARD", reward_count=1,
         block_input="true", desc="师父赠书：飞剑、雷击、护体"),
    dict(step_id="TUT_02_LEARN", order=2, name="学习", trigger="TUT_01完成",
         ui_target="底部【功法】入口→技能书详情→【学习】按钮（依次3本）", complete_condition="SK_SWORD_FLYING、SK_THUNDER_STRIKE、SK_GANG_GUARD均已学习",
         reward_type="lingshi", reward_ref_ids="CUR_LINGSHI", reward_count=100, block_input="true",
         desc="每本学习成功消耗1本书；高亮下一本未学的书"),
    dict(step_id="TUT_03_EQUIP_SKILL", order=3, name="装配", trigger="TUT_02完成",
         ui_target="功法面板→技能图标拖入/点击主动栏第1-3格", complete_condition="主动栏1-3格分别为飞剑、雷击、护体（顺序不限），第4格保持空",
         reward_type="none", reward_ref_ids="", reward_count=0, block_input="true",
         desc="基础技能默认自动释放；提示第4格将来放新技能"),
    dict(step_id="TUT_04_CAST", order=4, name="释放", trigger="TUT_03完成且关闭养成面板；进入LV_1_1第1波",
         ui_target="技能栏第1格（快捷键1）闪烁+文字提示“按1手动释放飞剑”", complete_condition="玩家手动释放任意技能1次并命中敌人",
         reward_type="lingshi", reward_ref_ids="CUR_LINGSHI", reward_count=100, block_input="false",
         desc="同时提示空格闪避和自动开关；不强制暂停战斗"),
    dict(step_id="TUT_05_GEAR", order=5, name="换装", trigger="LV_1_1第2波清空时固定掉落1件绿色武器（tutorial_drop）",
         ui_target="掉落提示→底部【装备】入口→新武器→属性差异→【装备】按钮", complete_condition="武器槽装备了品质≥绿的武器",
         reward_type="material", reward_ref_ids="MAT_REFINE", reward_count=5, block_input="true",
         desc="展示属性差异绿色上升箭头；顺带提示分解"),
    dict(step_id="TUT_06_BOSS", order=6, name="首领", trigger="LV_1_1第4波清空，首领竹魅登场前",
         ui_target="首领血条+预警区域高亮，提示“红色区域0.8秒后受击，按空格闪避”", complete_condition="击败LV_1_1首领（首通）",
         reward_type="first_clear", reward_ref_ids="FC_LV_1_1", reward_count=1, block_input="false",
         desc="首次出现危险攻击时慢动作0.5倍持续0.8秒（仅本步）；失败可无限重试，不扣资源"),
]
tut.append(dict(step_id="TUT_07_SKYFALL_DODGE", order=7, name="天坠闪避", category="contextual",
    trigger="存档未完成本步，且玄岩天坠（BA_YANMO_SKYFALL）的全场预警第一次出现时（自动/手动模式都会触发；正常流程为3-4首领开战第15秒）",
    trigger_ref_ids="BA_YANMO_SKYFALL|LV_3_4",
    ui_target="屏幕中央大字“按空格闪避！”+空格键图标；底部【闪避】按钮高亮脉冲；全场朱砂虚线预警照常显示；自动模式下追加小字“闪避会切到手动，点自动按钮可恢复”",
    complete_condition="预警结束瞬间玩家处于闪避免伤（0.3秒）内，即成功闪避一次天坠。未闪避被击中则不完成，下一次天坠预警再提示；累计提示3次后自动标记完成",
    reward_type="none", reward_ref_ids="", reward_count=0, block_input="false",
    time_scale=0.3, time_scale_duration_s=0.8, max_show_count=3,
    desc="不暂停，只慢放：预警的0.8秒游戏时间以0.3倍速播放（现实约2.7秒）；只允许闪避/移动等正常输入，不遮罩。成功后飘字“闪避成功”"))
DEFAULTS = {"TUT_01_GET_BOOKS": ("", 0, 0), "TUT_02_LEARN": ("TUT_01_GET_BOOKS", 0, 0), "TUT_03_EQUIP_SKILL": ("TUT_02_LEARN", 0, 0),
            "TUT_04_CAST": ("TUT_03_EQUIP_SKILL|LV_1_1", 1, 0), "TUT_05_GEAR": ("LV_1_1|EQB_WEAPON_T1", 0, 0),
            "TUT_06_BOSS": ("LV_1_1|BOSS_ZHUMEI|BA_ZHUMEI_THORN", 0.5, 0.8)}
for t in tut:
    if t["step_id"] in DEFAULTS:
        ref_, ts, dur = DEFAULTS[t["step_id"]]
        t.update(category="main", trigger_ref_ids=ref_, time_scale=ts, time_scale_duration_s=dur, max_show_count=1)
write("tutorial_steps.csv", ["step_id", "order", "name", "category", "trigger", "trigger_ref_ids", "ui_target", "complete_condition",
                             "reward_type", "reward_ref_ids", "reward_count", "block_input", "time_scale", "time_scale_duration_s",
                             "max_show_count", "desc"], tut)

# 初始装备
write("start_kit.csv", ["entry_type", "ref_id", "quality_id", "count", "desc"], [
    dict(entry_type="equipment", ref_id="EQB_WEAPON_T1", quality_id="Q_WHITE", count=1, desc="开局已装备白色青竹剑"),
    dict(entry_type="equipment", ref_id="EQB_ROBE_T1", quality_id="Q_WHITE", count=1, desc="开局已装备白色竹叶袍"),
    dict(entry_type="tutorial_drop", ref_id="EQB_WEAPON_T1", quality_id="Q_GREEN", count=1, desc="TUT_05：1-1第2波固定掉落绿色武器（词条固定AF_ATK_FLAT=3）"),
])
print("generated ->", OUT)

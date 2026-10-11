# 《重走修仙路》首版配置表说明（v2）

> 适用：Godot 4.7.2 + GDScript 首版（无后端/账号/付费）。依据：《重走修仙路》开发计划（2026-10-11）。
> 计划里已定的规则（4波+首领、首领限时60秒、预警0.8秒、闪避0.3秒/冷却3秒、6槽5品质0-4词条、技能上限10级、离线上限8小时、10残页换书、背包100件等）全部照搬，没有改动。

## 1. 目录与工作流

```
design/
├─ README.md              本文件：每张表、每个字段的含义/单位/取值范围/引用关系
├─ balance.md             数值目标与每关耗时估算依据、三流派差异
├─ CHANGELOG.md           版本变更记录（v2：给前端的表/字段改动清单）
├─ balance_report.csv     balance.py 输出的逐关估算结果（自动生成，勿手改）
├─ data/                  全部配置表（CSV，UTF-8 无 BOM，逗号分隔，首行为英文字段名）
└─ tools/
   ├─ gen_tables.py       首版数值“种子”生成器：输出 data/*.csv
   ├─ common.py           CSV 读取公共函数
   ├─ validate.py         校验：可解析、主键唯一、ID 全局唯一、跨表引用无断链、计划硬性规则、15本书获取途径覆盖
   └─ balance.py          主线时长/DPS/生存估算，输出 balance_report.csv；加 --md 输出 Markdown 表
```

- 运行（在 design/ 目录）：`python3 tools/gen_tables.py && python3 tools/validate.py && python3 tools/balance.py`
- **数据源约定**：首版 CSV 由 gen_tables.py 生成。以后如直接手改 CSV，请不要再跑 gen_tables.py（会覆盖）；或把改动同步回脚本。任何改动后都要跑 validate.py（退出码 1 = 有错）与 balance.py。
- 当前状态（v3，2026-10-11：v2 按用户已确认的9条决策修订；v3 按制作人决定加入自动失败回退规则、天坠闪避引导、下调2-4/2-5首领血量）：25 张表、约 578 行（含表头），validate.py 0 错误。修订明细见 `CHANGELOG.md`。

### 通用约定
- **ID**：全大写英文+下划线，按表加前缀，全局唯一（validate.py 检查）。前缀：`GF_`功法 `SK_`技能 `BK_`技能书 `EN_`普通怪 `BOSS_`首领 `BA_`首领招式 `MAP_`地图 `LV_`关卡 `RL_`境界 `CUR_`货币 `MAT_`材料 `SLOT_`槽位 `Q_`品质 `EQB_`装备底子 `AF_`词条 `OE_`橙装特效 `QW_`品质权重组 `DT_`掉落表 `BP_`书池 `FC_`首通奖励 `OFF_`离线收益 `TUT_`引导步骤。`TIER_n` 是“第 n 档装备随机池”的伪 ID，对应 gear_tiers.gear_tier=n。
- 中文只出现在 `name` / `desc` / `role` / `build_dir` / `source_desc` / `trigger` / `ui_target` / `complete_condition` 等说明字段。
- 布尔值写 `true` / `false`（小写字符串）。多值字段用 `|` 分隔；键值参数用 `k=v;k=v`。
- 单位：时间=秒（字段名带 `_s`），距离/尺寸=像素（`_px`，以 1280×720 设计分辨率为准），比例=0~1 小数（0.3=30%），倍率=直接相乘的系数。
- “攻击×系数”：伤害 = 攻击力 × damage_coef × (1+对应增伤) × 暴击期望 × 目标减伤。
- **伤害/减伤公式**（constants.DEF_CONST=100）：受到伤害 = 原始伤害 × (1 − DEF/(DEF+100))。玩家与怪物同一公式。
- 转 Godot Resource 建议：每张表一个 `Resource` 子类，主键做 Dictionary 索引；`skill_levels` 按 (skill_id, level) 嵌到 SkillResource 的数组里；`waves`/`first_clear_rewards`/`drop_tables`/`book_pools` 按父 ID 分组成数组。

## 2. 引用关系总览

```
gongfa ◄── skills ◄──► skill_books（一一对应，skills.book_id ↔ skill_books.skill_id）
              ▲  └── skill_levels（每技能 1-10 级）
              │
maps ──► realms(realm_required) / enemies(boss_id, normal_enemy_ids) / materials(breakthrough_mat_id) / gongfa(book_gongfa_id)
levels ──► maps / enemies(boss) / drop_tables / first_clear_rewards / offline_rewards / levels(unlock_level_id) / realms(unlock_realm_id)
waves ──► levels / enemies(普通怪)
enemies(boss).behavior_param.attack_ids ──► boss_attacks
first_clear_rewards ──► levels / skill_books / materials / TIER_n / equip_bases(核心橙装) / quality_weights
drop_tables ──► TIER_n / materials / book_pools / quality_weights
offline_rewards ──► levels / quality_weights / book_pools
book_pools ──► skill_books
equip_bases ──► equip_slots / gear_tiers / orange_effects / gongfa
affixes ──► equip_slots(allowed_slots) / qualities(min_quality)
orange_effects ──► equip_bases / gongfa
realms ──► realms(prev) / materials / maps(unlock_map_id)
tutorial_steps ──► skill_books / materials / first_clear_rewards
start_kit ──► equip_bases / qualities
```

## 3. 各表字段

### 3.1 constants.csv 全局常量
| 字段 | 含义 |
|---|---|
| key | 常量名（英文，唯一） |
| value | 值（数字或枚举字符串） |
| unit | 单位说明 |
| desc | 说明；标“计划已定”的不得改 |

关键常量：普攻系数1.0/间隔0.8秒/射程150；基础暴击5%、暴伤1.5倍；闪避0.3秒/冷却3秒/位移160；预警0.8秒；首领限时60秒；DEF_CONST=100；冷却缩减上限40%；暴击率上限75%；反伤上限60%；护体反震全局内置间隔0.8秒（REFLECT_COUNTER_ICD）；危险攻击预警默认朱砂 #C8312B 虚线（TELEGRAPH_DEFAULT_COLOR / TELEGRAPH_DEFAULT_STYLE），可选白色 #FFFFFF（TELEGRAPH_ALT_COLOR）；10残页换1书；背包100；离线上限480分钟；自动存档10秒；自动模式同关连续失败1次即回退（AUTO_FAIL_RETREAT_COUNT，规则见第4节）。

### 3.2 gongfa.csv 功法（3行）
| 字段 | 含义 / 取值 |
|---|---|
| gongfa_id | GF_SWORD 飞剑诀 / GF_THUNDER 御雷诀 / GF_GANG 玄罡诀 |
| name, role, build_dir | 名称、战斗定位、主要搭配方向（照抄计划） |
| book_map_id | → maps；该功法技能书主要产出地图 |
| color | 特效/UI 主色，#RRGGBB |
| desc | 说明 |

### 3.3 skills.csv 技能（15行 = 3功法 ×（4主动+1被动））
| 字段 | 含义 / 单位 / 取值 |
|---|---|
| skill_id | 主键 |
| gongfa_id | → gongfa |
| name | 中文名 |
| slot_type | `active` 占主动栏 / `passive` 占被动槽 |
| tier | `basic` 基础（新手赠书）/ `normal` / `ultimate` 终极 / `passive`；决定升级费用倍率 |
| is_basic | true=新手引导赠送的3本之一 |
| shape | 判定形状：`projectile` 弹道（命中首个敌人）/ `line` 贯穿直线 / `chain` 连锁 / `circle` 圆形 / `rect` 矩形 / `aura` 跟随自身的持续圆形 / `self_buff` 自身增益（护盾）/ `none` 被动 |
| anchor | 释放锚点：`facing` 朝角色面向，原点在角色身前 / `self` 以角色为中心 / `nearest_front` 面向方向射程内最近敌人 / `none` |
| range_px | 射程或最大索敌距离（像素）；projectile/line/rect 为向前长度 |
| width_px | projectile/line 的判定宽度；rect 的长（沿面向） |
| height_px | rect 的纵向高度 |
| radius_px | circle/aura 半径；金刚不坏为爆发半径 |
| max_targets | 单次最多命中目标数（99=不限） |
| hits | 每次释放的段数/跳数（连环剑3、雷云6跳、罡风8跳、九霄9道） |
| damage_coef | 1级每段伤害系数（×攻击力）；剑心通明此列=追加飞剑系数0.8；**护体此列=反震系数**（护盾期间每受一次近战/接触攻击反震 攻击×系数，不暴击，全局0.8秒内置间隔） |
| cd_s | 1级冷却（秒）；被动为0 |
| duration_s | 持续时间（雷云/罡风/护盾/九霄降雷时长） |
| tick_interval_s | 持续伤害间隔 |
| chain_count | 连锁跳数（不含首目标），雷击1级=2，见 skill_levels |
| chain_radius_px | 连锁搜索半径 |
| chain_decay | 每跳伤害衰减比例（0.15=每跳×0.85） |
| effect_type / effect_value / effect_duration_s | 附加效果1：`def_down_pct` 降防比例 / `boss_dmg_bonus` 对首领增伤 / `slow_pct` 减速 / `stun_s` 眩晕秒数（首领减半）/ `knockback_px` 击退距离（首领与岩傀免疫）/ `dmg_reduce_pct` 减伤 / `shield_maxhp_pct` 护盾=最大生命×值 / `crit_rate_add` 暴击率加成 / `thunder_dmg_pct` 雷法增伤 / `hp_pct` 最大生命加成 |
| effect2_type / effect2_value | 附加效果2：`extra_sword_chance` 追加飞剑概率 / `thunder_cdr` 御雷诀冷却缩减 / `burst_absorb_pct` 金刚爆发=吸收量×值 / `reflect_add` 反伤比例 |
| coef_growth | 每升1级伤害系数增加比例（0.10 = 每级+10%基础值，10级=1.9倍） |
| cd_reduce | 每升1级冷却缩短比例（0.02 = 每级-2%基础值，10级=0.82倍） |
| effect_growth / effect2_growth | 每级附加效果数值增量（绝对值） |
| upgrade_cost_mult | 升级费用倍率：basic 1.0 / normal 1.3 / ultimate 1.8 / passive 1.5 |
| book_id | → skill_books，唯一对应技能书 |
| default_auto | 装配到主动栏时默认是否自动释放（计划：基础技能默认自动；首版全部主动默认 true，玩家可逐格关闭）；被动为空 |
| desc | 技能说明，（效果值）（效果2）在 UI 中替换成当前等级数值 |

**三流派技能一览（1级）**
| 功法 | 主动1（基础） | 主动2 | 主动3 | 主动4（终极） | 被动 |
|---|---|---|---|---|---|
| 飞剑诀 单体/首领 | 飞剑 1.6× CD2 弹道 | 连环剑 3×1.0 CD5 | 破甲剑 2.2× 贯穿 降防30% CD8 | 诛仙剑 5.0× 对首领+50% CD15 | 剑心通明 暴击+8%，命中15%追加飞剑 |
| 御雷诀 群体/连锁 | 雷击 1.3× 连锁2跳 CD3 | 雷云 6×0.55 r180 减速 CD9 | 掌心雷 2.2× r220 眩晕0.5s CD6 | 九霄神雷 9×0.9 锁定 CD18 | 引雷之体 雷伤+10% 冷却-5% |
| 玄罡诀 护盾/反伤 | 护体 盾8%生命6s；盾在时反伤+30%、反震0.6× CD8 | 震岳 2.2× r170 击退 CD6 | 罡风护身 8×0.55 r130 减伤15% CD10 | 金刚不坏 盾20%生命，爆发6.0×+吸收×1.5 CD15 | 玄罡护体 生命+10% 反伤25% |

护体（v2）成长：护盾 8%→12.5% 最大生命（+0.5%/级）；护盾期间额外反伤 30%→48%（+2%/级，effect2_value）；反震系数 0.6→1.14（+10%基础/级，damage_coef）；冷却 8→6.56 秒。反伤总比例受 REFLECT_CAP=60% 封顶（与玄罡护体被动 25%→43% 叠加）。

### 3.4 skill_levels.csv 技能等级（150行 = 15技能 × 1-10级）
| 字段 | 含义 |
|---|---|
| skill_id, level | 联合主键；level 1-10 |
| damage_coef | 该级每段伤害系数 = 基础×(1+coef_growth×(lv−1)) |
| cd_s | 该级冷却 = 基础×(1−cd_reduce×(lv−1)) |
| effect_value / effect2_value | 该级附加效果1/2数值 |
| chain_count | 该级连锁跳数（雷击 1-4级2、5-9级3、10级4；其他技能为0） |
| upgrade_cost_lingshi | **从本级升到下一级**的灵石消耗；10级=0 |
| cum_cost_lingshi | 达到本级累计已花灵石 |

升级基础表（升到 2…10 级）：60/120/200/320/480/700/1000/1400/1900，再乘 upgrade_cost_mult，取整到10。单个基础技能满级累计 6180 灵石，终极技能 11130。

### 3.5 skill_books.csv 技能书（15行，一书一技能）
| 字段 | 含义 |
|---|---|
| book_id | 主键 |
| skill_id | → skills（一一对应） |
| name | 书名 |
| gongfa_id | → gongfa（与技能一致） |
| region_map_id | → maps；“所属区域”，残页兑换只能换已解锁区域的书 |
| rarity | common / rare / epic（掉落光柱用） |
| decompose_pages | 分解1本重复书得残页数（1） |
| exchange_pages | 兑换本书所需残页（10，计划已定） |
| source_desc | 获取途径说明（功法面板“未学习”时显示） |

### 3.6 enemies.csv 敌人（6普通 + 3首领）
| 字段 | 含义 / 单位 |
|---|---|
| enemy_id | 主键 |
| name | 名称 |
| kind | normal / boss |
| map_id | → maps |
| hp / atk / def | 基准数值（= 该地图第5关的值），实际值 × levels 的倍率 |
| move_speed | 像素/秒 |
| attack_interval_s | 普通攻击间隔 |
| attack_range_px | 普通攻击距离 |
| behavior | `melee_chase` 近战追击 / `charge` 蓄力冲撞 / `swarm` 成群贴身 / `ranged` 远程保持距离 / `hit_and_run` 游击 / `tank` 霸体肉盾 / `boss_pattern` 首领招式循环 |
| behavior_param | 行为参数 k=v;…；首领的 `attack_ids` → boss_attacks（`|`分隔） |
| lingshi / xiuwei | 击杀给的灵石/修为（基准，× levels.enemy_hp_mult 或 boss_hp_mult） |
| desc | 说明 |

数值：竹灵 300/10/2，山魈 520/16/4（冲撞1.5倍）；泽灵 860/26/6，雷蟾 1560/40/10（远程380）；洞蝠 3000/60/12（游击），岩傀 8000/95/35（霸体）；首领 竹魅 7000/24/6、夔牛 18000/66/14、岩魔 55000/240/40（岩魔第4关起追加“玄岩天坠”）。

### 3.7 boss_attacks.csv 首领招式（10行：竹魅/夔牛 各1普攻+2危险；岩魔 1普攻+3危险）
| 字段 | 含义 |
|---|---|
| attack_id | 主键 |
| boss_id | → enemies（kind=boss） |
| name | 招式名 |
| is_danger | true=危险攻击，必须显示预警区域 |
| warn_s | 预警时长：危险攻击固定 0.8（计划已定），普攻 0 |
| shape / anchor | rect / circle；facing=首领面向 / self=首领为中心 / player=玩家当前位置（预警出现瞬间锁定，之后不跟随）/ arena=覆盖整个战场（走位无法躲开） |
| offset_x | 预警区域相对锚点的水平偏移（像素） |
| width_px / height_px / radius_px | 预警与判定区域尺寸（预警区=判定区） |
| count | 同时/依次出现的区域数（天雷三连3个间隔0.4秒；地裂2个） |
| damage_type | `atk_coef`：伤害=首领攻击（已乘关卡倍率）×damage_coef，吃玩家防御减伤；`true_maxhp`：真实伤害=玩家最大生命×damage_maxhp_pct，无视防御与一切减伤，先扣护盾，不触发反伤/反震 |
| damage_coef | atk_coef 类的伤害系数（true_maxhp 类为0） |
| damage_maxhp_pct | true_maxhp 类的最大生命比例（0~1；其他为0） |
| cd_s | 招式冷却 |
| first_cast_s | 开战后第一次释放的时间（秒，含0.8秒预警前的起手），之后每 cd_s 一次 |
| min_level_index | 该地图第几关起出现（1-5），用于逐关增加难度 |
| telegraph_color | 预警颜色 #RRGGBB；危险攻击默认 `#C8312B` 朱砂（美术建议），可选 `#FFFFFF` 白色；普攻为空（无预警） |
| telegraph_style | 预警描边样式：`dashed` 虚线（默认）/ `solid` 实线；普攻为空 |
| desc | 说明 |

危险攻击：竹刺突（前方 520×80 长条，3.0×）、竹叶旋风（自身 r220，2.5×，第3关起）；雷霆践踏（自身 r260，3.0×）、天雷三连（玩家脚下 3×r90，各1.6×，第3关起）；碎岩冲撞（前方 900×120 全宽，3.5×，只能闪避）、地裂（2×r150，2.2×，第3关起）、**玄岩天坠**（v2 新增，见下）。闪避判定：预警结束瞬间玩家处于闪避免伤（0.3秒）或已离开区域 = 无伤。

**BA_YANMO_SKYFALL 玄岩天坠**（v2，突出玄岩洞生存玩法）：
- 第4关起出现（min_level_index=4）；开战第15秒首次释放，之后每20秒一次（15/35/55秒…）；预警0.8秒，全场（anchor=arena，1280×720）朱砂虚线。
- 伤害=玩家最大生命×70%真实伤害（无视防御/减伤，先扣护盾）。叠加普攻与其他招式的伤害，无护盾、不闪避时第一次天坠就基本致死（模型：纯飞剑/纯御雷自动挂机在15秒阵亡）。
- 应对：① 预警内按空格闪避（0.3秒免伤），完全无伤；② 护盾硬扛：护体（8%~12.5%）+金刚不坏（20%~29%），开盾后天坠只剩约30%~40%；③ 玄罡核心橙装护盾破碎爆发可借天坠触发。
- 自动护盾AI（给程序）：短冷却护盾（护体）按冷却释放；冷却≥12秒的护盾（金刚不坏）在天坠预警期间可用就立刻释放，否则只在“冷却好之前不会撞上下一次天坠预警”时才释放（为天坠预留）。

### 3.8 maps.csv 地图（3行）
| 字段 | 含义 |
|---|---|
| map_id, name, order | 主键、名称、顺序 |
| realm_required | → realms；进入所需境界 |
| gear_tier | 该地图掉落装备档位（→ gear_tiers） |
| book_gongfa_id | → gongfa；技能书方向 |
| boss_id | → enemies；区域首领 |
| breakthrough_mat_id | → materials；首领首次击败给的突破材料。最后一张图（玄岩洞）为空：首版无更高境界，v2 已删除玄岩金精 |
| normal_enemy_ids | → enemies；本图2种普通怪（`|`分隔） |
| desc | 说明 |

### 3.9 levels.csv 关卡（15行）
| 字段 | 含义 |
|---|---|
| level_id | `LV_地图序_关序`，如 LV_2_3 |
| map_id | → maps |
| index | 地图内序号 1-5 |
| global_index | 全局序号 1-15 |
| name | 关卡名 |
| enemy_hp_mult / enemy_atk_mult | 普通怪 HP/攻击倍率（0.6/0.68/0.8/0.9/1.0），同时用于普通怪灵石/修为 |
| boss_id | → enemies，固定为该地图首领（每关都有首领，前4关是削弱版） |
| boss_hp_mult / boss_atk_mult | 首领倍率（0.4/0.52/0.67/0.84/1.0）；v2：玄岩洞第4、5关首领血量单独下调为 0.72 / 0.78（攻击仍 0.84 / 1.0），使纯玄罡诀打终关首领约48秒；v3：雷泽谷第4、5关首领血量下调为 0.74 / 0.80（攻击仍 0.84 / 1.0），纯玄罡诀打 2-5 首领约47秒、2-4 约43秒。各图首领血量倍率都逐关递增 |
| boss_time_limit_s | 60（计划已定） |
| wave_count | 4（计划已定） |
| unlock_level_id | → levels；需先通关的关卡（1-1 为空） |
| unlock_realm_id | → realms；地图第1关额外需要的境界 |
| normal_drop_table_id / boss_drop_table_id | → drop_tables |
| first_clear_reward_id | → first_clear_rewards.reward_id |
| offline_reward_id | → offline_rewards |
| desc | 说明 |

### 3.10 waves.csv 波次刷怪（每关4波，每行=一波中的一种怪）
| 字段 | 含义 |
|---|---|
| level_id | → levels |
| wave_index | 1-4 |
| enemy_id | → enemies（只允许本图普通怪） |
| count | 数量 |
| spawn_delay_s | 该组相对本波开始的出场延迟（第二种怪晚1.5秒） |
| spawn_side | right（角色向右推进，怪从右侧进场） |
| formation | cluster 聚团 / spread 分散（远程、冲锋、游击类） |

每关总怪数：青竹山 20→39，雷泽谷 30→50（群怪图，雷法优势），玄岩洞 21→35（单体更肉，考验首领与生存）。

### 3.11 first_clear_rewards.csv 首通奖励
| 字段 | 含义 |
|---|---|
| reward_id | `FC_` + level_id（一关多行） |
| level_id | → levels |
| seq | 行序号；联合主键 (reward_id, seq) |
| reward_type | lingshi / xiuwei / equipment / book / material / orange_choice |
| ref_id | 按类型引用：CUR_* / TIER_n / BK_* / MAT_* / EQB_CORE_* |
| count | 数量 |
| weight_set_id | equipment 时 → quality_weights（QW_FIRST_BLUE 蓝80%紫20%；地图终关 QW_FIRST_PURPLE 必紫） |
| desc | 说明 |

规则：
- **每关首通必给1件蓝装以上**（计划已定），槽位随机；1-1 固定为武器（衔接换装引导之后的二次换装）。
- **技能书保底**（v2）：每张地图第2/3/4/5关首通各给1本本区域技能书（主动/被动/主动/终极），共12本；加新手3本 = 全部15本主线必得。终极书：1-5 诛仙剑、2-5 九霄神雷、3-5 金刚不坏。首领概率掉落、离线概率、残页兑换保留，用于重复获取（分解成残页）。
- 青竹山、雷泽谷第5关首通另给区域突破材料；玄岩洞第5关不给（无更高境界）。
- LV_3_5（终关）首通：3行 `orange_choice`（choice_group 同一组），玩家三选一核心橙装（计划已定），4条词条随机。

### 3.12 drop_tables.csv 掉落表
| 字段 | 含义 |
|---|---|
| drop_table_id | 普通怪 DT_NORMAL_Tn / 首领 DT_BOSS_Tn（一表多行） |
| seq | 行序号 |
| roll | per_kill：每次击杀对每行独立判定 |
| entry_type | equipment / material / book_pool |
| ref_id | TIER_n（在该档 equip_bases 非核心底子里随机槽位）/ MAT_* / BP_* |
| chance | 0-1 触发概率 |
| count_min / count_max | 数量区间（闭区间均匀） |
| weight_set_id | 装备品质权重组 → quality_weights |
| desc | 说明 |

- 普通怪：4% 掉装备、5% 掉炼器材料；灵石/修为在 enemies 表。
- 首领：100% 掉1件装备（计划已定）、50% 炼器材料、16% 掉1本区域书（书池内终极书权重30% → 终极书单次约4.8%）。
- **品质抽到橙色时**：从3件核心橙装（equip_bases.is_core=true）中等概率选1件；只有首领（雷泽谷0.5%、玄岩洞1.5%）和终关三选一会出橙装。

### 3.13 book_pools.csv 区域书池
book_pool_id（BP_T1/2/3 对应三张地图）、book_id → skill_books、weight 权重（基础10、普通/被动20、终极30）。

### 3.14 offline_rewards.csv 离线收益（每关一行）
| 字段 | 含义 |
|---|---|
| offline_id / level_id | 主键 / → levels；按“最近已通关关卡”取行；无通关记录不产出（计划已定） |
| lingshi_per_min / xiuwei_per_min | 每分钟灵石/修为 = 在线挂机该关的每轮收益 ÷ 130秒/轮 × 60 × 50%离线效率 |
| equip_per_min | 每分钟装备件数期望（0.2，8小时≈96件，配合背包100件与溢出转材料） |
| weight_set_id | 离线装备品质权重（同普通怪，不出橙） |
| refine_per_min | 每分钟炼器材料 |
| book_chance_per_min | 每分钟掉1本书的概率（0.4%，8小时期望≈1.9本），从 book_pool_id 书池抽 |
| book_pool_id | → book_pools |
| cap_minutes | 480（计划已定）；负时间差按0，养成面板暂停期间不计 |
| desc | 说明 |

结算建议：灵石/修为直接乘分钟数；装备件数与书用期望值的泊松/逐次抽取均可，总数向下取整后剩余小数累计到下次。

### 3.15 装备相关
**equip_slots.csv**：slot_id（SLOT_WEAPON 武器 / ROBE 衣袍 / CROWN 冠 / SHOES 鞋 / RING 戒指 / ARTIFACT 法器）、name、order。

**qualities.csv**：
| 字段 | 含义 |
|---|---|
| quality_id | Q_WHITE/GREEN/BLUE/PURPLE/ORANGE |
| name, order, color | 白绿蓝紫橙，排序，颜色 |
| affix_count | 随机词条数 0/1/2/3/4（计划已定） |
| base_mult | 底子基础属性倍率 1.0/1.1/1.25/1.4/1.6 |
| decompose_refine | 分解得炼器材料（再 × gear_tiers.decompose_mult）：1/2/4/8/25 |
| reroll_refine / reroll_lingshi | 重铸1条词条的材料/灵石消耗（灵石再 × reroll_lingshi_mult）：绿4+100、蓝8+300、紫16+800、橙30+2000 |
| can_reroll | 白装无词条不可重铸 |
| auto_decompose_allowed | 橙=false（永不自动分解，计划已定）；自动分解默认关闭 |
| beam | 掉落光柱样式 |

**gear_tiers.csv**：gear_tier 1/2/3 → map_id；flat_mult 底子与“固定值词条”倍率 1.0/2.4/5.5；decompose_mult 分解倍率 1/2/3；reroll_lingshi_mult 重铸灵石倍率 1/2/4。

**equip_bases.csv**（18普通底子 + 3核心橙装）：base_id、slot_id → equip_slots、gear_tier、name、atk/hp/def/crit_rate/move_speed（白装基础值，实际 × 品质 base_mult）、is_core、orange_effect_id → orange_effects、gongfa_id、desc。一档底子：武器攻8；衣袍生命60防4；冠生命40防2；鞋生命20防3移速10；戒指攻4暴击2%；法器攻5生命20。

**affixes.csv** 词条池（16条）：
| 字段 | 含义 |
|---|---|
| affix_id, name | 主键、名称 |
| stat | 作用属性键（atk/atk_pct/hp/hp_pct/def/crit_rate/crit_dmg/atk_speed/extra_sword_chance/sword_dmg_pct/thunder_dmg_pct/chain_count/cdr/shield_pct/reflect_pct/lingshi_gain_pct） |
| value_type | flat 固定值 / pct 比例 / int 整数 |
| scale_by_tier | true 时数值 × gear_tiers.flat_mult |
| allowed_slots | 可出现槽位 → equip_slots |
| weight | 抽取权重（在该槽允许、品质达标的词条中抽，同件不重复） |
| min_quality | 最低出现品质（追加飞剑需蓝+，连锁目标需紫+） |
| green_min…orange_max | 各品质数值区间（均匀随机；pct 保留3位小数，flat 取整） |

流派词条对应：飞剑=攻速/暴击/暴伤/追加飞剑/飞剑诀伤害；御雷=雷伤/连锁目标/冷却缩减；玄罡=生命/生命%/护盾强度/反伤。

**orange_effects.csv** 核心橙装特效（3条）：orange_effect_id、base_id → equip_bases、gongfa_id、name、param1~3_key/param1~3（特效参数）、internal_cd_s 内置冷却、desc。
- 青冥剑（武器）「青冥万剑」：飞剑诀主动每次命中30%追加飞剑（0.8×），暴击必定追加；对首领伤害+15%。
- 雷音鼓（法器）「雷音震野」：御雷诀连锁+2；御雷诀技能每击杀1敌，所有御雷诀主动剩余冷却−0.5秒。
- 玄罡宝衣（衣袍）「玄罡镇岳」：护盾存在时反伤+25%；护盾被击破时自身r220爆发护盾上限×80%（内置CD 5秒）。

**quality_weights.csv**：weight_set_id、Q_WHITE…Q_ORANGE 各品质权重（相对值，可为小数）、desc。

**分解与重铸**：分解得 decompose_refine × decompose_mult 炼器材料；背包满溢出同样按此转化。重铸=选1条词条，消耗材料+灵石，在该槽允许、品质达标、且不与其余词条重复的池中重抽“词条种类+数值”。核心橙装特效不可重铸。

### 3.16 realms.csv 境界（3行，计划无小层次，首版不设）
| 字段 | 含义 |
|---|---|
| realm_id, name, order | RL_LIANQI 炼气 / RL_ZHUJI 筑基 / RL_JINDAN 金丹 |
| hp / atk / def / crit_rate / crit_dmg | 该境界角色基础属性（绝对值，突破后直接替换）：500/20/10 → 1250/50/25 → 3000/120/55，暴伤1.5/1.6/1.7 |
| prev_realm_id | → realms；从哪个境界突破而来 |
| xiuwei_cost / lingshi_cost | 突破消耗：筑基 2200修为+1500灵石；金丹 7500修为+6000灵石 |
| material_id / material_count | → materials；青竹灵髓×1 / 雷泽雷晶×1 |
| unlock_map_id | → maps；突破后解锁的地图 |
| desc | 说明 |
突破成功率100%、不自动突破（计划已定）。

### 3.17 materials.csv 货币与材料
item_id、name、item_type（currency / material / breakthrough）、map_id（突破材料所属区域）、desc。v2 共6行：CUR_LINGSHI、CUR_XIUWEI、MAT_REFINE、MAT_PAGE、MAT_BT_QINGZHU、MAT_BT_LEIZE（MAT_BT_XUANYAN 玄岩金精已删除）。

### 3.18 tutorial_steps.csv 新手引导（7步）
| 字段 | 含义 |
|---|---|
| step_id, order, name | 主线：领书→学习→装配→释放→换装→首领（order 1-6）；情境：天坠闪避（order 7） |
| category | v3 新增。main=主线顺序引导，前一步完成才触发下一步；contextual=情境引导，满足 trigger 时随时插入，不阻塞主线 |
| trigger | 触发条件（文字说明） |
| trigger_ref_ids | v3 新增。触发涉及的ID（`|`分隔），可引用 tutorial_steps / levels / boss_attacks / enemies / equip_bases / skills / skill_books；程序按它挂监听 |
| ui_target | UI 指向（高亮/手指位置/提示文字） |
| complete_condition | 完成条件 |
| reward_type / reward_ref_ids / reward_count | 奖励类型（none/book/lingshi/material/first_clear）、引用（`|`分隔）、数量；none 时引用为空、数量为0 |
| block_input | true=遮罩只允许点高亮控件 |
| time_scale | v3 新增。提示期间的游戏速度：0=暂停，1=正常，0~1 之间=慢放 |
| time_scale_duration_s | v3 新增。慢放持续的游戏时间（秒）；0=整个提示期间都用 time_scale |
| max_show_count | v3 新增。最多提示几次；达到后视为完成，不再提示 |
| desc | 说明 |

流程：TUT_01 领3本基础书 → TUT_02 依次学习（+100灵石）→ TUT_03 装配到主动栏1-3格、第4格空（计划已定）→ TUT_04 进入1-1，手动按1释放一次（+100灵石）→ TUT_05 1-1第2波固定掉绿武器并换上（+5炼器材料）→ TUT_06 首领登场前讲解0.8秒预警与空格闪避，击败首领（首通奖励）。估算 TUT_01~05 约2.5分钟完成，满足“5分钟内完成领书/学习/装配/释放/换装”。

TUT_07_SKYFALL_DODGE 天坠闪避（v3，情境引导，奖励为空）：
- 触发：存档里本步未完成，且玄岩天坠（BA_YANMO_SKYFALL）的全场预警第一次出现时。自动和手动模式都会触发；正常流程是 3-4 首领开战第15秒。
- UI：屏幕中央显示“按空格闪避！”和空格键图标；【闪避】按钮高亮脉冲；朱砂全场预警照常绘制，不加遮罩（block_input=false）。若当前是自动模式，追加一行小字“闪避会切到手动，点自动按钮可恢复”。
- 暂停/慢放：不暂停，只慢放。预警的 0.8 秒游戏时间以 0.3 倍速播放（现实约 2.7 秒），预警结束恢复 1 倍速。
- 完成：预警结束（天坠落地）那一刻玩家处于 0.3 秒闪避免伤中，判定成功，飘字“闪避成功”，本步完成。没闪避则下次天坠预警再提示；累计提示 3 次（max_show_count）后自动视为完成。
- “首通必须手动闪避”保留：无护盾配置自动挂机过不了 3-4/3-5，靠本引导教会玩家手动闪避，靠第4节的回退规则避免反复死亡。

### 3.19 start_kit.csv 开局物品
entry_type（equipment 开局已装备 / tutorial_drop 引导固定掉落）、ref_id → equip_bases、quality_id → qualities、count、desc。

## 4. 实现备注（给程序）
- 每关首领的危险攻击按 min_level_index 逐步加入；同一时刻最多1个危险攻击在预警中。
- 自动模式不闪避（计划已定），所以首领 danger 伤害在自动挂机时全部吃满——这是“手动闪避明显改善首领战”的数值来源（见 balance.md 的存活时间对比）。
- 九霄神雷：区域内无敌人不进入冷却；剑心通明/青冥剑的“追加飞剑”不再触发追加（防递归）。
- 冷却缩减上限 40%，作用于 cd_s 之后；技能 cd_s 已含等级缩短。
- 反伤只对近战/接触伤害生效，按“减伤前伤害 × 反伤比例”反弹给攻击者，不暴击；true_maxhp 类伤害（玄岩天坠）不触发反伤/反震。
- 护体反震（v2）：护盾存在期间每受一次近战/接触攻击，对攻击者造成 攻击×skill_levels.damage_coef 伤害，不暴击；全局内置间隔 REFLECT_COUNTER_ICD=0.8 秒。护体不再有“护盾期间增伤”。
- 首领预警绘制：读 boss_attacks.telegraph_color / telegraph_style；设置里可把颜色整体切换为 TELEGRAPH_ALT_COLOR（白）。
- 自动护盾AI见 3.7「玄岩天坠」。
- 自动挂机失败回退（v3，制作人决定；常量 AUTO_FAIL_RETREAT_COUNT=1、AUTO_FAIL_RETREAT_RESET_ON）。确切规则：
  1. 自动模式下，玩家在关卡X连续失败（死亡，或首领战超过60秒）达到 AUTO_FAIL_RETREAT_COUNT（=1）次，就把X标记为“当前配置不稳定”，并立即回退到“已通关且未被标记”的最高关卡继续自动挂机，不在X反复死亡。若没有符合条件的关卡，按计划兜底刷 LV_1_1 普通怪。
  2. 以下任一情况发生时清除全部“不稳定”标记：更换技能栏/被动/装备（含重铸）、任一技能升级、境界突破；玩家手动挑战X并成功时，清除X的标记。清除后自动挂机重新以最高已通关关卡为目标（未通关的下一关仍需玩家点“挑战”）。
  3. 标记和失败计数写入存档；在该关成功通关一次会把计数清零。
  4. 手动模式下失败仍按计划原规则（FAIL_RETURN_POLICY：返回最近已通关关卡，不扣资源），不计入自动失败计数，也不打标记。
  5. 离线收益照旧按最近已通关关卡结算，不受标记影响。
  6. 回退时在战斗日志/顶部提示一行：“当前配置难以稳定通过X，已回到Y挂机（调整配置或手动挑战可解除）”。
- 天坠闪避引导 TUT_07 需要能对单个 time_scale 窗口做慢放（Engine.time_scale 或战斗层独立时钟均可），慢放期间闪避输入照常响应。

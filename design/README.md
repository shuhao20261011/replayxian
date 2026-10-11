# 《重走修仙路》首版配置表说明（v5）

> 适用：Godot 4.7.2 + GDScript 首版（无后端/账号/付费）。依据：《重走修仙路》开发计划（2026-10-11）。
> 计划里已定的规则（4波+首领、首领限时60秒、预警0.8秒、闪避0.3秒/冷却3秒、6槽5品质0-4词条、技能上限10级、离线上限8小时、10残页换书、背包100件等）全部照搬，没有改动。

## 1. 目录与工作流

```
design/
├─ README.md              本文件：每张表、每个字段的含义/单位/取值范围/引用关系
├─ balance.md             数值目标与每关耗时估算依据、三流派差异
├─ CHANGELOG.md           版本变更记录（每版给前端的表/字段改动清单）
├─ icon_list.csv          图标清单（v5.1，gen_tables.py 生成，validate.py 检查与各表 icon 列一致）
├─ balance_report.csv     balance.py 输出的逐关估算结果（自动生成，勿手改）
├─ data/                  全部配置表（CSV，UTF-8 无 BOM，逗号分隔，首行为英文字段名）
└─ tools/
   ├─ gen_tables.py       首版数值“种子”生成器：输出 data/*.csv
   ├─ common.py           CSV 读取、文案占位符渲染（render_tpl）、首领危险招式排招模拟（danger_schedule，复刻前端 boss.gd）
   ├─ validate.py         校验：可解析、主键唯一、ID 全局唯一、跨表引用无断链、计划硬性规则、15本书获取途径覆盖、文案规范（第5节）、危险招式间隔（BUG-005）
   └─ balance.py          主线时长/DPS/生存估算，输出 balance_report.csv；加 --md 输出 Markdown 表
```

- 运行（在 design/ 目录）：`python3 tools/gen_tables.py && python3 tools/validate.py && python3 tools/balance.py`
- **数据源约定**：首版 CSV 由 gen_tables.py 生成。以后如直接手改 CSV，请不要再跑 gen_tables.py（会覆盖）；或把改动同步回脚本。任何改动后都要跑 validate.py（退出码 1 = 有错）与 balance.py。
<<<<<<< HEAD
- 当前状态（v5，2026-10-11：v2 按用户已确认的9条决策修订；v3 按制作人决定加入自动失败回退规则、天坠闪避引导、下调2-4/2-5首领血量；v4 定案反伤/反震吃防御、对齐前端操作规则与节奏常量；v5 回调 2-5 首领血量、按“精致的成品，好看的 UI”打磨全部玩家可见文案（新增 ui_texts.csv 与若干追加列，见第5节）、修复 BUG-005 首领危险招式间隔）：26 张表、约 613 行，validate.py 0 错误；v5.1 预警色按地图配置、新增 icon_list.csv。修订明细见 `CHANGELOG.md`。
=======
- 当前状态（v4，2026-10-11：v2 按用户已确认的9条决策修订；v3 按制作人决定加入自动失败回退规则、天坠闪避引导、下调2-4/2-5首领血量；v4 定案反伤/反震吃防御、对齐前端操作规则与节奏常量）：25 张表、约 587 行（含表头），validate.py 0 错误。修订明细见 `CHANGELOG.md`。
>>>>>>> 02a0548 (feat(stage3-4): 功法/技能书/升级/残页 + 装备生成/词条/橙装/掉落/换装/分解/重铸；装/功面板；首领最小间距；v4 反伤/反震防御开关；正式主角与青竹山背景接入)

### 通用约定
- **ID**：全大写英文+下划线，按表加前缀，全局唯一（validate.py 检查）。前缀：`GF_`功法 `SK_`技能 `BK_`技能书 `EN_`普通怪 `BOSS_`首领 `BA_`首领招式 `MAP_`地图 `LV_`关卡 `RL_`境界 `CUR_`货币 `MAT_`材料 `SLOT_`槽位 `Q_`品质 `EQB_`装备底子 `AF_`词条 `OE_`橙装特效 `QW_`品质权重组 `DT_`掉落表 `BP_`书池 `FC_`首通奖励 `OFF_`离线收益 `TUT_`引导步骤。`TIER_n` 是“第 n 档装备随机池”的伪 ID，对应 gear_tiers.gear_tier=n。
- 中文只出现在 `name` / `desc` / `desc_tpl` / `note` / `role` / `build_dir` / `source_desc` / `hint_text` / `sub_text` / `button_text` / `success_text` / `trigger` / `ui_target` / `complete_condition` 等文字字段。
- **玩家可见 vs 策划说明（v5）**：`name`、`desc`、`desc_tpl`、`role`、`build_dir`、`source_desc`、tutorial_steps 的 `hint_text`/`sub_text`/`button_text`/`success_text`、ui_texts.text 是**玩家可见文案**，遵守第5节『文案规范』；`note`、`trigger`、`ui_target`、`complete_condition`、constants.desc 等是给程序/策划看的说明，不上屏。v5 起凡是有 `note` 列的表，原来的技术性 desc 挪进 note，desc 改为上屏文案。
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

<<<<<<< HEAD
v5 新增：`DANGER_MIN_GAP_MARGIN_S`=0.5 秒（BUG-005：同一首领任意两次危险招式判定间隔 ≥ DODGE_COOLDOWN + 本值 = 3.5 秒，validate.py 检查）；`BOSS_MULTI_AREA_INTERVAL`=0.4 秒（多段危险招式相邻两段的出现间隔，与前端代码默认一致，validate.py 排招模拟读取）。

关键常量：普攻系数1.0/间隔0.8秒/射程150；基础暴击5%、暴伤1.5倍；闪避0.3秒/冷却3秒/位移160；预警0.8秒；首领限时60秒；DEF_CONST=100；冷却缩减上限40%；暴击率上限75%；反伤上限60%；护体反震全局内置间隔0.8秒（REFLECT_COUNTER_ICD）；危险攻击预警色按地图配置（v5.1，见 3.7「预警绘制」）：朱砂 #B8382C（TELEGRAPH_DEFAULT_COLOR）/ 预警白 #F4F1EA（TELEGRAPH_ALT_COLOR），虚线（TELEGRAPH_DEFAULT_STYLE），外描边 2px #1C1E21 60%、填充 15%（TELEGRAPH_OUTLINE_* / TELEGRAPH_FILL_ALPHA）；10残页换1书；背包100；离线上限480分钟；自动存档10秒；自动模式同关连续失败1次即回退（AUTO_FAIL_RETREAT_COUNT，规则见第4节）；反伤/反震吃防御（REFLECT_IGNORE_DEF=0、COUNTER_IGNORE_DEF=0，公式见第4节）。
=======
关键常量：普攻系数1.0/间隔0.8秒/射程150；基础暴击5%、暴伤1.5倍；闪避0.3秒/冷却3秒/位移160；预警0.8秒；首领限时60秒；DEF_CONST=100；冷却缩减上限40%；暴击率上限75%；反伤上限60%；护体反震全局内置间隔0.8秒（REFLECT_COUNTER_ICD）；危险攻击预警默认朱砂 #C8312B 虚线（TELEGRAPH_DEFAULT_COLOR / TELEGRAPH_DEFAULT_STYLE），可选白色 #FFFFFF（TELEGRAPH_ALT_COLOR）；10残页换1书；背包100；离线上限480分钟；自动存档10秒；自动模式同关连续失败1次即回退（AUTO_FAIL_RETREAT_COUNT，规则见第4节）；反伤/反震吃防御（REFLECT_IGNORE_DEF=0、COUNTER_IGNORE_DEF=0，公式见第4节）。
>>>>>>> 02a0548 (feat(stage3-4): 功法/技能书/升级/残页 + 装备生成/词条/橙装/掉落/换装/分解/重铸；装/功面板；首领最小间距；v4 反伤/反震防御开关；正式主角与青竹山背景接入)

节奏常量（v4，与前端代码同名、默认值一致；前端读表覆盖代码默认值，balance.py 也从这里读，改一处两边同时生效）：

| key | 值 | 作用 |
|---|---|---|
| RUN_START_WALK_TIME | 1.0 秒 | 每轮开局到第1波刷出前的自动前进 |
| WAVE_ENTER_WALK_TIME | 3.0 秒 | 第N波清空到第N+1波刷出之间的自动前进（最后一波后直接首领登场） |
| SPAWN_DISTANCE_PX | 760 像素 | 普通怪刷在玩家前方的距离 |
| BOSS_SPAWN_DISTANCE_PX | 560 像素 | 首领刷在玩家前方的距离 |
| AUTO_ENGAGE_RANGE_PX | 450 像素 | 敌人进入该距离视为“已交战”；balance.py 把它当作开始稳定输出的距离 |
| BOSS_INTRO_TIME | 3.0 秒 | 最后一波清空到首领出现的登场表现 |
| RESULT_SHOW_TIME | 2.0 秒 | 每轮胜负结算展示，之后自动开下一轮 |
| AUTO_SHIELD_RESERVE_CD | 12 秒 | 冷却≥该值的护盾（金刚不坏）由自动AI为天坠预留 |

<<<<<<< HEAD
60秒首领限时从首领出现开始计，不含登场3秒。前端代码里另有 GROUND_Y=585、PLAYER_BACKTRACK_PX=600（BOSS_MULTI_AREA_INTERVAL v5 起入表），以及同组怪逐只出场间隔0.12秒、同组间距45/110像素（写死在代码里）。这些只影响表现、不影响耗时估算，没有入表，沿用代码默认值。
=======
60秒首领限时从首领出现开始计，不含登场3秒。前端代码里另有 GROUND_Y=585、BOSS_MULTI_AREA_INTERVAL=0.4、PLAYER_BACKTRACK_PX=600，以及同组怪逐只出场间隔0.12秒、同组间距45/110像素（写死在代码里）。这些只影响表现、不影响耗时估算，没有入表，沿用代码默认值。
>>>>>>> 02a0548 (feat(stage3-4): 功法/技能书/升级/残页 + 装备生成/词条/橙装/掉落/换装/分解/重铸；装/功面板；首领最小间距；v4 反伤/反震防御开关；正式主角与青竹山背景接入)

### 3.2 gongfa.csv 功法（3行）
| 字段 | 含义 / 取值 |
|---|---|
| gongfa_id | GF_SWORD 飞剑诀 / GF_THUNDER 御雷诀 / GF_GANG 玄罡诀 |
| name, role, build_dir | 名称、战斗定位、主要搭配方向（照抄计划） |
| book_map_id | → maps；该功法技能书主要产出地图 |
| color | **UI 文字色**（功法名、标签），#RRGGBB；v5 起保证在 UI 墨底 #232C25 上对比度 ≥4.5（飞剑青 #63BD9D / 御雷 #9A93E0 / 玄罡金 #CEA445） |
| desc | 玩家可见一句话简介（≤24字） |
| note | v5 追加列：原策划说明 |
| icon | v5 追加列：图标资源键 `ui_icon_gongfa_<id小写>` |
| fx_color | v5 追加列：**技能特效主色**，与美术 v2 规范一致（飞剑青 #63BD9D / 雷电紫蓝 #7872C3 / 护盾金 #CEA445）；只用于特效，不用于小字 |

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
| desc | 1级渲染好的上屏说明（= desc_tpl 用 skills 本行渲染；validate 检查二者一致） |
| desc_tpl | v5 追加列：说明模板，占位符 `{字段名}` / `{字段名:pct}` 等对应 skill_levels 同名字段，UI 按**当前等级**渲染（规则见第5节） |
| note | v5 追加列：原策划说明 |
| icon | v5 追加列：图标资源键 `ui_icon_skill_<id小写>` |

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
| source_desc | 获取途径说明（功法面板“未学习”时显示，≤28字；v5 改为由首通奖励/掉落/书池自动生成，如“青竹山第2关首通必得；竹魅掉落”） |
| icon | v5 追加列：技能书图标键 `ui_icon_book_<功法小写>`（同功法共用书皮） |

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
| desc | 玩家可见描述（图鉴/首领登场，≤22字） |
| note | v5 追加列：原策划说明（行为、数值说明） |

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
| telegraph_color | 预警颜色 #RRGGBB；v5.1 起危险招式显式写入**所属地图的预警色**（竹魅 `#B8382C`，夔牛、岩魔 `#F4F1EA`）；允许留空=取地图值；普攻为空（无预警） |
| telegraph_style | 预警描边样式：`dashed` 虚线（默认）/ `solid` 实线；普攻为空 |
| desc | 上屏说明（= desc_tpl 渲染结果，≤32字） |
| desc_tpl | v5 追加列：说明模板（可用 {count}、{damage_maxhp_pct:pct} 等本行字段） |
| note | v5 追加列：原策划说明（判定形状、出现关卡） |

危险攻击：竹刺破土（v5 由“竹刺突”改名；前方 520×80 长条，3.0×）、竹叶旋风（自身 r220，3.3×，第3关起）；雷霆践踏（自身 r260，3.0×）、天雷三连（玩家脚下 3×r90，各2.4×，第3关起）；碎岩冲撞（前方 900×120 全宽，3.5×，只能闪避）、地裂（以玩家位置为圆心 2×r150、两段间隔0.4秒，各3.4×，第3关起）、**玄岩天坠**（v2 新增，见下）。闪避判定：预警结束瞬间玩家处于闪避免伤（0.3秒）或已离开区域 = 无伤。

**危险招式节奏（v5，BUG-005 修复）**：前端排招规则（boss.gd）——各危险招式计时器从首领出现时的 first_cast_s 倒数；首领不在前摇且场上没有预警时，按 attack_ids 顺序释放第一个就绪的招式，计时器从实际释放时刻重置为 cd_s。v4 的冷却 8/12、9/12、10/13/20 互不整除，几轮后会挤在一起（3-4/3-5 地裂末段判定 33.72 秒 → 天坠 35.78 秒，只隔 2.06 秒 < 闪避冷却 3 秒）。v5 改为固定节拍：

| 首领 | 危险招式 first_cast_s / cd_s | 判定时刻（首领出现后，秒） | 最小间隔 |
|---|---|---|---|
| 竹魅 | 竹刺 4/8；竹叶 8/16（原 6/12） | 竹刺 4.8、竹叶 8.8、竹刺 12.8、竹刺 20.8、竹叶 24.8 … | 3.9 秒（竹刺每次因浮点残差晚1帧，60秒内由4.0降到3.9） |
| 夔牛 | 践踏 4.5/9；三连 8.5/18（原 6/12） | 践踏 5.3、三连 9.3–10.1、践踏 14.3、23.3、三连 27.3–28.1 … | 4.0 秒 |
| 岩魔 | 冲撞 5/10；地裂 10/20（原 6.5/13）；天坠 20/20（原 15/20） | 冲撞 5.8、地裂 10.8–11.2、冲撞 15.8、天坠 20.8、冲撞 25.8、地裂 30.8–31.2、冲撞 35.8、天坠 40.8 … | 4.6 秒 |

- 约束：同一首领任意两次危险招式（含不同招式、多段招式取首/末段），后者首个判定 − 前者末个判定 ≥ DODGE_COOLDOWN + DANGER_MIN_GAP_MARGIN_S = 3.5 秒。validate.py 逐帧（60帧/秒）复刻上面的排招规则，模拟全部15关首领出现后60秒，并把危险招式优先顺序全排列各跑一遍（防同帧就绪时顺序翻转），任何一处不足即报错。
- 冷却拉长的招式按比例提高系数（竹叶 2.5→3.3、三连 1.6→2.4、地裂 2.2→3.4），危险招式总伤害/秒基本不变；单次没躲开更疼，更突出“手动闪避”。
- 未建模：掌心雷眩晕首领会推迟其排招（眩晕期间计时器是否走由前端决定），可能压缩间隔，建议前端加运行时保护（见第4节）。

**BA_YANMO_SKYFALL 玄岩天坠**（v2，突出玄岩洞生存玩法）：
- 第4关起出现（min_level_index=4）；首领出现后第20秒首次释放，之后每20秒一次（20/40/60秒…，v5 BUG-005：原 15/35/55）；预警0.8秒，全场（anchor=arena，1280×720）虚线，颜色同玄岩洞地图预警色（预警白 #F4F1EA）。
- 伤害=玩家最大生命×70%真实伤害（无视防御/减伤，先扣护盾）。叠加普攻与其他招式的伤害，无护盾、不闪避时第一次天坠就基本致死（模型：纯飞剑/纯御雷自动挂机在第一次天坠即20秒阵亡）。
- 应对：① 预警内按空格闪避（0.3秒免伤），完全无伤；② 护盾硬扛：护体（8%~12.5%）+金刚不坏（20%~29%），开盾后天坠只剩约30%~40%；③ 玄罡核心橙装护盾破碎爆发可借天坠触发。
- 自动护盾AI（给程序）：短冷却护盾（护体）按冷却释放；冷却≥12秒的护盾（金刚不坏）在天坠预警期间可用就立刻释放，否则只在“冷却好之前不会撞上下一次天坠预警”时才释放（为天坠预留）。

**预警绘制（v5.1，美术实测定案）**
- 取色优先级：`boss_attacks.telegraph_color`（非空）→ 所属地图 `maps.telegraph_color` → `constants.TELEGRAPH_DEFAULT_COLOR`。表里危险招式已显式填好地图色，所以前端现有逻辑（招式色非空就用招式色，否则用默认色）**不改代码即可按地图生效**；maps 列供以后新增招式留空时使用。玩家设置“统一用预警白”时一律用 TELEGRAPH_ALT_COLOR。
- 样式：主线条=预警色，虚线（telegraph_style），0.8 秒闪烁；主线条外侧加外描边 TELEGRAPH_OUTLINE_PX=2 像素、颜色 TELEGRAPH_OUTLINE_COLOR=#1C1E21、不透明度 TELEGRAPH_OUTLINE_ALPHA=0.6；区域内部填充=预警色、不透明度 TELEGRAPH_FILL_ALPHA=0.15。
- validate：两个常量必须等于美术规范值；maps.telegraph_color 只能取这两个值；危险招式颜色为空或等于所属地图色；普攻不得有预警色。

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
| desc | 玩家可见地图简介（≤22字） |
| telegraph_color | v5.1 追加列：本图首领危险招式预警色，只能取 TELEGRAPH_DEFAULT_COLOR（#B8382C 朱砂）或 TELEGRAPH_ALT_COLOR（#F4F1EA 预警白）。青竹山 #B8382C；雷泽谷、玄岩洞 #F4F1EA（美术实测：深色/熔岩背景上朱砂不够显眼） |
| note | v5 追加列：原策划说明 |

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
| boss_hp_mult / boss_atk_mult | 首领倍率（0.4/0.52/0.67/0.84/1.0）；v2：玄岩洞第4、5关首领血量单独下调为 0.72 / 0.78（攻击仍 0.84 / 1.0），使纯玄罡诀打终关首领约48秒；v3：雷泽谷第4、5关首领血量下调为 0.74 / 0.80（攻击仍 0.84 / 1.0）；v5：2-5 回调为 0.82，纯玄罡诀打 2-5 首领 46 秒（45.6，限时口径不含登场）、2-4 40 秒。各图首领血量倍率都逐关递增 |
| boss_time_limit_s | 60（计划已定） |
| wave_count | 4（计划已定） |
| unlock_level_id | → levels；需先通关的关卡（1-1 为空） |
| unlock_realm_id | → realms；地图第1关额外需要的境界 |
| normal_drop_table_id / boss_drop_table_id | → drop_tables |
| first_clear_reward_id | → first_clear_rewards.reward_id |
| offline_reward_id | → offline_rewards |
| desc | 玩家可见关卡意境短句（≤16字，如“竹径清幽，初试身手。”）；关卡序号由 UI 用 ui_texts.HUD_LEVEL 拼 |
| note | v5 追加列：原策划说明 |

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
**equip_slots.csv**：slot_id（SLOT_WEAPON 武器 / ROBE 衣袍 / CROWN 头冠 / SHOES 鞋履 / RING 戒指 / ARTIFACT 法器；v5 统一为两字）、name、order。

**qualities.csv**：
| 字段 | 含义 |
|---|---|
| quality_id | Q_WHITE/GREEN/BLUE/PURPLE/ORANGE |
| name, order, color | 白绿蓝紫橙，排序，**UI 文字色**（v5：#CACAC9 / #62BB73 / #5A9BE6 / #B07BE0 / #D89522，在墨底 #232C25 上对比度 ≥4.5） |
| beam_color | v5 追加列：掉落光柱/品质框颜色，与美术 v2 规范一致（#CACAC9 / #62BB73 / #347DD2 / #934DC5 / #D89522） |
| affix_count | 随机词条数 0/1/2/3/4（计划已定） |
| base_mult | 底子基础属性倍率 1.0/1.1/1.25/1.4/1.6 |
| decompose_refine | 分解得炼器材料（再 × gear_tiers.decompose_mult）：1/2/4/8/25 |
| reroll_refine / reroll_lingshi | 重铸1条词条的材料/灵石消耗（灵石再 × reroll_lingshi_mult）：绿4+100、蓝8+300、紫16+800、橙30+2000 |
| can_reroll | 白装无词条不可重铸 |
| auto_decompose_allowed | 橙=false（永不自动分解，计划已定）；自动分解默认关闭 |
| beam | 掉落光柱样式 |

**gear_tiers.csv**：gear_tier 1/2/3 → map_id；flat_mult 底子与“固定值词条”倍率 1.0/2.4/5.5；decompose_mult 分解倍率 1/2/3；reroll_lingshi_mult 重铸灵石倍率 1/2/4。

**equip_bases.csv**（18普通底子 + 3核心橙装）：base_id、slot_id → equip_slots、gear_tier、name、atk/hp/def/crit_rate/move_speed（白装基础值，实际 × 品质 base_mult）、is_core、orange_effect_id → orange_effects、gongfa_id、desc（玩家可见短句 ≤16字）、note（v5 追加：原说明）、icon（v5 追加：`ui_icon_equip_<id小写>`）。一档底子：武器攻8；衣袍生命60防4；冠生命40防2；鞋生命20防3移速10；戒指攻4暴击2%；法器攻5生命20。

**affixes.csv** 词条池（16条；v5 名称去掉“%”等符号：攻击%→攻击加成、生命%→生命加成、攻速→攻击速度、雷伤→御雷诀伤害；数值显示由 UI 按 value_type 拼接）：
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

**orange_effects.csv** 核心橙装特效（3条）：orange_effect_id、base_id → equip_bases、gongfa_id、name、param1~3_key/param1~3（特效参数）、internal_cd_s 内置冷却、desc（上屏，= desc_tpl 渲染）、desc_tpl（v5 追加：模板，占位符取本行 param1~3 / internal_cd_s）、note（v5 追加：原说明）。
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
| desc | 玩家可见境界短句（≤14字） |
| note | v5 追加列：原策划说明 |
突破成功率100%、不自动突破（计划已定）。

### 3.17 materials.csv 货币与材料
item_id、name、item_type（currency / material / breakthrough）、map_id（突破材料所属区域）、desc（玩家可见 ≤20字）、note（v5 追加：原说明）、icon（v5 追加：`ui_icon_item_<id小写>`）。v2 共6行：CUR_LINGSHI、CUR_XIUWEI、MAT_REFINE、MAT_PAGE、MAT_BT_QINGZHU、MAT_BT_LEIZE（MAT_BT_XUANYAN 玄岩金精已删除）。

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
| hint_text | v5 追加列：主提示语（大字，≤12字，**以动词开头**，如“按 1 释放飞剑”）；与 ui_target 第一个“…”内文字一致（兼容前端现解析方式） |
| sub_text | v5 追加列：补充小字（≤24字，可空）；TUT_07 为“闪避会切到手动，点【自动战斗】或按 Q 恢复”，只在自动模式显示 |
| button_text | v5 追加列：高亮按钮上的文字（≤4字，可空=沿用控件自身文字） |
| success_text | v5 追加列：完成飘字（≤16字），可含 {reward_count} |

流程：TUT_01 领3本基础书 → TUT_02 依次学习（+100灵石）→ TUT_03 装配到主动栏1-3格、第4格空（计划已定）→ TUT_04 进入1-1，手动按1释放一次（+100灵石）→ TUT_05 1-1第2波固定掉绿武器并换上（+5炼器材料）→ TUT_06 首领登场前讲解0.8秒预警与空格闪避，击败首领（首通奖励）。估算 TUT_01~05 约2.5分钟完成，满足“5分钟内完成领书/学习/装配/释放/换装”。

TUT_07_SKYFALL_DODGE 天坠闪避（v3，情境引导，奖励为空）：
<<<<<<< HEAD
- 触发：存档里本步未完成，且玄岩天坠（BA_YANMO_SKYFALL）的全场预警第一次出现时。自动和手动模式都会触发；正常流程是 3-4 首领出现后第20秒（v5 BUG-005：原第15秒）。
- UI：屏幕中央显示“按空格闪避！”和空格键图标；【闪避】按钮高亮脉冲；全场预警照常绘制（玄岩洞为预警白），不加遮罩（block_input=false）。若当前是自动模式，追加一行小字“闪避会切到手动，点【自动战斗】或按 Q 恢复”。
=======
- 触发：存档里本步未完成，且玄岩天坠（BA_YANMO_SKYFALL）的全场预警第一次出现时。自动和手动模式都会触发；正常流程是 3-4 首领开战第15秒。
- UI：屏幕中央显示“按空格闪避！”和空格键图标；【闪避】按钮高亮脉冲；朱砂全场预警照常绘制，不加遮罩（block_input=false）。若当前是自动模式，追加一行小字“闪避会切到手动，点【自动战斗】或按 Q 恢复”。
>>>>>>> 02a0548 (feat(stage3-4): 功法/技能书/升级/残页 + 装备生成/词条/橙装/掉落/换装/分解/重铸；装/功面板；首领最小间距；v4 反伤/反震防御开关；正式主角与青竹山背景接入)
- 暂停/慢放：不暂停，只慢放。预警的 0.8 秒游戏时间以 0.3 倍速播放（现实约 2.7 秒），预警结束恢复 1 倍速。
- 完成：预警结束（天坠落地）那一刻玩家处于 0.3 秒闪避免伤中，判定成功，飘字“闪避成功”，本步完成。没闪避则下次天坠预警再提示；累计提示 3 次（max_show_count）后自动视为完成。
- “首通必须手动闪避”保留：无护盾配置自动挂机过不了 3-4/3-5，靠本引导教会玩家手动闪避，靠第4节的回退规则避免反复死亡。

### 3.19 start_kit.csv 开局物品
entry_type（equipment 开局已装备 / tutorial_drop 引导固定掉落）、ref_id → equip_bases、quality_id → qualities、count、desc。

### 3.20 ui_texts.csv 界面文案（v5 新增，45行）
| 字段 | 含义 |
|---|---|
| key | 主键，英文大写（BANNER_/FLOAT_/HUD_/BTN_/LABEL_/TOAST_/LOOT_/OFFLINE_/TEXT_ 前缀） |
| text | 上屏文案，可含占位符 `{名}` |
| placeholders | 占位符声明，`名:来源` 用 `;` 分隔；来源为 `表.字段`（取该表某行的字段，如 level_name:levels.name）或 `intN`（运行时整数，最多 N 位） |
| max_chars | 渲染后的最大字数（validate 用最长的来源值代入检查） |
| context | 出现位置说明（不上屏） |

用于替换前端写死的提示，例如自动失败回退横幅 BANNER_RETREAT“暂难稳过{failed_level_name}，退守{to_level_name}”+ BANNER_RETREAT_TIP“换配置、升技能或点【挑战】可再战”（原 battle.gd 写死“当前配置难以稳定通过X，已回到Y挂机…”）。

### 3.21 icon_list.csv 图标清单（v5.1 新增，放在 design/ 根目录，不是运行时数据表）
| 字段 | 含义 |
|---|---|
| icon_key | 图标资源键（= 各表 icon 列；按键为 ui_icon_key_space / q / 1–4），去重 |
| category | 功法 / 技能 / 技能书 / 货币材料 / 装备 / 按键 |
| refs | 对应表与ID，`表:ID` 用 `|` 分隔（同功法技能书共用一张书皮，所以一行对多本书）；按键写 `key:键名`，并列出用到它的引导步骤 |
| name | 中文名（多个用“、”） |
| prompt | 简短画面提示，取自上屏文案意象 + 功法特效色 + 统一画风（写实手绘、深色底、左上光源、古金细描边） |
| size | 建议尺寸：图标源图 128×128、显示 64×64（美术规范 5 节）；按键 96×96→48×48，空格键 256×96→128×48 |

## 4. 实现备注（给程序）
- 每关首领的危险攻击按 min_level_index 逐步加入；同一时刻最多1个危险攻击在预警中。
<<<<<<< HEAD
- 危险招式间隔（v5 BUG-005）：表内节奏已保证纯排招下任意两次危险判定 ≥3.5 秒。建议前端加一层运行时保护：释放危险招式前，若“本招首个判定时刻 − 上一危险招式末个判定时刻 < DODGE_COOLDOWN + DANGER_MIN_GAP_MARGIN_S”，就把本招推迟到满足为止（覆盖眩晕、卡帧等表外因素）。
=======
>>>>>>> 02a0548 (feat(stage3-4): 功法/技能书/升级/残页 + 装备生成/词条/橙装/掉落/换装/分解/重铸；装/功面板；首领最小间距；v4 反伤/反震防御开关；正式主角与青竹山背景接入)
- 自动/手动切换（v4，按前端已实现的规则确认）：自动模式下闪避（空格或 HUD【闪避】按钮）或左右移动（A/D/方向键）会立即切到手动，松手后不自动恢复；技能键 1-4 不切手动（同一帧手动释放优先，本帧自动AI不再放技能）；切回自动要点 HUD【自动战斗】按钮或按 Q。
- 自动模式不闪避（计划已定），所以首领 danger 伤害在自动挂机时全部吃满——这是“手动闪避明显改善首领战”的数值来源（见 balance.md 的存活时间对比）。
- 九霄神雷：区域内无敌人不进入冷却；剑心通明/青冥剑的“追加飞剑”不再触发追加（防递归）。
- 冷却缩减上限 40%，作用于 cd_s 之后；技能 cd_s 已含等级缩短。
- 反伤只对近战/接触伤害生效，不暴击；true_maxhp 类伤害（玄岩天坠）不触发反伤/反震。
- 反伤/反震与防御（v4 定案：都吃攻击者防御，与前端现有实现一致；balance.py v2 起也按吃防御估算）：
  - 反伤 = 玩家受到的减伤前伤害 × min(被动/词条反伤 + 护体护盾期间反伤加成, REFLECT_CAP) × (1 − 攻击者DEF/(攻击者DEF+DEF_CONST))
  - 反震 = 玩家攻击 × 护体 skill_levels.damage_coef × (1 − 攻击者DEF/(攻击者DEF+DEF_CONST))，每 REFLECT_COUNTER_ICD 秒最多1次
  - 攻击者DEF 取当前防御（含破甲剑等减防效果，与普通伤害一致）。都不暴击。REFLECT_IGNORE_DEF / COUNTER_IGNORE_DEF 改为 1 时，对应项去掉最后的防御系数（无视防御）。前端只需在调用敌人受伤结算时按开关跳过防御减伤。
- 护体反震（v2）：护盾存在期间每受一次近战/接触攻击，对攻击者造成 攻击×skill_levels.damage_coef 伤害，不暴击；全局内置间隔 REFLECT_COUNTER_ICD=0.8 秒。护体不再有“护盾期间增伤”。
- 首领预警绘制（v5.1）：颜色按 boss_attacks.telegraph_color → maps.telegraph_color → TELEGRAPH_DEFAULT_COLOR 取；设置里可整体切换为 TELEGRAPH_ALT_COLOR（预警白）；telegraph.gd 需新增外描边（TELEGRAPH_OUTLINE_PX/COLOR/ALPHA）与内部填充（TELEGRAPH_FILL_ALPHA），并把代码里的兜底色 #C8312B/#FFFFFF 改为 #B8382C/#F4F1EA。详见 3.7「预警绘制」。
- 自动护盾AI见 3.7「玄岩天坠」。
- 自动挂机失败回退（v3，制作人决定；常量 AUTO_FAIL_RETREAT_COUNT=1、AUTO_FAIL_RETREAT_RESET_ON）。确切规则：
  1. 自动模式下，玩家在关卡X连续失败（死亡，或首领战超过60秒）达到 AUTO_FAIL_RETREAT_COUNT（=1）次，就把X标记为“当前配置不稳定”，并立即回退到“已通关且未被标记”的最高关卡继续自动挂机，不在X反复死亡。若没有符合条件的关卡，按计划兜底刷 LV_1_1 普通怪。
  2. 以下任一情况发生时清除全部“不稳定”标记：更换技能栏/被动/装备（含重铸）、任一技能升级、境界突破；玩家点【挑战】按钮发起X并通关时（v4 明确：无论中途是否切过自动、是否全程手动），清除X的标记。系统自动发起的挂机轮（包括回退后的挂机）不算。清除后自动挂机重新以最高已通关关卡为目标（未通关的下一关仍需玩家点“挑战”）。
  3. 标记和失败计数写入存档；在该关成功通关一次会把计数清零。
  4. 手动模式下失败仍按计划原规则（FAIL_RETURN_POLICY：返回最近已通关关卡，不扣资源），不计入自动失败计数，也不打标记。
  5. 离线收益照旧按最近已通关关卡结算，不受标记影响。
  6. 回退时顶部横幅显示 ui_texts.BANNER_RETREAT（“暂难稳过{failed_level_name}，退守{to_level_name}”），下方小字 BANNER_RETREAT_TIP（v5 起文案入表，替换原写死的句子）。
- 天坠闪避引导 TUT_07 需要能对单个 time_scale 窗口做慢放（Engine.time_scale 或战斗层独立时钟均可），慢放期间闪避输入照常响应。

## 5. 文案规范（v5）

依据 `/workspace/xxhbgj/PRINCIPLES.md` 第一条“精致的成品，好看的 UI（以 v2 宣纸水墨风格为准）”。凡是上屏的字段（见“通用约定·玩家可见 vs 策划说明”）都按本节写；validate.py 会自动检查标 ✔ 的条目。

### 5.1 语感
- 古风修仙语感，短句、有画面，四字/六字节奏优先；不写解释性的“系统话”。例：“御剑离手，直取当面之敌，造成攻击160%的伤害。”
- 先意象、后数值：一句意象（≤8字）+ 一句效果，效果句只写玩家需要知道的数。
- 禁用词 ✔：Boss/CD/DPS/HP/ATK/DEF/Buff、像素、效果值、系数、货币、金币、经验、法力、怪物、几率、攻击力、近战、接触、伤害值、红色区域。
- 标点 ✔：一律全角（，。；：！？“”【】·）；英文半角空格只允许出现在按键名两侧（“按 Q 恢复”“按 1 释放飞剑”）。desc 以“。”结尾 ✔；按钮、标签、横幅、飘字不加句号。
- 按键/按钮写法：键盘键用“按 X”，界面按钮用【按钮名】。

### 5.2 术语表（全表统一）
| 用这个 | 不用 |
|---|---|
| 灵石、修为 | 货币、金币、经验 |
| 功法（飞剑诀/御雷诀/玄罡诀）、技能、技能书、悟道残页 | 流派（仅策划文档用）、法术、秘籍 |
| 炼器材料、突破材料 | 强化石 |
| 首领 | Boss、BOSS |
| 攻击、防御、最大生命、暴击率、暴击伤害、攻击速度 | 攻击力、HP、ATK、DEF、攻速 |
| 护盾、反伤、反震、近身攻击 | 近战/接触攻击 |
| 概率 | 几率 |
| 冷却 | CD |
| 预警、预警区域（玩家可见，不提颜色：各地图预警色不同）/ 朱砂、预警白（只在美术与程序文档中） | 朱红预警、红色区域、红圈、白框等以颜色指代预警的说法（validate 禁用） |
| 头冠、鞋履（槽位两字） | 冠、鞋 |
| 地图第N关（如“青竹山第2关”） | 1-2、LV_1_2 |

### 5.3 长度上限 ✔（按字计，中英文/数字/符号都算1字；desc 按1级和10级两次渲染检查）
| 表.字段 | 上限 | 表.字段 | 上限 |
|---|---|---|---|
| gongfa.name / role / build_dir / desc | 3 / 6 / 16 / 24 | skills.name / desc | 4 / 56 |
| skill_books.name / source_desc | 6 / 28 | enemies.name / desc | 4（首领 7） / 22 |
| boss_attacks.name / desc | 4 / 32 | maps.name / desc | 3 / 22 |
| levels.name / desc | 4 / 16 | realms.name / desc | 2 / 14 |
| materials.name / desc | 4 / 20 | equip_slots.name | 2 |
| equip_bases.name / desc | 4 / 16 | affixes.name | 5 |
| orange_effects.name / desc | 4 / 56 | qualities.name | 1 |
| tutorial_steps.name / hint_text / sub_text / button_text / success_text | 4 / 12 / 24 / 4 / 16 | ui_texts.text | 每行 max_chars（渲染后） |

按 1280×720 设计分辨率估算（正文字体 Noto，标题 Ma Shan Zheng，字号以美术 v2 规范为准）：上限按卡片一行约 20–24 字设计，技能/橙装说明 56 字在卡片内不超过3行；名称、按钮、标签必须单行显示，不缩放字号。

### 5.4 引导句 ✔
- tutorial_steps.hint_text 以动词开头，直接说下一步做什么：领取 / 打开 / 学习 / 装配 / 按 / 换上 / 点击 / 击败 / 闪避 / 前往 / 选择 / 拖动 / 升级 / 装备 / 分解。
- 一句只说一个动作；原因放 sub_text。ui_target 第一个“…”与 hint_text 一致，TUT_07 的 小字“…”与 sub_text 一致 ✔（前端现有解析不用改也能拿到新文案）。

### 5.5 数值占位符 ✔
- 语法：`{字段名}` 或 `{字段名:格式}`，字段名为小写英文（正则 `\{([a-z_][a-z0-9_]*)(?::(pct|num|int))?\}`）。
  - 无格式 / `num`：原样数字，去掉末尾多余的0（0.50→0.5，3.0→3）。
  - `pct`：×100 加“%”，最多1位小数（0.08→8%，0.125→12.5%）。
  - `int`：四舍五入取整。
- 取值来源：skills.desc_tpl → **skill_levels 当前等级行**（damage_coef/cd_s/effect_value/effect2_value/chain_count），skill_levels 没有的字段（hits/duration_s/tick_interval_s/chain_decay/effect_duration_s）取 skills 行；orange_effects.desc_tpl → 本行 param1~3 / internal_cd_s；boss_attacks.desc_tpl → 本行字段；tutorial success_text → 本行 reward_count；ui_texts → placeholders 列声明的来源。
- desc_tpl 与 desc 里不得写死数字 ✔（意象里的“三”“九”可用汉字）；desc 列 = 模板按1级（或本行）渲染结果 ✔，作为不支持模板时的兜底。
- 渲染参考实现：`tools/common.py` 的 `render_tpl()`；前端用同一规则即可，字段缺失时显示占位符原文并打警告。

### 5.6 与 UI 表现相关的表字段（PRINCIPLES 衍生要求）
- 颜色分工 ✔：`qualities.color` / `gongfa.color` 是**文字色**（墨底 #232C25 对比度 ≥4.5）；`qualities.beam_color` / `gongfa.fx_color` 是光柱/特效色，严格用美术 v2 规范值。
- 图标键 ✔：`icon` 列统一 `ui_icon_<类>_<id小写>`（gongfa/skill/book/item/equip），美术按键名出图，缺图时前端显示功法色水墨圆点占位。
- 反馈文案入表：横幅、飘字、按钮、Toast、离线收益标题全部走 ui_texts，不在代码里写死中文；首领倒计时、波次等数字由前端拼进占位符。
- 预警 ✔（v5.1）：颜色只取美术 v2 规范两色，按地图配置（青竹山朱砂 #B8382C，雷泽谷/玄岩洞预警白 #F4F1EA），加暗色外描边与 15% 填充；玩家可见文案统一称“预警”“预警区域”，不用颜色指代。
- 图标清单 ✔（v5.1）：`design/icon_list.csv` 汇总全部 icon 键与按键图标（空格、Q、1–4），给美术出图用。
- 首领危险招式间隔 ✔（BUG-005）：任意两次危险判定 ≥ DODGE_COOLDOWN + DANGER_MIN_GAP_MARGIN_S，保证“看得见、躲得开”。

# 配置表变更记录

## v5.1 — 2026-10-11（小修订：预警色按地图配置、图标清单）

改法同前：只改 `tools/gen_tables.py`，重新生成；`validate.py` 0 错误（26 张表、613 行）。数值未改，balance 结果不变（未重跑，无需重跑）。

### 一、预警色（以美术 v2 规范 `art/final/style_guide.md` 为唯一来源，按美术实测定案）
| 文件 | 字段 | 改动 |
|---|---|---|
| `constants.csv` | `TELEGRAPH_DEFAULT_COLOR` | #C8312B → **#B8382C**（朱砂）；desc 写明取色优先级 |
| `constants.csv` | `TELEGRAPH_ALT_COLOR` | #FFFFFF → **#F4F1EA**（预警白） |
| `constants.csv` | 新增4行 | `TELEGRAPH_OUTLINE_PX=2`、`TELEGRAPH_OUTLINE_COLOR=#1C1E21`、`TELEGRAPH_OUTLINE_ALPHA=0.6`、`TELEGRAPH_FILL_ALPHA=0.15` |
| `maps.csv` | 追加列 `telegraph_color` | MAP_QINGZHU #B8382C；MAP_LEIZE、MAP_XUANYAN #F4F1EA |
| `boss_attacks.csv` | `telegraph_color` | 危险招式显式写入所属地图色：竹魅竹刺/竹叶 #B8382C；夔牛践踏/三连、岩魔冲撞/地裂/**玄岩天坠** #F4F1EA；普攻仍为空 |
| `boss_attacks.csv` | `BA_ZHUMEI_THORN.desc/desc_tpl` | “见朱痕即闪” → “见预警即闪” |
| `tutorial_steps.csv` | `TUT_06_BOSS.hint_text/ui_target` | “按空格躲开朱红预警” → “按空格躲开预警区域”；`TUT_07.ui_target` 去掉“朱砂”描述 |

- 取色优先级：boss_attacks.telegraph_color（非空）→ maps.telegraph_color → TELEGRAPH_DEFAULT_COLOR；玩家设置“统一预警白”时用 TELEGRAPH_ALT_COLOR。招式色已显式填好，前端现有“招式色非空就用”的逻辑不改即可生效。
- 文案：预警按地图变色，玩家可见文案一律称“预警”“预警区域”，不再用颜色指代；validate 禁用词新增 朱红/朱痕/红圈/白圈/红框/白框。
- 对比度顺手核对（WCAG 亮度对比，图形标准 3:1）：雷泽谷预警白对地图色 5.75 / 13.59；玄岩洞预警白对焦褐岩 12.01、对熔岩高光 2.60（外描边对熔岩 2.93，线对外描边 7.63）；青竹山朱砂对地图色 1.76 / 1.43、对实际背景战斗带中位色 2.84，主要靠色相（红对灰绿）与外描边区分。以美术实测为准。

### 二、图标清单
- 新文件 `design/icon_list.csv`（icon_key, category, refs, name, prompt, size），由 gen_tables.py 从各表 icon 列汇总并加按键图标，去重后 54 个：功法 3、技能 15、技能书 3（同功法共用书皮）、货币材料 6、装备 21、按键 6（空格、Q、1–4）。
- validate.py：icon_list 与各表 icon 列逐个比对（不多不少、refs 一致、字段非空、命名规范），按键图标必须齐全。

### 三、validate.py 新增
- TELEGRAPH_DEFAULT/ALT_COLOR 必须等于美术规范 #B8382C / #F4F1EA；外描边/填充常量存在且取值合法；maps.telegraph_color 只能取这两个值；危险招式颜色为空或等于所属地图色；普攻不得有预警色。
- 图标清单一致性（见上）。负向测试：删一行按键图标、把地图色改成 #FFFFFF，均能报错。

### 四、给前端/测试
- 前端：`telegraph.gd` 绘制外描边（2px #1C1E21 60%）与内部填充（预警色 15%）；代码兜底色 #C8312B/#FFFFFF（telegraph.gd 第18、33行，game_data.gd 第182–183行）改为 #B8382C/#F4F1EA；如需支持“招式色留空取地图色”，在 game_data.gd 取色处加一层 maps.telegraph_color；maps.csv 读入新列；同步 game/design/data 副本。
- 测试：青竹山三关首领预警为朱砂，雷泽谷、玄岩洞（含天坠全场预警）为预警白；外描边与填充可见；设置切换预警白后全图统一；TUT_06 提示为“按空格躲开预警区域”。

## v5 — 2026-10-11（2-5 首领血量回调、全量文案打磨、BUG-005 首领危险招式间隔）

改法同前：先改 `tools/gen_tables.py`，再重新生成；`validate.py` 0 错误（26 张表、609 行）；`balance.py` 已重跑。**所有 ID 与原有字段名不变**，新增内容全部是追加列或新表。

结果：主线 **58.4 分钟**（v4 58.3；青竹山 23.2｜雷泽谷 21.1｜玄岩洞 14.1）。2-5 首领（限时口径，不含登场）：纯玄罡诀 46 秒（45.6）、纯飞剑 37、纯御雷 44；2-3/2-4/2-5 纯玄罡 37/40/46 秒，逐关递增。BUG-005 后玄岩天坠改在首领出现后 20/40/60 秒，纯飞剑/纯御雷自动挂机在 3-4/3-5 由 15 秒阵亡变为 20 秒阵亡（仍需手动闪避），带护盾的飞剑配置由“自动临界”变为“自动可过”。

### 一、数值
| 文件 | 改动 |
|---|---|
| `levels.csv` | `LV_2_5.boss_hp_mult` 0.80 → **0.82**（攻击倍率不变）。雷泽谷首领血量倍率 0.40/0.52/0.67/0.74/0.82，仍逐关递增 |
| `boss_attacks.csv`（BUG-005） | `BA_ZHUMEI_LEAF` first_cast_s 6→**8**、cd_s 12→**16**、damage_coef 2.5→**3.3**；`BA_KUINIU_BOLTS` 6→**8.5**、12→**18**、1.6→**2.4**；`BA_YANMO_QUAKE` 6.5→**10**、13→**20**、2.2→**3.4**；`BA_YANMO_SKYFALL` first_cast_s 15→**20**（cd 20 不变）。其余招式不变。系数按冷却比例上调，危险伤害/秒基本不变 |
| `constants.csv` | 新增 `DANGER_MIN_GAP_MARGIN_S=0.5`（危险招式判定最小间隔 = DODGE_COOLDOWN + 本值）、`BOSS_MULTI_AREA_INTERVAL=0.4`（与前端代码默认相同，前端读表覆盖后行为不变） |

### 二、BUG-005（qa/bug_report.md）
- 原因：前端 boss.gd 排招为“就绪即放、同时只有一个预警、计时器从实际释放时刻重置”。v4 各危险招式冷却互不整除（岩魔 10/13/20），几轮后会撞到一起：3-4/3-5 地裂末段判定 33.72 秒 → 天坠 35.78 秒只隔 2.06 秒，另有冲撞紧跟天坠 0.8 秒等；竹魅 1-3~1-5、夔牛 2-3~2-5 也有 0.8–2.0 秒的间隔。
- 修改：改成固定节拍（竹魅每4秒一招交替；夔牛践踏9秒一次、三连插在两次践踏正中；岩魔 冲撞5/地裂10/冲撞15/天坠20 循环）。60 秒内最小间隔：竹魅 3.9 秒、夔牛 4.0 秒、岩魔 4.6 秒，全部 ≥ 3.5 秒。时间轴见 README 3.7。
- 校验：`validate.py` 新增“危险招式间隔”检查——`tools/common.py` 的 `danger_schedule()` 以 60 帧/秒逐帧复刻 boss.gd 排招（含多段招式 0.4 秒间隔、严格 `<= 0` 判定导致的浮点晚1帧），模拟全部15关首领出现后60秒，并对危险招式优先顺序做全排列，任意相邻两次危险判定间隔 < DODGE_COOLDOWN + DANGER_MIN_GAP_MARGIN_S 即报错。用 v4 数据回测报出 41 处，其中 LV_3_4 “BA_YANMO_QUAKE（末段判定 33.72 秒）→ BA_YANMO_SKYFALL（判定 35.80 秒）只隔 2.08 秒”即 BUG-005（QA 日志 2.06 秒，差1帧）；模拟的释放时刻 5.02/6.52/15.00/19.52/32.52/35.00/45.52/46.73/55.00/56.73/58.52 与 QA 日志一致。
- 文案同步：`TUT_07_SKYFALL_DODGE.trigger` “第15秒”→“首领出现后第20秒”；`BA_YANMO_QUAKE` 说明修正（原写“玩家脚下及其前方”与 offset_x=0 不符，实际是两段都锁定玩家当时位置）。

### 三、文案（按 PRINCIPLES.md 第一条“精致的成品，好看的 UI”）
- 14 张表约 126 处上屏文案改写：gongfa、skills、skill_books、enemies、boss_attacks、maps、levels、realms、materials、equip_slots、equip_bases、affixes、orange_effects、tutorial_steps；另新增 ui_texts.csv 45 条。
- 统一古风语感与术语（灵石/修为/功法/技能书/悟道残页/炼器材料/首领/近身攻击/概率/朱红预警），去掉 Boss/CD/HP/系数/效果值/“1-2”等系统话；按键写“按 X”，按钮写【按钮名】。
- 改名：槽位 冠→头冠、鞋→鞋履；词条 攻击%→攻击加成、生命%→生命加成、攻速→攻击速度、雷伤→御雷诀伤害；招式 竹刺突→竹刺破土。
- 示例：
  - 护体 desc：“获得最大生命×（效果值）的护盾，持续6秒。护盾存在期间：反伤比例额外+（效果2）…” → “凝罡护体，获得最大生命8%的护盾，持续6秒；其间反伤提高30%，受近身攻击时反震攻击60%的伤害。”（模板 `{effect_value:pct}` 等）
  - LV_1_1 desc：“青竹山第1关” → “竹径清幽，初试身手。”
  - TUT_06 提示：“红色区域0.8秒后受击，按空格闪避” → “按空格躲开朱红预警”
  - 《连环剑》获取：“青竹山1-2首通保底；青竹山首领概率掉落” → “青竹山第2关首通必得；竹魅掉落”
  - 回退提示（原 battle.gd 写死）：“当前配置难以稳定通过X，已回到Y挂机（调整配置或手动挑战可解除）” → 横幅“暂难稳过{failed_level_name}，退守{to_level_name}”+小字“换配置、升技能或点【挑战】可再战”

### 四、给前端的变更清单
| 文件 | 改动 | 前端要做的 |
|---|---|---|
| `ui_texts.csv` | **新表**（key,text,placeholders,max_chars,context） | 加入 game_data.gd 的 TABLE_NAMES；横幅/飘字/HUD/按钮/Toast/离线文案改从此表取，按 placeholders 填值（替换 battle.gd 第329行附近写死的回退提示等） |
| `skills.csv` | 追加 `desc_tpl`、`note`、`icon`；desc 改为1级渲染文案 | 技能详情按**当前等级**渲染 desc_tpl（skill_levels 行覆盖 skills 行同名字段）；不支持时可先用 desc |
| `orange_effects.csv`、`boss_attacks.csv` | 追加 `desc_tpl`、`note` | 同上（取本行字段） |
| `gongfa.csv` | 追加 `note`、`icon`、`fx_color`；`color` 改为文字色 | 文字用 color，技能特效用 fx_color |
| `qualities.csv` | 追加 `beam_color`；`color` 改为文字色 | 光柱/品质框用 beam_color，品质名文字用 color |
| `enemies/maps/levels/realms` | 追加 `note`；desc 改为上屏短句 | 原来如果显示过 desc，内容已变成玩家文案；技术说明在 note |
| `materials/equip_bases` | 追加 `note`、`icon` | 图标按 icon 键加载 |
| `skill_books.csv` | 追加 `icon`；source_desc 改写 | — |
| `tutorial_steps.csv` | 追加 `hint_text`、`sub_text`、`button_text`、`success_text`；ui_target 第一个“…”= hint_text | 建议 tutorial_service.gd 改读 hint_text/sub_text（现解析方式仍能拿到同样文字）；success_text 中 {reward_count} 取本行 reward_count |
| `equip_slots/affixes` | name 改写 | 直接生效 |
| 占位符规则 | `{field}` / `{field:pct}`（×100加%，最多1位小数）/ `{field:num}`（去末尾0）/ `{field:int}`（取整） | 参考 `tools/common.py` 的 `render_tpl()`；详见 README 5.5 |
| 危险招式节奏 | 见第一、二部分 | 无需改代码；建议加运行时最小间隔保护（README 第4节） |
| 数据副本 | — | 前端若有 game/design/data 副本，需同步本版 CSV |

### 五、工具与文档
- `tools/gen_tables.py`：COPY 文案表 + `apply_copy()`（旧 desc→note、desc_tpl 渲染、icon 生成）；ui_texts、tutorial 新列；颜色分工；书籍获取途径自动生成；BUG-005 节奏；2 个新常量。
- `tools/common.py`：`render_tpl()` 占位符渲染；`danger_schedule()` / `danger_gap_violations()` 排招模拟。
- `tools/validate.py`：文案检查（长度上限、禁用词、半角标点、desc 不写死数字、desc=模板渲染、句号结尾、icon 命名、build_dir 用词条名、同类名称唯一、引导句动词开头、ui_target 与 hint_text 一致、ui_texts 占位符声明/来源/渲染后长度、文字色对比度≥4.5）；危险招式间隔检查（BUG-005）。
- `README.md`：新增第5节『文案规范』与 3.20 ui_texts；各表新增列说明；3.7 增加危险招式节奏表；天坠时刻改为 20/40/60。
- `balance.md`：按 v5 重算（2-5 倍率、天坠时刻）。

## v4 — 2026-10-11（小修订：反伤防御定案、操作规则对齐前端、节奏常量入表）

改法同前：先改 `tools/gen_tables.py`，再重新生成；`validate.py` 0 错误；`balance.py` 已重跑。数据表只有 `constants.csv`、`tutorial_steps.csv` 两张有变化，**关卡/怪物/技能等数值都没改**。

结果：主线 56.7 → **58.3 分钟**（青竹山 22.6→23.2｜雷泽谷 20.3→21.1｜玄岩洞 13.8→14.1）。全部来自估算口径对齐前端：每轮结算展示2秒、补刷时固定节奏不打折、行进/接敌按前端流程计算。首领耗时改为与60秒限时同口径（从首领出现算起，不含登场3秒），所以 2-5 纯玄罡诀显示为 44 秒（v3 口径 47 秒），战斗本身没有变化。

### 一、数据表（data/*.csv）—— 前端/程序需要关注

| 文件 | 改动类型 | 具体改动 |
|---|---|---|
| `constants.csv` | 新增2行 | `REFLECT_IGNORE_DEF=0`、`COUNTER_IGNORE_DEF=0`（开关）：反伤、护体反震都**吃攻击者防御**，与前端现有实现一致，前端无需改动；改为1时跳过防御减伤。公式见 README 第4节 |
| `constants.csv` | 新增7行（与前端代码同名，值=前端代码默认值） | `RUN_START_WALK_TIME=1.0`、`SPAWN_DISTANCE_PX=760`、`BOSS_SPAWN_DISTANCE_PX=560`、`AUTO_ENGAGE_RANGE_PX=450`、`BOSS_INTRO_TIME=3.0`、`RESULT_SHOW_TIME=2.0`、`AUTO_SHIELD_RESERVE_CD=12`。前端已支持读表覆盖，行为不变 |
| `constants.csv` | 修改 desc | `WAVE_ENTER_WALK_TIME`（值仍为3.0）写明“最后一波后直接首领登场”；`AUTO_FAIL_RETREAT_RESET_ON`（值不变）写明 manual_clear=玩家点【挑战】发起并通关，无论中途是否切过自动 |
| `tutorial_steps.csv` | 修改1格 | `TUT_07_SKYFALL_DODGE.ui_target` 自动模式小字改为“闪避会切到手动，点【自动战斗】或按 Q 恢复” |

### 二、前端/程序行为（确认，无新增需求）
1. 反伤/反震吃防御：维持现状（`enemy.take_damage` 统一走防御减伤）。
2. 自动/手动切换：空格/闪避按钮/左右移动切手动；技能键1-4不切；点【自动战斗】或按 Q 切回；自动模式不自己闪避。README 第4节已按此写明。
3. 回退标记清除：玩家点【挑战】按钮发起该关并通关即清除，无论中途是否切过自动；系统自动发起的挂机轮不算。
4. 节奏常量：前端读 constants 覆盖代码默认值，现在表里的值等于代码默认值，行为不变。之后调节奏只改表，balance.py 同步生效。

### 三、工具与文档
- `tools/gen_tables.py`：新增上述 9 个常量，更新 2 条 desc 和 TUT_07 文案。
- `tools/balance.py`：
  - 删除 ASSUME 中的 WALK_PER_WAVE / SPAWN_STAGGER / BOSS_INTRO / SHIELD_HOLD_MIN_CD，改从 constants 读取，缺常量直接报错。
  - 清怪 = 开局前进1秒 + 波间前进3秒×3 + 各波 [击杀 + 接敌 + 本波最大 spawn_delay_s]，其中接敌 = (刷怪距离 − 450) / (220 + 最快敌速)。
  - 首领 = 接敌 + 击杀，不含登场3秒，与限时同口径。每关另计登场3秒 + 结算2秒，报表新增列 `show_s`。
  - 补刷每轮 = 击杀×0.85 + 固定节奏（v3 为整轮×0.85）。
  - 支持 REFLECT_/COUNTER_IGNORE_DEF 开关。试算两者都改为1：主线不变；终关纯玄罡首领 46→43 秒。
  - 天坠对比表新增“自动临界”档：自动存活比首领耗时多不到10%。
- `tools/validate.py`：校验两个开关只能是0/1；9个节奏常量必须存在且非负；接敌距离≥普攻射程；刷怪距离>普攻射程。
- `README.md`：3.1 增加节奏常量表；第4节写明反伤/反震公式、自动/手动切换规则、manual_clear 定义；TUT_07 文案同步。
- `balance.md`：耗时公式、结论、分段与构成、三流派表、天坠表全部按 v4 重算。

## v3 — 2026-10-11（制作人对两个风险的决定）

改法同 v2：先改 `tools/gen_tables.py`，再重新生成全部 CSV；`tools/validate.py` 0 错误，`tools/balance.py` 已重跑。只有3张表有变化：constants、levels、tutorial_steps。

结果：主线 57.5 → **56.7 分钟**（青竹山 22.6 不变｜雷泽谷 21.1 → 20.3｜玄岩洞 13.8 不变）。2-5 首领耗时：飞剑 38 秒（v2 47）、御雷 46 秒（v2 56）、纯玄罡 **47 秒**（v2 58）。

### 一、数据表（data/*.csv）—— 前端/程序需要关注

| 文件 | 改动类型 | 具体改动 |
|---|---|---|
| `constants.csv` | 新增2行 | `AUTO_FAIL_RETREAT_COUNT=1`（次）：自动模式同一关连续失败达到该次数，就标记该关“当前配置不稳定”，并回退挂机；`AUTO_FAIL_RETREAT_RESET_ON=loadout_change\|skill_level_up\|realm_up\|manual_clear`（枚举，清除标记的时机） |
| `constants.csv` | 修改 desc | `FAIL_RETURN_POLICY` 的值不变，desc 末尾加“自动模式另见AUTO_FAIL_RETREAT_*” |
| `levels.csv` | 修改 | `LV_2_4.boss_hp_mult` 0.84→**0.74**；`LV_2_5.boss_hp_mult` 1.0→**0.80**；boss_atk_mult 不变（0.84 / 1.0）。雷泽谷首领血量倍率 0.40/0.52/0.67/0.74/0.80，仍逐关递增 |
| `tutorial_steps.csv` | **新增5列** | `category`（main / contextual）、`trigger_ref_ids`（`\|`分隔的ID）、`time_scale`（0=暂停，1=正常，0~1=慢放）、`time_scale_duration_s`（0=整个提示期间）、`max_show_count`。列顺序见文件表头。TUT_01–06 的原有字段值不变，新列都已补值（main；TUT_06 为 0.5 倍慢放 0.8 秒，其余 0 或 1；max_show_count 都是 1） |
| `tutorial_steps.csv` | **新增1行** | `TUT_07_SKYFALL_DODGE` 天坠闪避：category=contextual；trigger_ref_ids=`BA_YANMO_SKYFALL\|LV_3_4`；天坠预警第一次出现时触发（自动/手动都触发）；UI 是屏幕中央“按空格闪避！”+【闪避】按钮高亮；不暂停，time_scale=0.3、time_scale_duration_s=0.8；完成条件是预警结束时处于闪避免伤中；max_show_count=3；reward_type=none；block_input=false |

### 二、前端/程序行为变更
1. **自动挂机失败回退**（确切规则见 README 第4节）：自动模式下在关卡X失败1次（死亡或首领超时）→ X 标记为“不稳定”→ 立即回到“已通关且未被标记”的最高关卡继续自动挂机。换技能/被动/装备（含重铸）、技能升级、突破时清除所有标记；手动通关X时清除X的标记。标记与计数写存档。手动模式失败仍按原规则，不计数。离线收益不受影响。回退时给一行提示。
2. **天坠保留“首通必须手动闪避”**：无护盾配置自动挂机过不了 3-4/3-5，由规则1避免反复死亡。
3. **新手引导支持情境步骤**：category=contextual 的步骤不参与主线顺序，满足 trigger 就插入；按 time_scale / time_scale_duration_s 做暂停或慢放（慢放期间输入照常响应）；按 max_show_count 限制提示次数，到次数视为完成。
4. TUT_07 只播提示，没有奖励（reward_type=none）。

### 三、工具与文档
- `tools/gen_tables.py`：新增 AUTO_FAIL_RETREAT_* 常量；新增 LV24/LV25_BOSS_HP_MULT 并写入 BOSS_HP_OVERRIDE；tutorial 生成新增5列和 TUT_07。
- `tools/validate.py`：引导检查同步更新——order 必须是从1开始的连续编号；main 步骤按“领书→学习→装配→释放→换装→首领”排列；category 只能是 main/contextual；校验 reward_type 枚举，none 时引用为空、数量为0；time_scale 在 0–1，duration≥0，max_show_count≥1；trigger_ref_ids 引用必须存在，引用的 BA_ 必须是危险攻击；**每个 true_maxhp 类危险攻击都必须有引导步骤引用它**（已做反向测试：删掉 TUT_07 会报错）；“基础书由引导发放”的检查改为汇总全部 book 奖励步骤。
- `tools/balance.py`：未改代码，只重跑。
- `README.md`（3.1 关键常量、3.9 boss_hp_mult、3.18 引导字段与 TUT_07、第4节回退规则）、`balance.md`（结论、分段、构成、风险说明）同步更新。

## v2 — 2026-10-11（按用户已确认的9条决策修订）

改法：先改源头 `tools/gen_tables.py`，再重新生成全部 CSV；`tools/validate.py` 0 错误，`tools/balance.py` 已重跑（`balance_report.csv`、`balance.md` 已更新）。

### 一、数据表（data/*.csv）—— 前端/程序需要关注

| 文件 | 改动类型 | 具体改动 |
|---|---|---|
| `boss_attacks.csv` | **新增5列** | `damage_type`（`atk_coef` / `true_maxhp`）、`damage_maxhp_pct`、`first_cast_s`（开战后首次释放秒数）、`telegraph_color`（危险攻击默认 `#C8312B` 朱砂，普攻为空）、`telegraph_style`（`dashed` 默认 / `solid`；普攻为空）。列顺序见文件表头 |
| `boss_attacks.csv` | **新增1行** | `BA_YANMO_SKYFALL` 玄岩天坠：is_danger=true，warn_s=0.8，shape=rect，**anchor=arena（新枚举：覆盖全场）**，1280×720，damage_type=true_maxhp，damage_maxhp_pct=0.7，cd_s=20，first_cast_s=15，min_level_index=4，朱砂虚线 |
| `enemies.csv` | 修改 | `BOSS_YANMO.behavior_param` 的 attack_ids 追加 `BA_YANMO_SKYFALL`；desc 更新 |
| `constants.csv` | 新增4行 | `TELEGRAPH_DEFAULT_COLOR=#C8312B`、`TELEGRAPH_ALT_COLOR=#FFFFFF`、`TELEGRAPH_DEFAULT_STYLE=dashed`、`REFLECT_COUNTER_ICD=0.8`（护体反震全局内置间隔，秒） |
| `skills.csv` | 修改 `SK_GANG_GUARD` 护体 | effect2_type `shield_dmg_bonus` → **`reflect_add`**（护盾期间额外反伤）；effect2_value 0.25→0.30，effect2_growth 0.015→0.02；damage_coef 0→**0.6（反震系数）**，coef_growth 0→0.10，max_targets/hits 0→1；desc 重写。**`shield_dmg_bonus` 枚举已废弃，代码中可删除** |
| `skills.csv` | 修改（补偿护体去掉增伤后玄罡的输出） | `SK_GANG_QUAKE` damage_coef 1.8→2.2；`SK_GANG_GALE` 0.45→0.55；`SK_GANG_VAJRA` 5.0→6.0 |
| `skill_levels.csv` | 随上表重算 | 护体 1–10级：damage_coef 0.6→1.14、effect2_value 0.30→0.48（护盾值、冷却、费用不变）；震岳/罡风/金刚不坏 damage_coef 全等级同比例上调 |
| `first_clear_rewards.csv` | 新增3行、删1行 | +`FC_LV_1_5` seq4 book `BK_SWORD_EXECUTE`；+`FC_LV_2_5` seq4 book `BK_THUNDER_NINE`；+`FC_LV_3_5` seq4 book `BK_GANG_VAJRA`；−`FC_LV_3_5` seq5 material `MAT_BT_XUANYAN` |
| `skill_books.csv` | 修改 source_desc | 诛仙剑/九霄神雷/金刚不坏 增加“X-5首通保底” |
| `levels.csv` | 修改 | `LV_3_4.boss_hp_mult` 0.84→0.72；`LV_3_5.boss_hp_mult` 1.0→0.78（boss_atk_mult 不变）。纯玄罡诀终关首领约48秒；3-4同步下调，保持逐关递增 |
| `maps.csv` | 修改 | `MAP_XUANYAN.breakthrough_mat_id` `MAT_BT_XUANYAN` → 空 |
| `materials.csv` | 删除1行 | `MAT_BT_XUANYAN` 玄岩金精（全部引用已清除） |
| 其他表 | 未改 | 橙装来源/概率、离线50%/8小时、开局白武器白衣袍、1-1第2波绿武器、每关打本区域首领（前4关削弱）均保持不变 |

### 二、前端/程序行为变更
1. **首领预警绘制**：读 `telegraph_color` / `telegraph_style`；设置项可整体切到 `TELEGRAPH_ALT_COLOR`（白色）。
2. **anchor=arena**：预警铺满战场可见区域，走位无法躲开，只能闪避免伤或护盾吸收。
3. **true_maxhp 伤害**：玩家最大生命×比例，无视防御与一切减伤，先扣护盾，不触发反伤/反震。
4. **护体（v2）**：护盾期间不再增伤；改为反伤比例额外+effect2_value，且每受一次近战/接触攻击对攻击者反震 攻击×damage_coef（不暴击，全局0.8秒内置间隔）。UI 文案按 skills.desc。
5. **自动护盾AI**：护体按冷却释放；冷却≥12秒的护盾（金刚不坏）为玄岩天坠预留——预警期间可用就立刻释放，否则只在“冷却好之前不会撞上下次天坠预警”时才释放。
6. **首通奖励**：每张地图第5关首通多给1本终极技能书；玄岩洞第5关不再给突破材料。
7. 功法面板“未学习技能的获取来源”文案随 skill_books.source_desc 更新。

### 三、工具与文档
- `tools/gen_tables.py`：新增 SKYFALL_* / TELEGRAPH_* / LV35_BOSS_HP_MULT / BOSS_HP_OVERRIDE；FIRST_BOOK 增加第5关；地图无突破材料时不生成材料奖励。
- `tools/validate.py`：最后一张地图允许 breakthrough_mat_id 为空。
- `tools/balance.py`：护体增伤→反震+反伤；生存模型改为0.1秒步长模拟（含 true_maxhp 离散伤害、护盾AI）；三流派对比把玄罡反震/反伤计入单体与5目标DPS；新增“玄岩天坠：自动 vs 手动 vs 护盾”表；技能组合选择改成确定性排序。
- `README.md`、`balance.md` 同步更新。

## v1 — 2026-10-11
首版配置表。

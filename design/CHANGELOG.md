# 配置表变更记录

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

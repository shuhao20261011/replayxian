# 重走修仙路（replayxian）

> **项目核心准则：[docs/PRINCIPLES.md](docs/PRINCIPLES.md)**（精致的成品，好看的 UI）

国风剪影横版修仙挂机刷宝游戏。Godot **4.7.2 stable** + GDScript，Compatibility 渲染器，基准 1280×720（`canvas_items` + `expand`，可缩放），键鼠操作。

- 开发计划：`docs/dev_plan.md`（本 PR 范围：准备工作 + 第10节 阶段1、阶段2）
- 美术规格：`docs/style_guide.md`；战斗界面布局参考 `docs/07_battle_ui_mockup.png`
- 策划配置表：`design/`（`design/README.md` 字段说明，`design/CHANGELOG.md` 变更记录，`design/data/*.csv` 25 张表）

## 运行

```bash
godot --path .                      # 编辑器外直接运行（Windows: Godot_v4.7.2-stable_win64.exe --path .）
godot -e --path .                   # 打开编辑器
godot --path . -- --level=LV_1_3    # 调试：直接挑战某关；可加 --boss 跳到首领战、--manual 手动开局、--god 无敌
```

操作：A/D 或 ←/→ 移动，1–4 释放技能，空格闪避，Q 切换自动战斗；鼠标可点技能格（下方“自动/手动”标签或右键切换该格自动释放）、闪避、自动开关、挑战、地图（选关）。

## 测试

```bash
./run_tests.sh
# 等价于：godot --headless --path . --import && godot --headless --path . res://tests/test_runner.tscn
# 只跑名字包含某串的用例：godot --headless --path . res://tests/test_runner.tscn -- --only=skyfall
```

`tests/` 下 63 个用例（以 `./run_tests.sh` 输出为准）：配置加载与数据驱动、技能栏规则与冷却、自动/手动切换、闪避免伤、伤害规则（防御、真实伤害、护盾、反伤、护体反震内置间隔）、首领预警与闪避判定、自动护盾AI、天坠情境引导、刷怪→首领→胜利/失败→挂机循环、v3 自动挂机失败回退、面板暂停、默认配置 10 分钟挂机稳定性，以及 QA 第一轮缺陷回归（`tests/test_regressions.gd`：首领节点释放、天坠引导中途结算复位、标记清除后回到最高关、闪避位移/冷却精确、全场预警铺满视口、坐标归零、底栏不裁切等）。运行期出现任何脚本错误都会判该用例失败。战斗逻辑由 `Battle.tick(delta)` 驱动，测试以固定步长确定性推进。

## 文案与配置要点（策划表 v5 / v5.1）

- **上屏文字读表**：横幅、飘字、HUD、按钮、提示文字一律来自 `design/data/ui_texts.csv`（`UiText.t(key, {占位符})`，`scripts/ui/ui_text.gd`）。主表还没有的前端文字暂放 `data/ui_texts_local.csv`（同列结构，待策划收编；主表同名 key 优先，测试会提示重复）。
- **占位符渲染**与 `design/tools/common.py` 的 `render_tpl()` 逐字一致：`{f}`/`{f:num}` 至多2位小数去尾0，`{f:pct}` ×100 至多1位小数加 %，`{f:int}` 四舍五入（恰好一半取偶，同 Python），大数按 Python `%g`。对照用例由 `python3 tools/gen_render_cases.py` 用策划工具生成到 `tests/fixtures/render_tpl_cases.json`（设计表更新后重跑）。技能说明按当前等级渲染 `desc_tpl`（skill_levels 同名字段覆盖 skills），`orange_effects`/`boss_attacks` 取本行。
- **引导文字**直接读 `tutorial_steps.hint_text / sub_text / success_text`（自动模式追加 sub_text，并显示空格键图标）。
- **硬规则：相邻两次危险招式判定间隔 ≥ `DODGE_COOLDOWN + DANGER_MIN_GAP_MARGIN_S`（当前 3.0 + 0.5 = 3.5 秒）**，即后一招首个判定 − 前一招末个判定。节拍由 `boss_attacks.csv` 决定；运行时首领起手前检查“现在 + 预警时长 − 上次危险判定”，不足则推迟释放（掌心雷眩晕等会压缩节拍），首领战剩余时间不足一招预警时不再起手。回归：`test_bug005_danger_gap_guard_after_stun`、QA `qa_bug005`。
- **预警时长**：预警从首领起手的下一帧开始计时，`warn_s`（默认 0.8 秒）在 60 帧/秒下恰好显示 48 帧后判定（BUG-014）。
- **预警取色**：`boss_attacks.telegraph_color` → `maps.telegraph_color` → `TELEGRAPH_DEFAULT_COLOR`；玩家设置“统一预警白”（`PlayerState.telegraph_alt`，写存档）时一律 `TELEGRAPH_ALT_COLOR`。区域填充 = 预警色 × `TELEGRAPH_FILL_ALPHA`，描边外侧加 `TELEGRAPH_OUTLINE_PX` 宽、`TELEGRAPH_OUTLINE_COLOR`×`TELEGRAPH_OUTLINE_ALPHA` 的外描边。
- 颜色分工：`gongfa.color`/`qualities.color` 是文字色，技能特效用 `gongfa.fx_color`，掉落光柱/品质框用 `qualities.beam_color`；图标按各表 `icon` 键加载；`note` 列只给策划看，不上屏。

## Web 导出

`export_presets.cfg` 含 “Web” 预设（单线程 nothreads 模板，无需 COOP/COEP 头，可直接放 GitHub Pages）：

```bash
godot --headless --path . --export-release "Web" build/web/index.html
```

Web 没有系统中文字体，主题默认字体为内嵌的思源黑体子集 `art/fonts/NotoSansSC-Regular-subset.otf`（SIL OFL 1.1，许可见同目录 `OFL-NotoSansSC.txt`）。改动上屏文字后若出现缺字，重跑 `python3 tools/subset_font.py <NotoSansSC-Regular.otf>`（字符集 = 项目全部文本 + GB2312 一级常用字）。构建产物只放 `build/`（已忽略），发布用本地 `gh-pages` 分支。

## Windows 导出

已配置 `export_presets.cfg`（Windows Desktop，x86_64）。需要安装 4.7.2 导出模板：

```bash
godot --headless --path . --export-release "Windows Desktop" build/windows/ReplayXian.exe
```

`design/data/*.csv` 通过 `include_filter` 原样打包（CSV 的 `.import` 设为 `keep`，不会被当成翻译表导入）。

## 目录

```
project.godot             Input Map（move_left/right、dodge、skill_1..4、toggle_auto）、Autoload、显示设置
scenes/main.tscn          入口：Battle + HUD
scenes/battle/            battle.tscn（战斗主场景）、player.tscn、enemy.tscn、boss.tscn
scenes/ui/                hud.tscn、skill_slot.tscn
scripts/autoload/         GameData（读 CSV → Resource）、PlayerState（成长/技能栏/进度/回退标记）
scripts/resources/        每张核心表一个 Resource：SkillDef(+SkillLevelDef)、SkillBookDef、GongfaDef、EnemyDef、
                          BossAttackDef、LevelDef(+WaveDef)、MapDef、RealmDef、EquipBaseDef、QualityDef
scripts/battle/           Battle（状态机/伤害结算）、Player、Enemy、Boss、Telegraph、SkillSystem、
                          PlayerController（输入+自动AI）、SkillFx（技能效果节点）、TutorialService（情境引导）
scripts/ui/               Hud、SkillSlotUI、UiStyle
art/                      占位美术（tools/gen_placeholder_art.py 生成，按 style_guide 尺寸/锚点/命名；正式资源同名覆盖即可）
tests/                    无头测试
```

## 数据驱动

所有数值从 `design/data/*.csv` 读取：常量、技能（形状/射程/系数/冷却/效果）、技能等级、敌人行为参数、首领招式（预警形状/锚点/颜色/样式/伤害类型/首次释放时间/逐关解锁）、关卡倍率、波次、开局装备、情境引导步骤。改表后重启即生效；代码里只保留“表中缺该项时”的兜底默认值。可用 `-- --data-dir=<目录>` 指向另一套表试玩。

以下表现/节奏参数目前不在表中，用代码默认值，如需可直接在 `constants.csv` 增加同名行覆盖：
`GROUND_Y=585`、`SPAWN_DISTANCE_PX=760`、`BOSS_SPAWN_DISTANCE_PX=560`、`RUN_START_WALK_TIME=1.0`、`BOSS_INTRO_TIME=3.0`、`RESULT_SHOW_TIME=2.0`、`BOSS_MULTI_AREA_INTERVAL=0.4`、`AUTO_SHIELD_RESERVE_CD=12`、`AUTO_ENGAGE_RANGE_PX=450`、`PLAYER_BACKTRACK_PX=600`。

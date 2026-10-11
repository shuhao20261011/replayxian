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

`tests/` 下 54 个用例（以 `./run_tests.sh` 输出为准）：配置加载与数据驱动、技能栏规则与冷却、自动/手动切换、闪避免伤、伤害规则（防御、真实伤害、护盾、反伤、护体反震内置间隔）、首领预警与闪避判定、自动护盾AI、天坠情境引导、刷怪→首领→胜利/失败→挂机循环、v3 自动挂机失败回退、面板暂停、默认配置 10 分钟挂机稳定性，以及 QA 第一轮缺陷回归（`tests/test_regressions.gd`：首领节点释放、天坠引导中途结算复位、标记清除后回到最高关、闪避位移/冷却精确、全场预警铺满视口、坐标归零、底栏不裁切等）。运行期出现任何脚本错误都会判该用例失败。战斗逻辑由 `Battle.tick(delta)` 驱动，测试以固定步长确定性推进。

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

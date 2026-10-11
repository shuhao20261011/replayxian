# 重走修仙路（replayxian）

> **项目核心准则：[docs/PRINCIPLES.md](docs/PRINCIPLES.md)**（精致的成品，好看的 UI）

国风剪影横版修仙挂机刷宝游戏。Godot **4.7.2 stable** + GDScript，Compatibility 渲染器，基准 1280×720（`canvas_items` + `expand`，可缩放），键鼠操作。

- 开发计划：`docs/dev_plan.md`（本 PR 范围：准备工作 + 第10节 阶段1、阶段2）
- 美术规格：`docs/style_guide.md`；战斗界面布局参考 `docs/07_battle_ui_mockup.png`
- 策划配置表：`design/`（当前同步到 v5.5；`design/README.md` 字段说明，`design/CHANGELOG.md` 变更记录，`design/data/*.csv`）
- 正式美术：`art/`（第1~3批 + 2.1/3.1 批，规格见 `art/ART_STYLE_GUIDE_final.md`）

## 运行

```bash
godot --path .                      # 编辑器外直接运行（Windows: Godot_v4.7.2-stable_win64.exe --path .）
godot -e --path .                   # 打开编辑器
godot --path . -- --level=LV_1_3    # 调试：直接挑战某关；可加 --boss 跳到首领战、--manual 手动开局、--god 无敌
```

操作：A/D 或 ←/→ 移动，1–4 释放技能，空格闪避，Q 切换自动战斗，Esc 关闭养成面板；鼠标可点技能格（下方“自动/手动”标签或右键切换该格自动释放）、闪避、自动开关、挑战、地图（选关）。

## 测试

```bash
./run_tests.sh
# 等价于：godot --headless --path . --import && godot --headless --path . res://tests/test_runner.tscn
# 只跑名字包含某串的用例：godot --headless --path . res://tests/test_runner.tscn -- --only=skyfall
```

`tests/` 下 126 个用例（以 `./run_tests.sh` 输出为准；另有 `tests/test_art.gd` 正式美术接入：图集/锚点、命中帧结算、首领技能动画、预警参数读表、岩魔冲撞位移）：配置加载与数据驱动、技能栏规则与冷却、自动/手动切换、闪避免伤、伤害规则（防御、真实伤害、护盾、反伤、护体反震内置间隔）、首领预警与闪避判定、自动护盾AI、天坠情境引导、刷怪→首领→胜利/失败→挂机循环、v3 自动挂机失败回退、面板暂停、默认配置 10 分钟挂机稳定性，以及 QA 第一轮缺陷回归（`tests/test_regressions.gd`：首领节点释放、天坠引导中途结算复位、标记清除后回到最高关、闪避位移/冷却精确、全场预警铺满视口、坐标归零、底栏不裁切等）。运行期出现任何脚本错误都会判该用例失败。战斗逻辑由 `Battle.tick(delta)` 驱动，测试以固定步长确定性推进。

## 文案与配置要点（策划表 v5.5）

- **上屏文字读表**：横幅、飘字、HUD、按钮、提示文字一律来自 `design/data/ui_texts.csv`（`UiText.t(key, {占位符})`，`scripts/ui/ui_text.gd`）。主表还没有的前端文字暂放 `data/ui_texts_pending.csv`（同列结构，待策划收编；主表同名 key 优先，测试禁止重复）。
- **占位符渲染**与 `design/tools/common.py` 的 `render_tpl()` 逐字一致：`{f}`/`{f:num}` 至多2位小数去尾0，`{f:pct}` ×100 至多1位小数加 %，`{f:int}` 四舍五入（恰好一半取偶，同 Python），大数按 Python `%g`。对照用例由 `python3 tools/gen_render_cases.py` 用策划工具生成到 `tests/fixtures/render_tpl_cases.json`（设计表更新后重跑）。技能说明按当前等级渲染 `desc_tpl`（skill_levels 同名字段覆盖 skills），`orange_effects`/`boss_attacks` 取本行。
- **引导文字**直接读 `tutorial_steps.hint_text / sub_text / success_text`（自动模式追加 sub_text，并显示空格键图标）。
- **硬规则：相邻两次危险招式判定间隔 ≥ `DODGE_COOLDOWN + DANGER_MIN_GAP_MARGIN_S`（当前 3.0 + 0.5 = 3.5 秒）**，即后一招首个判定 − 前一招末个判定。节拍由 `boss_attacks.csv` 决定；运行时首领起手前检查“现在 + 预警时长 − 上次危险判定”，不足则推迟释放（掌心雷眩晕等会压缩节拍），首领战剩余时间不足一招预警时不再起手。回归：`test_bug005_danger_gap_guard_after_stun`、QA `qa_bug005`。
- **预警时长**：预警从首领起手的下一帧开始计时，`warn_s`（默认 0.8 秒）在 60 帧/秒下恰好显示 48 帧后判定（BUG-014）。
- **预警取色**：`boss_attacks.telegraph_color` → `maps.telegraph_color` → `TELEGRAPH_DEFAULT_COLOR`；玩家设置“统一预警白”（`PlayerState.telegraph_alt`，写存档）时一律 `TELEGRAPH_ALT_COLOR`。绘制参数全部读 `constants.csv`（v5.4/v5.5，README 3.7）：普通预警主线 `TELEGRAPH_LINE_PX` 虚线 `DASH_PX`/`GAP_PX`、外描边 `OUTLINE_PX`×`OUTLINE_ALPHA`、填充 `FILL_ALPHA`、进度内圈 `PROGRESS_FILL_ALPHA`；全场预警 `ARENA_LINE_PX`/`ARENA_DASH_PX`/`ARENA_GAP_PX`/`ARENA_OUTLINE_PX`×`ARENA_OUTLINE_ALPHA`，底色中心 `ARENA_FILL_ALPHA_CENTER`→四边 `ARENA_FILL_ALPHA_EDGE`；闪烁 1.0↔`TELEGRAPH_BLINK_MIN_ALPHA`（0.8 秒 3 次）。地面预警画在 HUD 之上的跟随视口图层，全场预警框内收到 HUD 让出的可见战场区（BUG-015）。“统一预警白”开关在地图面板，默认隐藏，待制作人定稿（项目设置 `xxhbgj/ui/show_telegraph_white_toggle` 或 `-- --telegraph-white-toggle` 打开，BUG-016）。
- **阶段5 境界突破**（`realms.csv`）：下一境界 = `prev_realm_id` 为当前境界的那一行；条件为 `xiuwei_cost` / `lingshi_cost` / `material_id`×`material_count`（x-5 首领首通给的突破材料），成功率 100%、不自动突破；成功后扣除消耗，属性直接替换为新境界基础值，并开放 `unlock_map_id`（关卡另受 `levels.unlock_level_id`/`unlock_realm_id` 约束）。`PlayerState.breakthrough_status()` / `breakthrough()`，结果码 `ok / no_xiuwei / no_lingshi / no_material / max_realm`。“破”面板（`scripts/ui/break_panel.gd`）：当前 / 下一境界属性与增量、条件持有／需要、突破后开放的地图预览；成功后横幅“突破成功·晋入…”→“…已开启”，并弹出地图开放卡片（前往 / 稍后）。可突破时“破”入口亮红点。地图面板按地图分组，未开放标“需某境界”，刚开放且未通关标“新开”。
- **首通奖励**（`first_clear_rewards.csv`）：首通结算时在横幅下弹出首通卡片（`FirstClearCard`，逐项图标 + 品质框，不暂停）。终关首通的 `orange_choice` 行生成三选一：卡片亮相 1.5 秒后弹出“核心橙装　三选一”（`OrangeChoiceDialog`，暂停；“稍后再选”保留在装备面板）。
- **暗图描边**：`CreatureArt.RIM_MAP_KEYS`（雷泽谷 leize、玄岩洞 xuanyan）上的怪物与首领挂 `shaders/creature_rim_dark.tres`：剪影外缘一圈淡纸白描边 + 朝左上光源的轮廓提亮，按 `alpha_threshold` 把半透明笔触转成剪影遮罩，只作用于外缘。可调参数：`outline_color`、`outline_alpha`（0.45）、`outline_width_px`（2，贴图像素）、`rim_color`、`rim_strength`（0.3）、`rim_width_px`（3）、`light_dir`（-0.6,-0.8）、`alpha_threshold`（0.25）。
- **全场预警框让开 HUD**：HUD 每帧把可见的拾取提示、挑战按钮与模式小字、波次/首领名/横幅、引导文字、首通卡片的矩形写入 `Battle.hud_avoid_rects`；全场预警描边在这些矩形（外扩 `Telegraph.AVOID_PAD`=8px）处断开，虚线相位按沿线距离连续。
- 占位符另支持 `{f:raw}`：原样输出、不按数字格式化（版本号里的提交号如 `1234567`、`12e4567`）；策划工具 `render_tpl()` 待同步。
- 颜色分工：`gongfa.color`/`qualities.color` 是文字色，技能特效用 `gongfa.fx_color`，掉落光柱/品质框用 `qualities.beam_color`；图标按各表 `icon` 键加载；`note` 列只给策划看，不上屏。

## Web 导出

`export_presets.cfg` 含 “Web” 预设（单线程 nothreads 模板，无需 COOP/COEP 头，可直接放 GitHub Pages）。**发布用的 Web 包一律用构建脚本**（阶段5 起每个阶段都这样构建）：

```bash
tools/build_web.sh 5                                   # 导出到 build/web/
tools/build_web.sh 5 --pages ../wt-gh-pages stage5 --zip ../builds/replayxian_stage5_web.zip
```

脚本做三件事：
1. **版本号**：导出前写 `build_info.json`（`{"stage","commit","dirty","built_at"}`，已 gitignore，经 `include_filter` 打进 .pck，导出后删除）。游戏左上角境界药丸下方显示小字“阶段5　<短提交号>”（`HUD_BUILD_VERSION`；有未提交改动时提交号后加 `+`）；不经脚本运行时显示“开发版”。QA 截图即可确认版本。
2. **缓存破坏**：`tools/web_cachebust.py` 把导出的 `index.js / .wasm / .pck / 音频 worklet / 图标 / 启动图` 改名为 `index.<提交号>.*`，并改写 `index.html` 中的全部引用（`<script src>`、图标、`GODOT_CONFIG.executable` 与 `fileSizes`；加载器按 executable 推出 .wasm/.pck/worklet 文件名）。每次构建的资源 URL 都不同，GitHub Pages 约 10 分钟的缓存不会拿到旧文件。`index.html` 入口名不变，另写 `version.json` 与 `<meta name="build-version">`。
3. `--pages <目录> <子目录>`：拷到 gh-pages 的 `<子目录>/`，并把首页 `index.html` 中指向该子目录的链接改为 `<子目录>/?v=<提交号>`（入口页本身也绕过缓存）。新阶段先在首页加卡片再跑脚本。

只导出不加版本：`godot --headless --path . --export-release "Web" build/web/index.html`（不建议用于发布）。

Web 没有系统中文字体：项目主题为美术 `art/ui/ui_theme.tres`，字体 Noto Serif SC（正文/数值）、Ma Shan Zheng（标题/圆章单字）、Zhi Mang Xing（副题）均为内嵌子集（SIL OFL 1.1，许可见 `art/fonts/OFL_*.txt`）。改动上屏文字后若缺字，重跑 `tools/subset_fonts.sh`（原版字体取自 `../art/final/fonts`；正文字体另含 GB2312 一级常用字）。截图：`xvfb-run godot --path . res://tools/shot.tscn -- --out=<目录>`。构建产物只放 `build/`（已忽略），发布用本地 `gh-pages` 分支。

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

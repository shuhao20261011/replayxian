# 《重走修仙路》美术规范 · 正式资源版（final）

> 状态：**第 1 批（主角 7 个动作 + 青竹山四层视差 + 书法标题）、第 2 批（6 种普通怪 + 3 个首领图集 + 雷球/竹刺贴图）已出**。风格沿用用户已确认的 v2（`../style/v2/`），本文从 v2 复制后更新。
> 全部资源由 AI 生图原图经 Python 处理得到，脚本在 `src/`，`python3 src/build_all.py` 一键重建（`build_all.py 2` 只重建第 2 批）。生图原图目录记作 `assets/` = `/home/box/agent-data/agents/c452b474-dc96-4e4c-84be-b722b92a0762/assets/`。
> 把本目录的 `characters/`、`enemies/`、`bosses/`、`fx/`、`bg/`、`ui/`、`fonts/` 复制到 Godot 工程的 `res://art/` 下即可（`.tres`/`.tscn` 里的路径按 `res://art/...` 写好了）。

## 0. 文件清单

### 第 1 批文件清单
| 文件 | 说明 |
| --- | --- |
| `characters/hero/chr_hero_{idle_08f,walk_08f,attack_06f,cast_06f,dodge_05f,hit_03f,death_08f}.png` | 主角 7 个动作图集，格 320×192，脚底锚点 (144,184)；8 帧的动作 6+2 换行（1920×384），其余单行 |
| `characters/hero/chr_hero_attack_06f_swordlight.png` | 普攻备选：第 4 帧保留生图里的青色剑光 |
| `characters/hero/chr_hero.tres` | SpriteFrames，含 7 个动作（已用 Godot 4.7.2 headless 加载验证） |
| `bg/qingzhu/bg_qingzhu_far.png` | 远景 1280×720，不透明，左右无缝 |
| `bg/qingzhu/bg_qingzhu_mid.png` | 中景 2560×720，透明，左右无缝 |
| `bg/qingzhu/bg_qingzhu_near.png` | 近景地面 2560×170，放在 y=550，地面顶边在 y=585，左右无缝 |
| `bg/qingzhu/bg_qingzhu_fore.png` | 前景竹长图 2560×720（左右竹丛在 0~1280 两侧，后半段留空），战斗区内已淡出 |
| `bg/qingzhu/bg_qingzhu_fore_01.png`、`_02.png` | 左/右竹丛单独精灵（400×720、452×720），想手动摆放时用 |
| `bg/qingzhu/bg_qingzhu.tscn` | Parallax2D 四层场景（已用 Godot 4.7.2 加载验证） |
| `ui/title_logo.png`、`ui/title_logo_h.png` | 书法标题透明底：竖版（定调图同款，277×938）、横版（1005×272） |
| `fonts/` | MaShanZheng-Regular.ttf、ZhiMangXing-Regular.ttf + 各自 OFL 许可文件 |
| `preview/` | `batch1_preview.png` 总预览、`bg_qingzhu_composite.png` 四层合成、`chr_hero_*.gif` 动作预览（2 倍）、`keyart_calligraphy.png` 书法标题版定调图 |
| `src/` | `fcommon.py` 公共（抠白、校色、分帧）、`make_hero.py`、`make_bg.py`、`make_title.py`、`make_preview.py`、`check_hero.py`（目检拼图）、`build_all.py` |

### 第 2 批文件清单
| 文件 | 说明 |
| --- | --- |
| `enemies/<id>/enm_<id>_{idle_06f,move_06f,attack_06f,hit_03f,death_06f}.png` | 6 种普通怪图集：`bamboo_imp` 竹灵、`mountain_ape` 山魈、`marsh_wisp` 泽灵、`thunder_toad` 雷蟾、`cave_bat` 洞蝠、`rock_golem` 岩傀。格子尺寸按体型定，见 5.1.2 |
| `enemies/<id>/enm_<id>.tres` | 每种普通怪一个 SpriteFrames（5 个动作） |
| `bosses/zhumei/boss_zhumei_{idle_06f,move_08f,attack_08f,skill_thorn_08f,skill_leaf_08f,hit_03f,death_08f}.png` + `boss_zhumei.tres` | 竹魅：竹刺突 `skill_thorn`、竹叶旋风 `skill_leaf` |
| `bosses/kuiniu/boss_kuiniu_{idle_06f,move_08f,attack_08f,skill_stomp_08f,hit_03f,death_08f}.png` + `boss_kuiniu.tres` | 夔牛：雷霆践踏 `skill_stomp`；天雷三连 `skill_bolts` 是 .tres 里的别名动画（复用践踏图集） |
| `bosses/yanmo/boss_yanmo_{idle_06f,move_08f,attack_08f,skill_charge_08f,skill_skyfall_08f,hit_03f,death_08f}.png` + `boss_yanmo.tres` | 岩魔：碎岩冲撞 `skill_charge`、玄岩天坠 `skill_skyfall`；地裂 `skill_quake` 是 .tres 里的别名动画（复用岩拳图集） |
| `fx/fx_toad_orb.png` | 雷蟾弹道雷球 91×79（从攻击行的独立雷球切出，按雷蟾同比例缩放，朝左飞） |
| `fx/fx_zhumei_thorn_02f.png` | 竹魅竹刺破土 2 帧，单帧 320×352，底部锚点 (160,344)，沿竹刺突预警长条摆放 |
| `preview/batch2_preview.png` | 实际比例阵容（青竹山背景，与主角同一地平线）+ 每种怪的全部帧（金框＝攻击命中帧，朱砂框＝前摇定格帧） |
| `preview/batch2_lineup.png` | 只有阵容那一段（2560×720） |
| `src/` 新增 | `enemy_sheets.py`（原图登记：行数、每行帧数、岩傀标签裁切）、`make_enemies.py`（抠图/分帧/定尺寸/图集/.tres/fx）、`make_preview2.py`、`check_enemies.py`（目检拼图）、`debug_split.py`（分帧框选图）；`fcommon.py` 新增 `key_glow`、`row_bands`、`split_row`（第 1 批函数未改） |

### 第 3 批文件清单
| 路径（相对 final/） | 说明 |
| --- | --- |
| `bg/leize/bg_leize_{far,mid,near,fore}.png`、`bg_leize_fore_01/02.png`、`bg_leize.tscn` | 雷泽谷四层视差（远 1280×720 不透明；中 2560×720；近 2560×195，放 y=525；前 2560×720 + 两个单件枯树/芦苇精灵） |
| `bg/xuanyan/bg_xuanyan_{far,mid,near,fore}.png`、`bg_xuanyan_fore_01/02.png`、`bg_xuanyan.tscn` | 玄岩洞四层视差（远景取中段去暗框后重建无缝；近 2560×145 放 y=575，底部已补齐到 720） |
| `fx/fx_sword_body.png`、`fx_sword_trail.png`、`fx_sword_trail_grad.png`、`fx_sword_trail_gradient.tres`、`fx_sword_slash_06f.png`、`fx_sword_hit_06f.png` | 飞剑剑体、拖尾纹理与渐变、剑气弧 6f、命中火花 6f |
| `fx/fx_thunder_glow.png`、`fx_thunder_strike_06f.png`、`fx_thunder_ground_06f.png` | 雷电光晕、落雷 6f、雷击地爆 6f |
| `fx/fx_shield_ring.png`、`fx_shield_sphere.png`、`fx_shield_hit_04f.png`、`shield_fx.tscn/.gd` | 八卦符环、护盾球、护盾受击 4f、护盾组合场景 |
| `fx/fx_loot_beam.png`、`fx_loot_base.png`、`fx_loot_particle.png`、`fx_loot_rays.png`、`loot_beam.tscn/.gd` | 白色通用光柱 / 底座 / 粒子 / 橙装放射光，组合场景按品质自动着色 |
| `fx/fx_warn_dash.png`、`fx_warn_rect_9p.png`、`fx_warn_circle.png`、`fx_warn_dash_screen.png`、`fx_warn_rect_9p_screen.png`、`fx_warn_screen_fill.png`、`warn_samples.tscn` | 首领预警：虚线、矩形九宫格、标准椭圆、全场框和底色（白色出图，modulate 着色） |
| `fx/fx_frames.tres` | 特效 SpriteFrames：sword_slash / sword_hit / thunder_strike / thunder_ground / shield_hit |
| `fx/shaders/fx_on_light.gdshader`、`fx_add_soft.gdshader`、`shield_sphere.gdshader` | 亮底防过曝、暗底柔和加色、护盾球菲涅尔 |
| `shaders/sprite_paper_outline.gdshader` | 备用：精灵 1~2px 纸色外描边（实测不需要，默认不挂） |
| `ui/ui_*_9p*.png`、`ui_roundbtn*.png`、`ui_dodge*.png`、`ui_toggle_*.png`、`ui_reddot.png`、`ui_bar_*`、`ui_barframe*` | UI 九宫格切图和按钮状态（见 5.4） |
| `ui/ui_frame_quality_{white,green,blue,purple,orange}.png`、`ui_frame_quality_white_mod.png` | 品质框 72×72（beam_color 着色版 5 张 + 白框 modulate 版） |
| `ui/ui_theme.tres` | Godot Theme（Noto Serif SC，金字 #EAD7A8） |
| `ui/icons/*.png` | 54 个图标（文件名 = icon_list.csv 的 icon_key）+ 6 个按键按下态 `*_pressed.png` |
| `fonts/NotoSerifSC-Regular.otf`、`NotoSerifSC-Bold.otf`、`OFL_notoserifcjk.txt` | UI 正文/数值字体 |
| `preview/batch3_maps_contrast.png`、`batch3_vfx.png`、`batch3_warning.png`、`batch3_icons.png`、`batch3_battle_ui.png` | 预览（不进游戏） |

## 1. 一句话风格（v2）

**做旧宣纸肌理上的写意水墨：远山云雾层层叠叠、景深强；浓墨剪影角色带干笔飞白，长袍飘逸、动作有张力；金青飞剑和紫色光柱是画面里唯一的华彩；UI 用墨迹笔刷框、深色半透明底和古金描边，图标为写实手绘风格。**

### 相比 v1 的变化
| 项 | v1 | v2 |
| --- | --- | --- |
| 绘制方式 | 程序化平涂，边缘干净，偏卡通 | AI 生图 + 后期，手绘水墨质感：干笔、湿笔晕染、纸纹、墨渍 |
| 远景 | 3–4 层噪声山脊 | 5 层以上远山加云雾，大气透视强，近处浓、远处几乎融进纸色 |
| 角色 | 几何拼接剪影 | 剪影边缘带飞白和墨丝；长袍、长发、披帛大幅飘动；姿势夸张、有张力 |
| 敌人 | 造型规整的剪影 | 轮廓更凶狞，用乱笔表现毛发；怪物原型以 enemies.csv 为准（竹灵、山魈、泽灵、雷蟾、洞蝠、岩傀；首领竹魅、夔牛、岩魔），见 5.1.2 |
| 特效 | 单色光（青、蓝、金） | 飞剑金青双色流光；雷电鎏金或雷紫；掉落光柱参照预览图的紫色，带底部光球和上升光点 |
| UI | 纯色圆角面板 | 墨迹笔刷边框、深色半透明底（约 80%）、古金细描边、云纹角花；图标写实手绘（玉灵石、太极、羽毛、布袋、书卷等） |
| 字体 | 宋体 + 黑体 | 标题改用书法体 **Ma Shan Zheng**（副题 Zhi Mang Xing，均 OFL），数值和正文仍用 Noto Sans/Serif SC，金字加深色描边 |

### 从 v1 保留的设定
- 三张地图的主色区分：青竹山青绿、雷泽谷靛紫、玄岩洞赭红。v2 中以「水墨灰阶 + 地图主色罩染」的方式呈现。
- 主角的朱砂披帛 `#B8382C`，仍是主角唯一的彩色识别点。
- 首领预警改为**白色 `#F4F1EA` 或朱砂 `#B8382C` 虚线框**加 0.8 秒闪烁，不用红橙色填充，避免和玄岩洞的熔岩、橙装光柱混淆。
- 资源规格（第 5 节）。

## 2. 配色规范（v2，实测）

| 类别 | 名称 | HEX | 用途 / 取样位置 |
| --- | --- | --- | --- |
| 水墨 | 宣纸亮 / 宣纸暗 | `#D1C6B3` / `#C2B4A1` | 天空留白、底纸（01） |
| 水墨 | 淡墨 / 中墨 / 浓墨 | `#C5BBA8` / `#A0968A` / `#30312D` | 远山、中景山、近景崖石（01） |
| 水墨 | 焦墨 | `#111415` | 角色剪影（01 主角） |
| UI | 墨底 / 墨绿 | `#232C25` / `#2F453C` | 面板底、关卡牌底（07） |
| UI | 古金描边 / 金字 | `#C5B489` / `#EAD7A8` | 描边与图标（07 实测）；数值与按钮字（规范） |
| UI | 生命 / 护盾 | `#7B2015` / `#A98344` | 状态条（07） |
| 强调 | 朱砂（规范） | `#B8382C` | 首领预警虚线、印章；披帛校色目标 |
| 强调 | 披帛（正式资源） | `#B8382C` | 正式资源已统一校色：红色像素色相固定为朱砂，饱和度/亮度按中位数映射（保留明暗）；v2 样张生图原色为 `#7B3527` 左右 |
| 特效 | 飞剑青 | `#63BD9D` | 飞剑剑光（06），剑柄/火花为金 |
| 特效 | 雷电紫蓝 | `#7872C3` | 连锁雷电辉光（06），内核近白 |
| 特效 | 护盾金 | `#CEA445` | 八卦护盾（06） |
| 特效 | 预警白 | `#F4F1EA` | 首领预警虚线 |
| 品质 | 白 / 绿 / 蓝 / 紫 / 橙 | `#CACAC9` / `#62BB73` / `#347DD2` / `#934DC5` / `#D89522` | 光柱、名称、品质框（06 光柱实测）；07 场景落宝光柱内核 `#D3B5E9` |
| 地图 | 青竹山 | `#8C907B` / `#455247` | 青绿淡墨（整体偏灰绿、最亮） |
| 地图 | 雷泽谷 | `#5A5A85` / `#1E2245` | 靛紫浓墨、夜空 |
| 地图 | 玄岩洞 | `#EE741A` / `#3E2A19` | 熔岩高光、焦褐岩 |

### 2.1 文字色与特效色（第 3 批定）
策划表里同一品质 / 功法有两套色值，用途严格分开：

| 字段 | 用途 | 规则 |
| --- | --- | --- |
| `qualities.color`、`gongfa.color` | **UI 文字色**（装备名、品质字、功法名、技能书名等） | 已审通过，在面板底 `#232C25` 上对比度 ≥ 4.5（实测：白 8.78、绿 6.09、蓝 4.98、紫 4.63、橙 5.65；飞剑诀 6.37、御雷诀 5.23、玄罡诀 6.18）。UI 文字一律用这组，不要用 beam/fx 色 |
| `qualities.beam_color`、`gongfa.fx_color` | **光柱、特效、品质框、题签色块等图形用的原值** | 不保证文字对比度（如紫 beam `#934DC5` 在 `#232C25` 上只有 2.82、御雷 fx `#7872C3` 3.42），**禁止用作文字色** |
| `#EAD7A8` 金字 | 默认 UI 文字、数值、按键字 | 对比度 10.14；描边 `#1C1E21` 85%，3~4px |
| `#C8BA96` 暗金 | 次要说明文字（“境界：”“推荐战力：”） | 字号 ≥ 13 |

### 2.2 首领预警色（按地图，第 3 批实测定稿）
| 地图 | 预警色（modulate） | 说明 |
| --- | --- | --- |
| 青竹山 | 朱砂 `#B8382C` | 亮宣纸地面上白色不显，用朱砂 |
| 雷泽谷 | 预警白 `#F4F1EA` | 暗紫底 |
| 玄岩洞（含天坠全场预警） | 预警白 `#F4F1EA` | 避开熔岩橙红 |

统一结构（三张地图相同，只换颜色）：

| 部件 | 地平线圆形 / 矩形预警 | 全场预警（天坠） |
| --- | --- | --- |
| 主线 | **4px** 虚线，划 12 / 空 12 | **6px** 虚线 |
| 外描边 | **2px** 连续 `#1C1E21` × **70%** | **3px** `#1C1E21` × 70% |
| 填充 | 预警色 × **15%**（进度内圈 30%） | 中心 15% → 四边 35% |
| 闪烁 | 引擎做，0.8s | 同左 |

实测调整：要求值是主线 2~3px + 外描边 60%。压在玄岩洞熔岩高光（亮端约 #F8A80E）上时白线对比度只有 1.76，靠外描边托底；外描边 60% 时与高光的对比度不足 4，提高到 70% 后为 3.4~4.4，白线与暗描边之间 7.8~9.0，整圈轮廓清楚。青竹山亮地面（约 #DFDCC9）上朱砂主线 4.2、外描边 5.3。主线因此由 3px 加粗到 4px。实测数据见 `src/_warn_contrast.json`，样例见 `preview/batch3_warning.png`。

## 3. 三张地图的区分要点（实际图）
- **青竹山**：宣纸天空最亮，青绿淡罩（偏灰绿）。标志：左右浓墨竹林框景、崖顶楼阁、4~5 层雾。地面为暖灰石台，约 y≈600 起。
- **雷泽谷**：靛紫浓墨夜空，冷色、中低明度。标志：尖峰群 + 两道落雷 + 斜雨、泽地倒影、枯树芦苇。浅紫雾带在峰脚，地面约 y≈560 起（水面占中下部）。
- **玄岩洞**：无天空，赭红/焦褐。标志：钟乳石倒垂、右侧熔岩瀑布与熔岩池、地缝透橙光。地面约 y≈570 起。
- 三图在 1/4 缩略下仍一眼可分（见 04 右下角缩略）：亮灰绿 / 暗靛紫 / 暗底橙光。
- 注意：三张生图地平线不完全一致（约 y=560~600），正式分层时统一到 y=585；战斗带内雷泽谷枯树、玄岩洞右侧石笋需移到前景层或删掉。

## 4. 从生图到可用素材的过渡管线

生图结果**不能直接进游戏**，只用来定风格和提供手绘纹理素材。按以下步骤转成正式资源：

1. **定稿**：按 `prompts.md` 每个条目生成 4–8 张候选，选定 1 张作为基准（key frame），其余作废。
2. **背景分层**：
   - 用同一提示词分别生成单层：只要远山、只要中景、只要前景竹或岩，背景为纯纸色。
   - 也可以对整图做分层抠图：用深度估计（如 Depth-Anything）按深度阈值切成 4 层，再用 inpainting 补齐被遮挡的部分。
   - 中景和近景横向扩展成 2560 宽并做无缝处理：用 outpainting，再做 offset 检查接缝。
   - 统一过一遍色彩：按本文配色做 Levels 和罩染，然后叠一层同一张宣纸纹理，保证各层纸纹一致。
3. **角色剪影图集**：
   - 生图只负责「造型设定」：每个角色生成待机、攻击、受击三个关键姿势，在纯纸色背景上。
   - 抠图后二值化或 alpha 化，得到剪影；保留边缘的干笔飞白，处理方法是用纸色做 alpha 的 luminance key。
   - 中间帧**不要**逐帧生图，生图结果帧间不连贯。两种可选做法：
     - (a) 美术按关键姿势手绘、补间，在 Krita 或 Clip Studio 里用水墨笔刷，2x 绘制；
     - (b) 把剪影拆成部件：头、躯干、袍摆、前后臂、前后腿、剑、披帛（`chr_hero_parts/*.png`），在 Godot 里用 Skeleton2D / Polygon2D 做骨骼动画，再离线导出成序列帧图集，或直接运行时播放。**推荐 (b)**：动作数量多、改动成本低。
   - 披帛、长发和袍摆在 Godot 里可以单独用 Line2D 或 Verlet 物理飘动，作为部件叠加。
   - 发光部件（敌人眼睛、熔岩裂纹）单独导出 `*_fx.png`，用 Add 混合叠加，可按地图换色。
4. **特效**：生图只出纯黑背景的单帧概念图，从中抠出笔触纹理（剑光、雷光、符文环、光柱）作为贴图。动态由 Godot 实现：GPUParticles2D、Line2D、shader（UV 滚动、溶解、菲涅尔）。光柱只做一张白色纹理，按品质 `modulate`。
5. **UI**：
   - 墨迹笔刷框：生图出 2–3 种笔刷边，裁成九宫格（`NinePatchRect`）源图 128×128，边距 32；描边金线用 `StyleBoxTexture` 叠加。
   - 写实手绘图标：每个图标单独生成，统一深色底、统一光源（左上），裁成 128×128 源图，进游戏显示 64×64。
   - 所有文字由引擎渲染，不能把文字画进图里。
6. **验收**：同屏截图检查三点：剪影在三张地图上是否可读、纸纹是否统一、特效是否压过背景。

## 5. 资源规格（正式版）

### 5.1 角色动作图集

基准为 1x，对应 1280×720。

| 对象 | 单帧尺寸 | 锚点（脚底，相对帧左上） | 动作：帧数 @ 帧率 |
| --- | --- | --- | --- |
| 主角 | 320×192 | (144, 184) | 待机 8f@10fps 循环；行走 8f@12fps 循环；普攻 6f@15fps（**第 4 帧为命中帧**，原第 3 帧，按生图实际调整）；施法 6f@12fps（第 4 帧出手）；闪避 5f@16fps（0.31s，对应免伤时长）；受击 3f@12fps；死亡 8f@10fps |
| 普通怪（竹灵、山魈、泽灵、雷蟾、洞蝠、岩傀） | 默认 256×160（人形 192×192），**第 2 批按体型逐个定，见 5.1.2** | 默认 (128, 152)，逐个见 5.1.2 | 待机 6f；移动 6f；攻击 6f；受击 3f；死亡 6f（fps 逐个见 5.1.2） |
| 首领（竹魅、夔牛、岩魔） | 默认 320×320，**第 2 批按体型和技能范围逐个定，见 5.1.2** | 默认 (160, 308)，逐个见 5.1.2 | 待机 6f@8fps；移动 8f@10fps；普攻 8f@12fps；危险技能＝前摇 4f（定格到 0.8s 预警结束）+ 出手 4f @10fps；受击 3f@12fps；死亡 8f@8fps |

#### 5.1.1 主角（第 1 批）

**主角身高（第 1 批定）**：头顶到脚底 **172px**（以待机帧为准，其余动作按各自直立帧统一到同一身高）。320×192 格不变：锚点 y=184 以上可用 184px，受击帧扬手、施法帧举指比头顶高 5% 左右，172px 时最高点仍在格内（检查无越界）；横向最宽的是受击第 1 帧和闪避第 3 帧，也都在格内。因此**规格未改**。

- 图集组织：每个动作一张图集，按 320×192 网格从左到右、从上到下排；**单张宽度不超过 2048px，最多 6 列，超过换行**（8 帧动作为 6+2，1920×384）。
- 横向锚点：待机/普攻/施法/闪避/受击/死亡按「双脚中点」对齐到 x=144；行走按「头部」对齐（原地走，身体不前后晃）。
- 朝向：图集一律面朝右。朝左时 `flip_h = true`，同时把 offset.x 取反（见 5.7）。
- 披帛统一校色到朱砂 `#B8382C`（各图集红色像素中位色在 `#A23025`~`#C43B2E` 之间，明暗按原画保留）。
- 剑光、命中闪光等特效不画进角色图集，由引擎特效层实现；`*_swordlight.png` 只作备选。

#### 5.1.2 怪物与首领（第 2 批定）

**体型层次**（脚底到头顶的身体高度，不含雷光、烟和举起的巨石；主角 172px）：

| 档 | 怪物与身体高度 | 与主角比 |
| --- | --- | --- |
| 小 | 竹灵 128px | 0.74 |
| 小（悬浮） | 泽灵 118px、洞蝠 112px（翼展约 150px） | 0.65~0.7 |
| 与主角相当 | 山魈 178px（佝偻、体宽大）；雷蟾高 122px、体长约 190px（矮胖，体量与主角相当） | ≈1.0 |
| 大 | 岩傀 236px | 1.37 |
| 首领 | 夔牛 268px（含角，体长约 330px）、竹魅 290px、岩魔 318px | 1.56~1.85 |

**格子尺寸与锚点**（锚点是地面点，坐标相对帧左上；所有怪物精灵**朝左**）：

| id | 名称 | 单帧 | 锚点 | 对齐方式 | 尺寸调整理由 |
| --- | --- | --- | --- | --- | --- |
| `bamboo_imp` | 竹灵 | 256×192 | (152, 184) | 双脚中点 | 人形怪原定 192×192，但长矛向前（左）伸出约 140px，所以加宽到 256 |
| `mountain_ape` | 山魈 | 288×224 | (144, 216) | 身体质心 x + 脚底 y | 身高与主角相当，扑击帧向前探，256×160 放不下 |
| `marsh_wisp` | 泽灵 | 224×192 | (96, 184) | **悬浮**：身体质心在锚点正上方 82px | 鬼火拖尾向右飘，身体离地约 15px |
| `thunder_toad` | 雷蟾 | 256×160 | (128, 152) | 身体质心 x + 脚底 y | 标准格，未改 |
| `cave_bat` | 洞蝠 | 192×224 | (72, 216) | **悬浮**：身体质心在锚点正上方 118px | 飞在主角胸口高度，扑咬时正对主角上半身 |
| `rock_golem` | 岩傀 | 320×288 | (160, 280) | 双脚中点 | 明显大于主角，举双拳帧高约 273px |
| `zhumei` | 竹魅 | 736×352 | (352, 330) | 底部（根须）中点 | 普攻竹鞭向前甩出约 340px，前摇向后甩出约 370px，必须加宽；每行 2 帧 |
| `kuiniu` | 夔牛 | 384×480 | (192, 466) | 身体质心 x + 蹄底 y | 人立前摇加头顶雷光，高约 430px |
| `yanmo` | 岩魔 | 352×480 | (200, 472) | 双脚中点 | 天坠举起的巨石高约 435px |

- **死亡动画**的横向改按身体质心对齐（倒地、化灰后“脚底”不可靠），并整体平移，让第 1 帧和受击、待机的锚点完全一致，切换时不跳。
- **悬浮怪锚点规则**：节点原点仍放在地面（y=585，用于排序、碰撞和阴影），精灵按“身体质心在锚点正上方 hover px”对齐；所有动作（含死亡）都按质心对齐，所以死亡是在空中化散。需要上下浮动时，前端在 `offset.y` 上叠加 `sin(t)*4px`，不要改节点 y。
- 同一张原图里，个别行被生图画小了（竹魅移动行、岩魔移动行，宽高同比缩小，不是姿势变化），已按行补偿 1.15 / 1.12 倍。
- 图集：单张宽 ≤2048，列数＝floor(2048/单帧宽)（竹魅每行 2 帧，夔牛、岩魔每行 5 帧，其余单行）。

**动作、fps 与关键帧**（索引从 0 起）：

| id | idle | move | attack（命中/出手帧） | hit | death | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 竹灵 | 6f@8 循环 | 6f@12 循环 | 6f@12，**索引 2** 突刺命中（0.17s） | 3f@12 | 6f@10 | 受击生图与待机几乎相同，程序加了后仰 3~7° 和后退 4~9px |
| 山魈 | 6f@8 | 6f@12 | 6f@12，**索引 3** 扑击落地命中；索引 0~2 是蓄力，0.5s 蓄力期间可停在索引 2，冲撞到位后播 3~5 | 3f@12 | 6f@10 | |
| 泽灵 | 6f@8 | 6f@10 | 6f@12，**索引 2** 喷吐命中 | 3f@12 | 6f@10（末帧是补的 45% 淡出） | |
| 雷蟾 | 6f@8 | 6f@8 | 6f@10，**索引 3** 雷球离口，在锚点 (-52,-68) 处生成 `fx_toad_orb`（朝左） | 3f@12 | 6f@10（原 7 帧取 6） | |
| 洞蝠 | 6f@12 | 6f@15 | 6f@15，**索引 3** 张口扑咬命中 | 3f@12（**程序生成**：待机帧后仰 4~12° 并后退 5~12px） | 6f@10（原 8 帧取 6） | 原图第 4 行全是化散帧，不适合做受击 |
| 岩傀 | 6f@6 | 6f@8 | 6f@10，**索引 3** 双拳砸地命中 | 3f@12 | 6f@10（原 4 帧 + 60%/30% 淡出 2 帧） | |
| 竹魅 | 6f@8 | 8f@10 | 8f@12，**索引 2** 竹鞭横扫命中（帧序：起手 → 后甩 → 前扫 ×2 → 收势 ×4） | 3f@12 | 8f@8（6 帧 + 2 帧淡出） | |
| 夔牛 | 6f@8 | 8f@10（原 7 帧，补 1 帧重复） | 8f@12，**索引 2** 角顶命中 | 3f@12 | 8f@8（6 帧 + 2 帧淡出） | |
| 岩魔 | 6f@8 | 8f@10 | 8f@12，**索引 3** 岩拳命中 | 3f@12 | 8f@8（6 帧 + 2 帧淡出） | |

**首领危险技能**统一为 8 帧 @10fps。**前摇是索引 0~3，索引 3 在 .tres 里 duration=5.0，即定格 0.5s**，索引 0~3 合计正好 0.8s，等于预警时长。**索引 4 是出手判定帧**，出手 4 帧共 0.4s，整段 1.2s。

| 技能 attack_id | 动画名 | 图集 | 内容 |
| --- | --- | --- | --- |
| BA_ZHUMEI_THORN 竹刺突 | `skill_thorn` | `boss_zhumei_skill_thorn_08f.png` | 伏身蓄力 4 帧 → 化作竹刺破土 2 帧 → 由竹刺重新聚形 2 帧（取自死亡行倒放）。前方 520px 长条里的竹刺用 `fx_zhumei_thorn_02f.png` 沿预警条摆放 |
| BA_ZHUMEI_LEAF 竹叶旋风 | `skill_leaf` | `boss_zhumei_skill_leaf_08f.png` | 同一套前摇 4 帧 → 竹叶旋风 2 帧，播两遍 |
| BA_KUINIU_STOMP 雷霆践踏 | `skill_stomp` | `boss_kuiniu_skill_stomp_08f.png` | 人立蓄雷 4 帧 → 落地雷爆 4 帧 |
| BA_KUINIU_BOLTS 天雷三连 | `skill_bolts`（别名） | 复用 `skill_stomp` 全部 8 帧 | 没有单独生图；人立蓄雷正好对应“引天雷”，落雷由特效层在玩家位置生成 |
| BA_YANMO_CHARGE 碎岩冲撞 | `skill_charge` | `boss_yanmo_skill_charge_08f.png` | 站姿蓄力 4 帧 → 熔岩冲拳 3 帧 → 收势 1 帧；横向位移由程序做 |
| BA_YANMO_SKYFALL 玄岩天坠 | `skill_skyfall` | `boss_yanmo_skill_skyfall_08f.png` | 举岩 4 帧 → 巨岩迸碎石 4 帧（巨石下落由特效层做） |
| BA_YANMO_QUAKE 地裂 | `skill_quake`（别名） | 复用 `attack` 帧序 [0,1,2,2,3,4,5,6] | **地裂映射**：没有单独生图，复用岩拳的“举拳 3 帧（第 3 帧重复一次作定格）+ 砸下 4 帧”。举拳前摇比天坠举岩更短促，和全场的天坠区分开 |

普通攻击（BA_*_SLASH / HORN / FIST）没有预警，直接播 `attack`。

**抠图（第 2 批）**：白底按亮度转 alpha 并反预乘（同第 1 批）。在此基础上，身体 80px 范围内的发光像素（紫蓝雷光/雷球、橙黄熔岩与火花、青绿或红色眼睛）按偏色强度提高 alpha 并保留原色；雷蟾雷球的白芯和白色裂纹按发光密度填成不透明白光；被身体包住的纯白空隙（腿间等）仍然透明。在深色和中灰绿底上都检查过，没有白边。

### 5.2 背景（视差）

| 层 | 尺寸 | 视差系数 scroll_scale.x | 放置 | 说明 |
| --- | --- | --- | --- | --- |
| 远景（天空 + 远山） | 1280×720，不透明 | 0.15 | (0,0)，repeat 1280 | 左右无缝（与自身半宽错位的副本在两侧 240px 内交叉淡化） |
| 中景（山 / 竹 / 雷峰 / 石笋） | 2560×720，透明 | 0.5 | (0,0)，repeat 2560 | 横向拉伸 1280→1480 后头尾 200px 交叉淡化成 1280 无缝块，再拼两次；不用镜像（镜像会出现对称竹丛） |
| 近景地面 | 2560×170，透明（地面以下不透明） | 1.0 | (0,550)，repeat 2560 | 地面顶边对齐 y=585，草尖最高到 y≈555；做法同中景 |
| 前景遮挡（竹竿、芦苇、岩壁） | 2560×720 长图 或单件 PNG | 1.3 | (0,0)，repeat 2560，z_index 20（在角色之上） | 战斗区 x 230~1050、y 250 以下羽化淡出；竹丛外侧 170px 淡出，滚动时不露直边 |
| 动态元素 | 序列帧或 shader | — | — | 落雷闪光、熔岩流动（UV 滚动 shader）、雾带缓移 |

- 地平线统一 **y=585**；角色脚底锚点放在 y=585。
- 第 3 批两张图的近景放置：雷泽谷 `bg_leize_near.png` 2560×195 放 (0,525)；玄岩洞 `bg_xuanyan_near.png` 2560×145 放 (0,575)，都已在 `.tscn` 里写好。
- 玄岩洞远景：原图四周有暗框，取中段 (230~1050, 从 y=100 起) 放大后重建左右无缝；近景原图底部不规则，取地面以下镜像补齐到 y=720 并压暗。
- **暗底对比度（第 3 批实测）**：雷泽谷、玄岩洞在中景层的战斗带（y≈280~600）烘了一层亮雾，雷泽谷淡紫 `#C4B8E2` 峰值 50%，玄岩洞熔岩逆光 `#E2AC68` 峰值 55%，熔岩等发光像素处自动减弱。墨色怪（泽灵、雷蟾、洞蝠、岩傀、夔牛、岩魔）和主角在战斗带上都能看清（`preview/batch3_maps_contrast.png`），**怪物图集未改动**，也不需要描边 shader。备用方案 `shaders/sprite_paper_outline.gdshader`（纸色 `#F4F1EA` 55%，1.5px）已给出，如以后加了更暗的地图或怪物再挂。
- 白底图层抠图方法：alpha = 最大通道暗度（去 JPEG 底噪 3~4.5%），再反预乘还原颜色，墨色晕染保留为半透明，不会有白边。

### 5.3 特效（第 3 批正式版）

| 文件 | 尺寸 / 帧 | fps | 锚点 / 用法 |
| --- | --- | --- | --- |
| `fx_sword_body.png` | 136×48 | — | 中心 (68,24)；剑尖朝 +x，`rotation` 指向目标 |
| `fx_sword_trail.png` + `fx_sword_trail_gradient.tres` | 256×64 | — | `Line2D.texture`，`texture_mode=STRETCH`，点序 尾→头，`gradient` 用 .tres，宽 24~32 |
| `fx_sword_slash_06f.png` | 6×192×192 | 20 | 中心 (96,96)；0~2 划出、3~5 消散 |
| `fx_sword_hit_06f.png` | 6×128×128 | 24 | 中心 |
| `fx_thunder_glow.png` | 128×128 | — | 落雷/连锁端点/施法掌心光晕，Add |
| `fx_thunder_strike_06f.png` | 6×160×448 | 24 | 锚点 (80,440) = 地面落点 |
| `fx_thunder_ground_06f.png` | 6×288×240 | 20 | 锚点 (144,232) = 地面落点 |
| `fx_shield_ring.png` / `fx_shield_sphere.png` | 256×256 | — | 原色（护盾金）；符环 0.2 rad/s 缓转；球配 `shield_sphere.gdshader` |
| `fx_shield_hit_04f.png` | 4×256×256 | 16 | 白色出图，modulate `#CEA445` |
| `fx_loot_beam.png` | 64×512 | — | 锚点 (32,512) 底部；白色，modulate beam_color；`scale.y = 高度/512`，高度 白 0 / 绿 110 / 蓝 200 / 紫 300 / 橙 420 |
| `fx_loot_base.png` / `fx_loot_particle.png` / `fx_loot_rays.png` | 192×64 / 16×16 / 256×128 | — | 底座锚点 (96,44)；放射光锚点 (128,124)，仅橙装，modulate `#D89522` |
| `fx_warn_dash.png` | 24×8 | — | `Line2D` 虚线：width=8，`texture_mode=TILE`，`texture_repeat=ENABLED` |
| `fx_warn_rect_9p.png` | 40×40 | — | `NinePatchRect`，patch_margin 8，两向 TILE_FIT |
| `fx_warn_circle.png` | 528×144 | — | 侧视椭圆标准件，半径 256、中心 (264,72)；其他半径用 telegraph.gd 程序绘制，或按 r/256 缩放 |
| `fx_warn_dash_screen.png` / `fx_warn_rect_9p_screen.png` / `fx_warn_screen_fill.png` | 40×12 / 64×64（margin 12） / 640×360 | — | 全场预警的框和底色；底色拉伸铺满视口 |

- 预警纹理一律白色出图（外描边是烘进去的暗色），用 `modulate` 换地图预警色，见 2.2。
- 帧动画都在 `fx/fx_frames.tres` 里（sword_slash / sword_hit / thunder_strike / thunder_ground / shield_hit，均不循环）。
- **亮底过曝方案**：暗底（雷泽谷、玄岩洞、暗 UI）用 `CanvasItemMaterial.blend_mode = Add` 或 `fx_add_soft.gdshader`；亮底（青竹山、宣纸 UI）上的发光特效改挂 `fx_on_light.gdshader`：Mix 混合 + 外侧 4px `#1C1E21` 45% 墨晕，不会发白。可按地图在特效池里统一切换材质。对比见 `preview/batch3_vfx.png` 上下两栏。
- 雷电连锁仍建议程序化（`Line2D` 折线中点位移，每 2~3 帧重算），端点放 `fx_thunder_glow.png`。

### 5.4 UI（第 3 批正式版）
九宫格边距 = Godot `StyleBoxTexture.texture_margin_*` / `NinePatchRect.patch_margin_*`（左, 上, 右, 下）：

| 文件 | 源尺寸 | 九宫格边距 | 用途 |
| --- | --- | --- | --- |
| `ui_panel_9p.png` / `ui_panel_9p_translucent.png` | 238×116 | 35, 25, 35, 25 | 墨迹大面板（不透明 / 半透明底），content_margin 40, 30 |
| `ui_banner_9p.png` | 240×82 | 62, 28, 62, 28 | 墨绿祥云横幅（关卡名），最小宽 160 |
| `ui_pill_9p.png`（+ `_hover`、`_pressed`） | 111×42 | 24, 12, 24, 12 | 药丸框：资源栏、提示、小按钮 |
| `ui_slot_9p.png`（+ `_pressed`） | 106×102 | 27, 27, 27, 27 | 技能格；图标 72×72 叠在格子**上方**居中（格子内腔不透明） |
| `ui_tag_9p.png`（+ `_hover`、`_pressed`、`_disabled`） | 120×48 | 31, 13, 31, 13 | 翡翠题签按钮（Theme 默认 Button） |
| `ui_barframe_9p.png` | 214×31 | 20, 10, 20, 10 | 血条/护盾条底框，内腔 (4,4)~(205,27) |
| `ui_bar_hp_progress_9p.png` / `ui_bar_shield_progress_9p.png` | 214×31 | 20, 10, 20, 10 | `TextureProgressBar.texture_progress`，与底框同尺寸对齐，`nine_patch_stretch = true` |
| `ui_barframe_over_9p.png` | 214×31 | 20, 10, 20, 10 | `texture_over`（金边，内腔透明） |
| `ui_bar_hp_fill_9p.png` / `ui_bar_shield_fill_9p.png` | 224×22 / 223×22 | 14, 0, 14, 0 | 单独填充条（自绘进度时用） |
| `ui_roundbtn.png`（+ `_hover`、`_pressed`、`_disabled`） | 76×71 | 固定尺寸，可等比缩放 | 圆章功能按钮 |
| `ui_dodge.png`（+ `_pressed`、`_disabled`） | 111×110 | 固定 | 闪避大圆钮 |
| `ui_toggle_on.png` / `ui_toggle_off.png` | 73×35 | 固定 | 开关整图（CheckButton 图标）；另有 `ui_toggle_track_on/off.png` + `ui_toggle_knob.png`（30×29）可做滑动动画 |
| `ui_reddot.png` | 22×22 | 固定 | 红点，放在按钮右上角外 4px |
| `ui_frame_quality_*.png` | 72×72 | 固定 | 品质框，用 beam_color 着色；`ui_frame_quality_white_mod.png` 是白框，可 `modulate` beam_color；图标 64×64 放在框内居中 |

- 图标：`ui/icons/`，源图 128×128（显示 64×64），统一古金细描边、深色底、左上光源；按键 96×96，空格 256×96（显示一半），各有 `_pressed` 按下态。
- 技能书 `ui_icon_book_*` 的题签已校到功法 fx_color（飞剑青 `#63BD9D`、御雷 `#7872C3`、玄罡金 `#CEA445`）并加纸纹，书名由 UI 叠字。
- 字体：**标题/Logo 用书法体 Ma Shan Zheng**；UI 正文和数值用 **Noto Serif SC**（`fonts/NotoSerifSC-Regular.otf` / `-Bold.otf`，已打包进 Theme）。打包时建议子集化，或用 MSDF。伤害数字 Bold 40，字色 `#FFECC4`，描边 `#78140E` 8px（Theme 变体 `DamageLabel`）。
- 标题 Logo 已做成图片（`ui/title_logo*.png`）。
- 项目设置：`display/window/stretch/mode = canvas_items`，`aspect = expand`，基准 1280×720。

### 5.5 格式与 Godot 导入

| 资源 | 交付格式 | Godot 导入（Compress Mode） | 其他 |
| --- | --- | --- | --- |
| 角色 / 特效 / UI | PNG-32（RGBA） | Lossless | Mipmaps 关；**Fix Alpha Border 开**；Filter 线性 |
| 大背景（2560 宽） | PNG | VRAM Compressed（桌面端 S3TC/BPTC），如出现色带改用 Lossy 0.9 | 透明层同样开 Fix Alpha Border |
| 噪声 / 渐变 / 光柱纹理 | PNG 灰度 | Lossless | 用 modulate 着色 |

- 默认纹理过滤：Project Settings → Rendering → Textures → Default Texture Filter 设为 **Linear**。
- 本作首版只做 Windows 桌面端，交付以 PNG 为主。
- 背景用 Parallax2D 的 `repeat_size` 循环，纹理本身不用开 Repeat。

### 5.6 命名规范

`{类别}_{对象}_{动作或部件}[_{变体}]_{帧数}f.png`，全部小写拼音或英文，用下划线分隔：
- 角色：`chr_hero_idle_08f.png`、`chr_hero_attack_06f.png`、`chr_hero_attack_06f_swordlight.png`（变体放在帧数后，便于按动作排序）
- 敌人和首领：`enemies/<id>/enm_<id>_<动作>_<帧数>f.png`、`bosses/<id>/boss_<id>_<动作>_<帧数>f.png`；首领有多个危险技能时，动作名用 `skill_<内容>`（如 `boss_zhumei_skill_thorn_08f.png`、`boss_yanmo_skill_skyfall_08f.png`）；每种怪的 SpriteFrames 为 `enm_<id>.tres` / `boss_<id>.tres`
- 背景：`bg_qingzhu_far.png`、`bg_qingzhu_fore_01.png`、`bg_leize_mid.png`
- 特效：`fx_sword_slash_06f.png`、`fx_thunder_hit_06f.png`、`fx_shield_ring.png`、`fx_loot_beam.png`
- UI：`ui_panel_9p.png`、`ui_icon_skill_feijian.png`、`ui_frame_quality_blue.png`、`title_logo.png`
- 目录：`res://art/{characters/<obj>,enemies/<id>,bosses/<id>,bg/<map>,fx,ui,fonts}/`
- 怪物 id 与 enemies.csv 的对应：EN_BAMBOO_IMP→`bamboo_imp`、EN_MOUNTAIN_APE→`mountain_ape`、EN_MARSH_WISP→`marsh_wisp`、EN_THUNDER_TOAD→`thunder_toad`、EN_CAVE_BAT→`cave_bat`、EN_ROCK_GOLEM→`rock_golem`、BOSS_ZHUMEI→`zhumei`、BOSS_KUINIU→`kuiniu`、BOSS_YANMO→`yanmo`

### 5.7 前端接入说明（第 1、2 批）

**主角**
- 节点：`AnimatedSprite2D`，`sprite_frames = res://art/characters/hero/chr_hero.tres`。
- 锚点：把节点原点放在脚底。`centered = true` 时 `offset = Vector2(-16, -88)`（帧中心 (160,96) → 脚底 (144,184)）；或 `centered = false`，`offset = Vector2(-144, -184)`。
- 朝左：`flip_h = true`，`centered = true` 时 offset 改为 `Vector2(16, -88)`。
- 战斗中角色节点 `position.y = 585`。
- 动作：idle 10fps 循环、walk 12fps 循环、attack 15fps（第 4 帧＝索引 3 触发伤害/剑光）、cast 12fps（索引 3 出手）、dodge 16fps（5 帧≈0.31s，整段免伤）、hit 12fps、death 10fps（播完停在最后一帧，索引 6~7 为墨散，可在播完后淡出节点）。非循环动作在 `animation_finished` 里切回 idle。

**青竹山背景**
- 直接实例化 `res://art/bg/qingzhu/bg_qingzhu.tscn`，需要场景里有 `Camera2D`。
- 视差系数：远 0.15 / 中 0.5 / 近 1.0 / 前 1.3；z_index：-30 / -20 / -10 / +20（角色在 0）。
- 前景层在角色之上，只在画面两侧；战斗区 x 230~1050 内已淡出。如果镜头在战斗中会移动、前景扫过角色，可把 Fore 节点 `modulate.a` 降到 0.6~0.8，或改用 `fore_01/_02` 单件手动摆放。

**怪物 / 首领（第 2 批）**
- 节点：`AnimatedSprite2D`，`sprite_frames = res://art/enemies/<id>/enm_<id>.tres`（首领用 `res://art/bosses/<id>/boss_<id>.tres`）。动作名统一为 `idle / move / attack / hit / death`，首领另有 `skill_*`。
- 锚点：节点原点放在地面点（战斗中 `position.y = 585`）。推荐 `centered = false`，`offset = Vector2(-AX, -AY)`（AX、AY 见 5.1.2）；用 `centered = true` 时 `offset = Vector2(W/2 - AX, H/2 - AY)`。
- 朝向：图集一律**朝左**（默认面向主角）。需要朝右时设 `flip_h = true`；`centered = false` 时 offset.x 改为 `-(W - AX)`，`centered = true` 时改为 `AX - W/2`。

| id | W×H | `centered=false` 的 offset | 朝右时 offset |
| --- | --- | --- | --- |
| bamboo_imp | 256×192 | (-152, -184) | (-104, -184) |
| mountain_ape | 288×224 | (-144, -216) | (-144, -216) |
| marsh_wisp | 224×192 | (-96, -184) | (-128, -184) |
| thunder_toad | 256×160 | (-128, -152) | (-128, -152) |
| cave_bat | 192×224 | (-72, -216) | (-120, -216) |
| rock_golem | 320×288 | (-160, -280) | (-160, -280) |
| zhumei | 736×352 | (-352, -330) | (-384, -330) |
| kuiniu | 384×480 | (-192, -466) | (-192, -466) |
| yanmo | 352×480 | (-200, -472) | (-152, -472) |

- 伤害和出手时机：用 `frame_changed` 判断 5.1.2 里的命中帧；首领危险技能在 `skill_*` 播到索引 4 时结算，这时 0.8s 预警正好结束。前摇定格已写进 .tres（索引 3 的 duration=5），不需要手动暂停；如果以后改了预警时长，只改索引 3 的 duration：duration = (warn_s - 0.3) × 10。
- 受击：岩傀和三个首领是霸体（见 enemies.csv），受击时可以只闪白、不打断当前动作；普通怪播完 `hit` 后回到 `idle` / `move`。
- 死亡：播完停在最后一帧（最后 1~2 帧已经是淡出），再把节点淡出或回收。
- 雷蟾雷球：`fx/fx_toad_orb.png` 是弹道贴图（91×79，中心作为旋转和碰撞中心），在 attack 索引 3 时于锚点 (-52,-68) 处生成，速度 350px/s（见 enemies.csv）。贴图已带 alpha，用 Add 或 Mix 混合都可以。
- 竹魅竹刺：`fx/fx_zhumei_thorn_02f.png`（2 帧，320×352，底部锚点 (160,344)）。从 `skill_thorn` 索引 4 开始，沿 520px 预警条每隔约 120px 放一簇，逐簇延迟 0.05s。
- 悬浮怪（泽灵、洞蝠）：按 5.1.2 的悬浮锚点规则；阴影（如果有）放在节点原点。
- 第 2 批的 9 个 .tres 已用 Godot 4.7.2 headless 加载验证，所有动作的帧数、fps、循环和总时长都正确。

### 5.8 前端接入说明（第 3 批）
- **背景**：直接实例化 `bg/leize/bg_leize.tscn`、`bg/xuanyan/bg_xuanyan.tscn`，节点结构和青竹山相同（Far 0.15 / Mid 0.5 / Near 1.0 / Fore 1.3，z_index -30/-20/-10/20）。需要单独摆放前景时用 `bg_*_fore_01/02.png`，并把整张 `bg_*_fore.png` 隐藏。
- **特效**：AnimatedSprite2D 用 `fx/fx_frames.tres`；拖尾 `Line2D` + `fx_sword_trail.png` + `fx_sword_trail_gradient.tres`。材质：暗底地图 Add（或 `fx_add_soft.gdshader`），青竹山改用 `fx_on_light.gdshader`。
- **掉落光柱**：实例化 `fx/loot_beam.tscn`，节点原点放落点，设 `quality = 1~5`，自动设置颜色（beam_color）、高度、粒子和橙装放射光。
- **护盾**：实例化 `fx/shield_fx.tscn`，原点放主角身体中心（脚底上方约 90px），受击调 `hit()`。
- **预警**：参考 `fx/warn_samples.tscn`（RectWarn = NinePatchRect、CircleWarn = Sprite2D、ScreenWarn = 全场底色 + 框）。`modulate` 按 2.2 的地图色设置；闪烁用 Tween 把 `modulate.a` 在 1.0 和 0.45 间往返，0.8s 内 2~3 次。若继续用 telegraph.gd 程序绘制，参数按 2.2 的定稿值（主线 4px、外描边 2px 70%、填充 15%）。
- **UI**：项目或根 Control 的 `theme` 设 `ui/ui_theme.tres`。默认 Label / Button / ProgressBar / CheckButton / PanelContainer 已配好；类型变体（`theme_type_variation`）：`ShieldBar`、`TitleBanner`、`PillPanel`、`PillButton`、`TagLabel`、`SkillSlot`、`SkillSlotPressed`、`RoundButton`、`DodgeButton`、`DimLabel`、`TitleLabel`、`DamageLabel`。血条推荐 `TextureProgressBar`：under = `ui_barframe_9p`，progress = `ui_bar_*_progress_9p`，over = `ui_barframe_over_9p`，三张都设同样的 stretch margin 20, 10, 20, 10。技能冷却用 TextureProgressBar `fill_mode = CLOCKWISE` 叠半透明黑罩。拼装效果见 `preview/batch3_battle_ui.png`（脚本 `src/make_preview_battle_ui.py` 里有每个控件的坐标，可直接参考）。
- **图标**：`ui/icons/<icon_key>.png`，键名和 `design/icon_list.csv` 一致（54/54，另有 6 个 `_pressed`），导入 Lossless、Mipmaps 关。

## 6. 资源来源登记表

> **AI 生图的商用许可由用户在上线前确认**（需确认所用生图模型/服务的商用条款，并保留生成记录）。字体为 SIL OFL 1.1，可免费商用、可随游戏打包，但不能单独售卖字体文件，修改后的字体不能沿用原名。

| 资源文件（相对 final/） | 来源 | 生图原图 | 处理脚本 |
| --- | --- | --- | --- |
| `characters/hero/chr_hero_idle_08f.png` | AI生图 + 程序微动（呼吸/飘动） | `assets/d0177e6653c538974cdeb3f4e5379de31615e17362184c614acb267251170bc6.jpg` | `src/make_hero.py` |
| `characters/hero/chr_hero_walk_08f.png` | AI生图 | `assets/f4bd4866a7888fe3962229737792ac9f2ed15269e555ce77afbd590fb16c251f.jpg` | `src/make_hero.py` |
| `characters/hero/chr_hero_attack_06f.png` | AI生图（第 4 帧青色剑光已抠除） | `assets/6336cf4b5cefa664c12da51448da9d846de91a471c86a0b6f03e52f0f824a3f4.jpg` | `src/make_hero.py` |
| `characters/hero/chr_hero_attack_06f_swordlight.png` | AI生图（备选，保留剑光） | `assets/6336cf4b5cefa664c12da51448da9d846de91a471c86a0b6f03e52f0f824a3f4.jpg` | `src/make_hero.py` |
| `characters/hero/chr_hero_cast_06f.png` | AI生图 | `assets/e3faf2379a87914a5c87488ee1a19114a13abd6fbd6a6e7a2c25e8d4b8c58283.jpg` | `src/make_hero.py` |
| `characters/hero/chr_hero_dodge_05f.png` | AI生图 | `assets/555813a688c516a2164cd1f5da52d793bd17b136fbdde2cb22e68303cbe5d035.jpg` | `src/make_hero.py` |
| `characters/hero/chr_hero_hit_03f.png` | AI生图（上行 3 帧） | `assets/1ecda8b2f41c1fbd8c5cbd606837934ecfa453d30e1c96efe17b83f5e8c8b125.jpg` | `src/make_hero.py` |
| `characters/hero/chr_hero_death_08f.png` | AI生图（下行 8 帧） | `assets/1ecda8b2f41c1fbd8c5cbd606837934ecfa453d30e1c96efe17b83f5e8c8b125.jpg` | `src/make_hero.py` |
| `characters/hero/chr_hero.tres` | 程序生成（Godot SpriteFrames） | — | `src/make_hero.py` |
| `bg/qingzhu/bg_qingzhu_far.png` | AI生图（程序做无缝） | `assets/e7ccfd51c0911001947b99d5233645f1553a66101ef49597f168e63b60093840.jpg` | `src/make_bg.py` |
| `bg/qingzhu/bg_qingzhu_mid.png` | AI生图（抠白 + 无缝） | `assets/0588aedf731565dcf73c98737bcc58b16395d55e16de977dd77843a92bc392f0.jpg` | `src/make_bg.py` |
| `bg/qingzhu/bg_qingzhu_near.png` | AI生图（抠白 + 下移对齐 + 无缝） | `assets/ac93f2241bd462fe9701f7c4a9a28f69df12085c2722f37e560379f4c39f8656.jpg` | `src/make_bg.py` |
| `bg/qingzhu/bg_qingzhu_fore.png` | AI生图（抠白 + 拼长图 + 战斗区淡出） | `assets/3bc1e03198b833fb64c419a36cb4c857dd37e2229d2d47bbe282ebe22037fade.jpg` | `src/make_bg.py` |
| `bg/qingzhu/bg_qingzhu_fore_01.png / _02.png` | AI生图（抠白，左/右竹丛精灵） | `assets/3bc1e03198b833fb64c419a36cb4c857dd37e2229d2d47bbe282ebe22037fade.jpg` | `src/make_bg.py` |
| `bg/qingzhu/bg_qingzhu.tscn` | 程序生成（Godot 场景） | — | `src/make_bg.py` |
| `ui/title_logo.png / title_logo_h.png` | 字体（Ma Shan Zheng + Zhi Mang Xing）+ 程序绘制（墨色起伏、朱砂印） | — | `src/make_title.py` |
| `fonts/*.ttf + OFL_*.txt` | 字体（Google Fonts，OFL 1.1） | — | 手动下载，见第 7 节 |
| `preview/keyart_calligraphy.png` | AI生图 + 字体标题（预览用，不进游戏） | `assets/6a6223647b88e1c664e6c60600bf1127a6a5af18d7cb3cbad2724caaa347f83e.jpg` | `src/make_title.py` |
| `preview/batch1_preview.png、bg_qingzhu_composite.png` | 程序合成（预览用，不进游戏） | 由上述资源合成 | `src/make_preview.py` |
| `preview/chr_hero_*.gif` | 程序合成（预览用，不进游戏） | 由图集合成 | `src/make_hero.py` |
| `enemies/bamboo_imp/enm_bamboo_imp_*.png`（idle、move） | AI生图（抠白保留发光 + 分帧 + 统一体型 + 锚点对齐） | `assets/66d79884435c0cd36420d3629b60711f62260ca415c49fd24ba6a4b9b0a4a85f.jpg` | `src/make_enemies.py` |
| `enemies/bamboo_imp/enm_bamboo_imp_*.png`（attack、hit（+程序后仰）、death） | AI生图（抠白保留发光 + 分帧 + 统一体型 + 锚点对齐） | `assets/48a13ea96dde48d54511f3ce55e514192dfe59da52f29ba3624f264b725bd48e.jpg` | `src/make_enemies.py` |
| `enemies/bamboo_imp/enm_bamboo_imp.tres` | 程序生成（Godot SpriteFrames） | — | `src/make_enemies.py` |
| `enemies/mountain_ape/enm_mountain_ape_*.png`（idle、move） | AI生图（抠白保留发光 + 分帧 + 统一体型 + 锚点对齐） | `assets/e14ea04eded18a107630bce8d640fb68e77eeb35cfc657d2ca0366b87b1b3d32.jpg` | `src/make_enemies.py` |
| `enemies/mountain_ape/enm_mountain_ape_*.png`（attack、hit、death） | AI生图（抠白保留发光 + 分帧 + 统一体型 + 锚点对齐） | `assets/8b27656a57f3435a10a2e2153edb294ed037f87573e81090d68a9ceaebe2dd74.jpg` | `src/make_enemies.py` |
| `enemies/mountain_ape/enm_mountain_ape.tres` | 程序生成（Godot SpriteFrames） | — | `src/make_enemies.py` |
| `enemies/marsh_wisp/enm_marsh_wisp_*.png`（idle、move、attack） | AI生图（抠白保留发光 + 分帧 + 统一体型 + 锚点对齐） | `assets/c9100b4826124449c2b47aaa206c9bacc9e6ed37aa957120d9afee1c6f9e6a7e.jpg` | `src/make_enemies.py` |
| `enemies/marsh_wisp/enm_marsh_wisp_*.png`（hit、death（原图第 1 行，+1 帧淡出）） | AI生图（抠白保留发光 + 分帧 + 统一体型 + 锚点对齐） | `assets/cef15eb5c3afc6b06b52c8e20d717cd9c01ce374e4dbabc1aed346e7c0e0b45c.jpg` | `src/make_enemies.py` |
| `enemies/marsh_wisp/enm_marsh_wisp.tres` | 程序生成（Godot SpriteFrames） | — | `src/make_enemies.py` |
| `enemies/thunder_toad/enm_thunder_toad_*.png`（idle、move、attack） | AI生图（抠白保留发光 + 分帧 + 统一体型 + 锚点对齐） | `assets/1c109d7204354c59fb0f3ab6eb1645d820737ab43d648aad735e26f8f1c1f9eb.jpg` | `src/make_enemies.py` |
| `enemies/thunder_toad/enm_thunder_toad_*.png`（hit、death（原图第 2、3 行）） | AI生图（抠白保留发光 + 分帧 + 统一体型 + 锚点对齐） | `assets/cef15eb5c3afc6b06b52c8e20d717cd9c01ce374e4dbabc1aed346e7c0e0b45c.jpg` | `src/make_enemies.py` |
| `enemies/thunder_toad/enm_thunder_toad.tres` | 程序生成（Godot SpriteFrames） | — | `src/make_enemies.py` |
| `enemies/cave_bat/enm_cave_bat_*.png`（idle、move、attack、death；hit 由待机帧程序变形） | AI生图（抠白保留发光 + 分帧 + 统一体型 + 锚点对齐） | `assets/b4e7b13449ca449c2bab29cdcfe178664d77963e150f90acf056629b94694e4d.jpg` | `src/make_enemies.py` |
| `enemies/cave_bat/enm_cave_bat.tres` | 程序生成（Godot SpriteFrames） | — | `src/make_enemies.py` |
| `enemies/rock_golem/enm_rock_golem_*.png`（全部动作（左侧英文行标签已去掉；death +2 帧淡出）） | AI生图（抠白保留发光 + 分帧 + 统一体型 + 锚点对齐） | `assets/31097b59eca3a23537bae6626ec8e8e32e39842eed1b6dd54a81691b8d5ce36e.jpg` | `src/make_enemies.py` |
| `enemies/rock_golem/enm_rock_golem.tres` | 程序生成（Godot SpriteFrames） | — | `src/make_enemies.py` |
| `bosses/zhumei/boss_zhumei_*.png`（idle、move） | AI生图（抠白保留发光 + 分帧 + 统一体型 + 锚点对齐） | `assets/f2b858da218d727b93f4411eab929e364b4618df5117dded8c01fef65d81de68.jpg` | `src/make_enemies.py` |
| `bosses/zhumei/boss_zhumei_*.png`（attack、skill_thorn、skill_leaf、hit、death（+2 帧淡出）） | AI生图（抠白保留发光 + 分帧 + 统一体型 + 锚点对齐） | `assets/3b83971bd982da863539adafefe5e5f3fcd8562150e7e4c86ba58e49273092df.jpg` | `src/make_enemies.py` |
| `bosses/zhumei/boss_zhumei.tres` | 程序生成（Godot SpriteFrames） | — | `src/make_enemies.py` |
| `bosses/kuiniu/boss_kuiniu_*.png`（idle、move） | AI生图（抠白保留发光 + 分帧 + 统一体型 + 锚点对齐） | `assets/47f366ee7ee2438509ab29107fa7a1aae8d676bfb2fc50b79294d5da625e22e6.jpg` | `src/make_enemies.py` |
| `bosses/kuiniu/boss_kuiniu_*.png`（attack、skill_stomp、hit、death（+2 帧淡出）） | AI生图（抠白保留发光 + 分帧 + 统一体型 + 锚点对齐） | `assets/14618be672d3a56d10d2b108db25a36bb254bc875c4a5eac18c3d87758b301b5.jpg` | `src/make_enemies.py` |
| `bosses/kuiniu/boss_kuiniu.tres` | 程序生成（Godot SpriteFrames） | — | `src/make_enemies.py` |
| `bosses/yanmo/boss_yanmo_*.png`（idle、move、attack） | AI生图（抠白保留发光 + 分帧 + 统一体型 + 锚点对齐） | `assets/2cb8f6f3113ed456b9d21560f48b0e11544320ee59aa4b7d29bdf89661a6e6b9.jpg` | `src/make_enemies.py` |
| `bosses/yanmo/boss_yanmo_*.png`（skill_charge、skill_skyfall、hit、death（+2 帧淡出）） | AI生图（抠白保留发光 + 分帧 + 统一体型 + 锚点对齐） | `assets/8548cf9c2c3ed2c55ca7482462669dbaf58c04748ba8e05bfa08eb1a57ce5951.jpg` | `src/make_enemies.py` |
| `bosses/yanmo/boss_yanmo.tres` | 程序生成（Godot SpriteFrames） | — | `src/make_enemies.py` |
| `fx/fx_toad_orb.png` | AI生图（雷蟾攻击行第 3 格独立雷球，抠白 + 白芯填充） | `assets/1c109d7204354c59fb0f3ab6eb1645d820737ab43d648aad735e26f8f1c1f9eb.jpg` | `src/make_enemies.py` |
| `fx/fx_zhumei_thorn_02f.png` | AI生图（竹魅技能行第 5、6 帧竹刺） | `assets/3b83971bd982da863539adafefe5e5f3fcd8562150e7e4c86ba58e49273092df.jpg` | `src/make_enemies.py` |
| `preview/batch2_preview.png、batch2_lineup.png` | 程序合成（预览用，不进游戏） | 由上述资源和第 1 批背景、主角合成 | `src/make_preview2.py` |
| `bg/leize/bg_leize_far.png` | AI生图（裁切 + 左右无缝） | `assets/54213b4cece778a5121bd9f8b0c4c68a5e660f0b8c4793b375215b870617fb5c.jpg` | `src/make_bg_maps.py` |
| `bg/leize/bg_leize_mid.png` | AI生图（抠白 + 无缝）+ 程序亮雾带 | `assets/28de99b57157353afae4a859cf2151f62b913b3e574c371c833f337a1d190bb2.jpg` | `src/make_bg_maps.py` |
| `bg/leize/bg_leize_near.png` | AI生图（抠白 + 对齐 y=585 + 无缝） | `assets/a1eb5bc38791d5c4b8983b3a0a34859fcff080713ccde741ca05410af9d8fe23.jpg` | `src/make_bg_maps.py` |
| `bg/leize/bg_leize_fore*.png` | AI生图（抠白 + 拆件 + 战斗区羽化） | `assets/9b075eb83121ab6c888703c00d60e1d7af1dd1896f66950fc0645ddfccf6d0e2.jpg` | `src/make_bg_maps.py` |
| `bg/xuanyan/bg_xuanyan_far.png` | AI生图（取中段去暗框 + 重建无缝） | `assets/c73ccb36cb70540212598f8866d3a6f7562702ad2f41ddb2e4654b8f00376ffc.jpg` | `src/make_bg_maps.py` |
| `bg/xuanyan/bg_xuanyan_mid.png` | AI生图（抠白保留熔岩发光 + 无缝）+ 程序逆光雾带 | `assets/f3f69d8ba1dfa02c935983ed83b120fda3cb40b669aff57e4ad46f8a3462275a.jpg` | `src/make_bg_maps.py` |
| `bg/xuanyan/bg_xuanyan_near.png` | AI生图（抠白 + 底部镜像补齐 + 无缝） | `assets/7c8279e046ec46cdd695b3c5e1081f1ff4cc330011b9c93d1411ee786b29bdcd.jpg` | `src/make_bg_maps.py` |
| `bg/xuanyan/bg_xuanyan_fore*.png` | AI生图（抠白 + 拆件 + 战斗区羽化） | `assets/0b4f30556d7275b3f7d902296e76e84b41b80694c4d7aa9ed8ac91aee52b8235.jpg` | `src/make_bg_maps.py` |
| `bg/leize/bg_leize.tscn`、`bg/xuanyan/bg_xuanyan.tscn` | 程序生成（Godot 场景） | — | `src/make_bg_maps.py` |
| `fx/fx_sword_*.png`、`fx_thunder_*.png`、`fx_shield_ring.png`、`fx_shield_sphere.png` | AI生图（黑底转 alpha + 反预乘 + 切件；序列帧由单张程序变形/淡出生成） | `assets/303239db9345fac54ca2437c7e7e584bf341077e1bcdb2562143f61761e5a095.jpg` | `src/make_fx.py`、`src/fx_src.py` |
| `fx/fx_shield_hit_04f.png`、`fx_loot_*.png`、`fx_sword_trail_grad.png` | 程序绘制（光柱以特效原图白色光柱为形参考） | — | `src/make_fx.py` |
| `fx/fx_warn_*.png` | 程序绘制（与 telegraph.gd 同几何） | — | `src/make_fx.py` |
| `fx/fx_frames.tres`、`fx_sword_trail_gradient.tres`、`*.tscn`、`*.gd`、`fx/shaders/*.gdshader`、`shaders/sprite_paper_outline.gdshader` | 程序生成 | — | `src/make_fx_godot.py`、`src/make_fx.py`（outline shader 手写） |
| `ui/ui_*.png`（面板、横幅、药丸、技能格、圆钮、闪避、条框与填充、开关、题签、红点、各状态） | AI生图（白底抠图 + 切件 + 九宫格整理；hover/pressed/disabled 程序调色） | `assets/bac3e9297f970e68c92a5687d0b534a765cc30f907d152ca4d5d3173656f6984.jpg` | `src/make_ui.py`、`src/make_ui_bars.py`、`src/ui_src.py` |
| `ui/ui_frame_quality_*.png` | 程序绘制（古金框 + beam_color） | — | `src/make_ui.py` |
| `ui/ui_theme.tres` | 程序生成（Godot Theme） | — | `src/make_theme.py` |
| `ui/icons/ui_icon_skill_*.png`（15） | AI生图（切格 + 统一古金描边） | `assets/1f234338f9208bb558e200105d7c2f0a181a45e4924d3505045f105aac29e71a.jpg` | `src/make_icons.py` |
| `ui/icons/ui_icon_gongfa_*.png`、`ui_icon_item_cur_*.png`、`ui_icon_item_mat_refine.png`、`ui_icon_item_mat_bt_*.png` | AI生图（切格 + 描边） | `assets/936135f4c9e92c0c9caf8025ce1413fb3f169be523a78d9c70576bbe98735867.jpg` | `src/make_icons.py` |
| `ui/icons/ui_icon_book_*.png`、`ui_icon_item_mat_page.png` | AI生图（题签校色到 fx_color + 纸纹 + 描边） | `assets/1fb3e2b6793a8c31d86000936a77f7cf187c7f55da163db5f912396a358a17c6.jpg` | `src/make_icons.py` |
| `ui/icons/ui_icon_equip_*_t1.png`、`*_t2.png` | AI生图（切格 + 描边） | `assets/69978771452b7a3e89372620f879b3c0803b9a4674831ebf5553195171d07c2a.jpg` | `src/make_icons.py` |
| `ui/icons/ui_icon_equip_*_t3.png`、`ui_icon_equip_core_*.png` | AI生图（切格 + 描边） | `assets/8d49de5410557e3e2a562f8d2f295ae6e6602207b36ff3d4e1726b400a9adbbf.jpg` | `src/make_icons.py` |
| `ui/icons/ui_icon_key_*.png`（含 `_pressed`） | AI生图空白键帽 + 字体（Noto Serif SC 金字） | `assets/619eb843d1532fabf164fed0846d8be1988e4bdd858ec2117fd2776f8b9c2ed9.jpg` | `src/make_icons.py` |
| `fonts/NotoSerifSC-*.otf`、`OFL_notoserifcjk.txt` | 字体（SIL OFL 1.1） | — | 下载自 Google Noto CJK |
| `preview/batch3_*.png` | 程序合成（预览用，不进游戏） | 由上述资源合成 | `src/contrast3.py`、`make_preview_fx.py`、`make_preview_warn.py`、`make_preview_icons.py`、`make_preview_battle_ui.py` |

## 7. 字体

| 字体 | 用途 | 许可 | 来源 URL | 文件 |
| --- | --- | --- | --- | --- |
| Ma Shan Zheng（马善政楷书） | 标题「重走修仙路」、印章字 | SIL Open Font License 1.1 | https://fonts.google.com/specimen/Ma+Shan+Zheng （文件取自 https://github.com/google/fonts/tree/main/ofl/mashanzheng ） | `fonts/MaShanZheng-Regular.ttf`、`fonts/OFL_mashanzheng.txt` |
| Zhi Mang Xing（钟齐志莽行书） | 副题「一剑 一盾 一雷霆」 | SIL Open Font License 1.1 | https://fonts.google.com/specimen/Zhi+Mang+Xing （文件取自 https://github.com/google/fonts/tree/main/ofl/zhimangxing ） | `fonts/ZhiMangXing-Regular.ttf`、`fonts/OFL_zhimangxing.txt` |
| Noto Serif SC（思源宋体） | UI 正文、数值、按钮、按键字（Theme 默认字体） | SIL Open Font License 1.1 | https://fonts.google.com/noto/specimen/Noto+Serif+SC （文件取自 https://github.com/notofonts/noto-cjk ） | `fonts/NotoSerifSC-Regular.otf`、`fonts/NotoSerifSC-Bold.otf`、`fonts/OFL_notoserifcjk.txt` |

- 曾比较 Liu Jian Mao Cao（草书），可读性不够，未采用。

## 8. 待确认 / 风险（第 1 批）
1. **AI 生图商用许可**：见第 6 节，需用户上线前确认。
2. **待机帧**：8 帧生图差异很小，但各帧笔触细节不完全一致（头顶高度差 1~3px），程序已加 1.4% 呼吸缩放和身后头发/披帛 ±2px 波动；播放时会有轻微「墨迹抖动」感，属于水墨风可接受范围，如需更稳可只用其中 1 帧加程序微动。
3. **施法**：第 4、5 帧几乎相同（生图重复），节奏上是一个短停顿，不影响使用。
4. **普攻第 4 帧**：剑光抠除后，该处原本叠在剑光下的墨（袍摆）有极少量变浅；备选图保留了剑光。
5. **受击**：原图受击行比同图死亡行大约 1.33 倍（缩放系数 0.536 对 0.714），已按受击第 3 帧（直立）高度缩放到 172px，和其他动作一致。
6. **背景**：中景、近景每 1280px 内容重复一次（2560 = 同一无缝块 × 2）；远景 1280 周期。在 0.5/1.0 视差下滚动约 2.5/1.3 屏重复一次，如需要更长不重复，请再生一张不同构图的中景/近景，我拼成真正的 2560。近景地面原图下半部的石块层被裁掉（只保留地面顶边以下 135px）。

## 9. 待确认 / 风险（第 2 批）
1. **AI 生图商用许可**：同第 6 节，第 2 批全部怪物图集也属于 AI 生图，上线前需用户确认。
2. **补帧和程序补动作**：竹灵受击、洞蝠受击由程序变形生成；泽灵死亡、岩傀死亡、三个首领的死亡末帧是淡出补帧；夔牛移动原图只有 7 帧（重复 1 帧补到 8）；竹魅普攻原图 7 帧（前扫帧重复 1 次）。
3. **首领技能**：竹刺突、竹叶旋风共用同一套前摇，出手各只有 2 张不同的画（各重复一次）；岩魔冲撞的前摇 4 帧几乎是静止站姿（看不出蓄力），出手是冲拳而不是冲撞；天坠出手 4 帧仍举着巨石，下落靠特效层。夔牛受击是人立姿势，和践踏前摇（也是人立）相近，玩家可能误读成要放技能。
4. **墨色怪在深色地图上**：泽灵、洞蝠、山魈、夔牛主体是浓墨加灰色毛发，在雷泽谷、玄岩洞的暗底上对比度偏低，靠眼睛和雷光识别。第 3 批出地图后统一检查，必要时给怪物加 1~2px 纸色外描边（shader）。
5. **格子尺寸**：竹魅格子 736×352，主要是给竹鞭留位置；夔牛、岩魔格子高 480，主要是给雷光和巨石留位置。都在 2048 限制内，显存影响很小。

## 10. 待确认 / 风险（第 3 批）
1. **AI 生图商用许可**：第 3 批的背景、特效、UI 部件、图标都属于 AI 生图，同第 6 节，上线前需用户确认。
2. **背景重复周期**：雷泽谷、玄岩洞中景/近景同青竹山，每 1280px 内容重复一次；玄岩洞远景是从原图中段放大重建的，清晰度略低于另两张（远景视差 0.15，实际观感影响小）。
3. **功能按钮图标**：icon_list.csv 里没有「装备 / 功法 / 地图 / 突破」菜单图标，效果图里用 Ma Shan Zheng 单字（装/功/图/破）代替；如需要手绘图标，请在 icon_list 里加键并生图。
4. **效果图比例**：`batch3_battle_ui.png` 用的是游戏内真实比例（主角约 170px 高），所以画面不像 v2 的 07 那样角色占半屏；UI 部件和文字质量与 v2 持平。
5. **预警椭圆**：`fx_warn_circle.png` 只是半径 256 的标准件，其他半径缩放后线宽会变；精确线宽建议继续由 telegraph.gd 程序绘制，参数按 2.2。

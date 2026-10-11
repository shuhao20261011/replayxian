# 《重走修仙路》美术规范 · 正式资源版（final）

> 状态：**第 1 批正式资源已出（主角 7 个动作 + 青竹山四层视差 + 书法标题）**。风格沿用用户已确认的 v2（`../style/v2/`），本文从 v2 复制后更新。
> 全部资源由 AI 生图原图经 Python 处理得到，脚本在 `src/`，`python3 src/build_all.py` 一键重建。生图原图目录记作 `assets/` = `/home/box/agent-data/agents/c452b474-dc96-4e4c-84be-b722b92a0762/assets/`。
> 把本目录的 `characters/`、`bg/`、`ui/`、`fonts/` 复制到 Godot 工程的 `res://art/` 下即可（`.tres`/`.tscn` 里的路径按 `res://art/...` 写好了）。

## 0. 文件清单（第 1 批）
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

## 1. 一句话风格（v2）

**做旧宣纸肌理上的写意水墨：远山云雾层层叠叠、景深强；浓墨剪影角色带干笔飞白，长袍飘逸、动作有张力；金青飞剑和紫色光柱是画面里唯一的华彩；UI 用墨迹笔刷框、深色半透明底和古金描边，图标为写实手绘风格。**

### 相比 v1 的变化
| 项 | v1 | v2 |
| --- | --- | --- |
| 绘制方式 | 程序化平涂，边缘干净，偏卡通 | AI 生图 + 后期，手绘水墨质感：干笔、湿笔晕染、纸纹、墨渍 |
| 远景 | 3–4 层噪声山脊 | 5 层以上远山加云雾，大气透视强，近处浓、远处几乎融进纸色 |
| 角色 | 几何拼接剪影 | 剪影边缘带飞白和墨丝；长袍、长发、披帛大幅飘动；姿势夸张、有张力 |
| 敌人 | 狼妖、岩傀，造型规整 | 毛发蓬乱的妖兽、带翼魔物、岩傀，轮廓更凶狞，用乱笔表现毛发 |
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
| 普通怪（狼妖等 6 种） | 256×160（人形怪 192×192） | (128, 152) | 待机 6f@8fps；移动 6f@12fps；攻击 6f@12fps；受击 3f@12fps；死亡 6f@10fps |
| 首领（3 种） | 320×320 | (160, 308) | 待机 6f@8fps；移动 8f@10fps；普攻 8f@12fps；危险技能＝前摇 4f（定格到 0.8s 预警结束）+ 出手 4f；受击 3f；死亡 8f@8fps |

**主角身高（第 1 批定）**：头顶到脚底 **172px**（以待机帧为准，其余动作按各自直立帧统一到同一身高）。320×192 格不变：锚点 y=184 以上可用 184px，受击帧扬手、施法帧举指比头顶高 5% 左右，172px 时最高点仍在格内（检查无越界）；横向最宽的是受击第 1 帧和闪避第 3 帧，也都在格内。因此**规格未改**。

- 图集组织：每个动作一张图集，按 320×192 网格从左到右、从上到下排；**单张宽度不超过 2048px，最多 6 列，超过换行**（8 帧动作为 6+2，1920×384）。
- 横向锚点：待机/普攻/施法/闪避/受击/死亡按「双脚中点」对齐到 x=144；行走按「头部」对齐（原地走，身体不前后晃）。
- 朝向：图集一律面朝右。朝左时 `flip_h = true`，同时把 offset.x 取反（见 5.7）。
- 披帛统一校色到朱砂 `#B8382C`（各图集红色像素中位色在 `#A23025`~`#C43B2E` 之间，明暗按原画保留）。
- 剑光、命中闪光等特效不画进角色图集，由引擎特效层实现；`*_swordlight.png` 只作备选。

### 5.2 背景（视差）

| 层 | 尺寸 | 视差系数 scroll_scale.x | 放置 | 说明 |
| --- | --- | --- | --- | --- |
| 远景（天空 + 远山） | 1280×720，不透明 | 0.15 | (0,0)，repeat 1280 | 左右无缝（与自身半宽错位的副本在两侧 240px 内交叉淡化） |
| 中景（山 / 竹 / 雷峰 / 石笋） | 2560×720，透明 | 0.5 | (0,0)，repeat 2560 | 横向拉伸 1280→1480 后头尾 200px 交叉淡化成 1280 无缝块，再拼两次；不用镜像（镜像会出现对称竹丛） |
| 近景地面 | 2560×170，透明（地面以下不透明） | 1.0 | (0,550)，repeat 2560 | 地面顶边对齐 y=585，草尖最高到 y≈555；做法同中景 |
| 前景遮挡（竹竿、芦苇、岩壁） | 2560×720 长图 或单件 PNG | 1.3 | (0,0)，repeat 2560，z_index 20（在角色之上） | 战斗区 x 230~1050、y 250 以下羽化淡出；竹丛外侧 170px 淡出，滚动时不露直边 |
| 动态元素 | 序列帧或 shader | — | — | 落雷闪光、熔岩流动（UV 滚动 shader）、雾带缓移 |

- 地平线统一 **y=585**；角色脚底锚点放在 y=585。
- 白底图层抠图方法：alpha = 最大通道暗度（去 JPEG 底噪 3~4.5%），再反预乘还原颜色，墨色晕染保留为半透明，不会有白边。

### 5.3 特效
（沿用 v2，未改）
- 飞剑：剑体 96×24 单图，拖尾用 `Line2D` 加渐变纹理（或拖尾序列 8f），命中剑气弧 6f，单帧 192×192。
- 雷电：建议程序化实现，用 `Line2D` 做折线中点位移，每 2–3 帧重算一次；配一张光晕纹理 64×64，再加命中爆闪 6f（128×128）。
- 护盾：椭圆罩 256×256 单图，配菲涅尔 shader；八卦符文环 256×256 单图（`rotation` 缓转）；受击闪光 4f。
- 掉落光柱：只做一张**灰白通用**竖向渐变纹理（64×512）和一张粒子图（16×16），按品质 `modulate` 着色。高度：白 0、绿 110、蓝 200、紫 300、橙 420（px）；橙装额外加放射光贴图 256×128。
- 发光层统一用 `CanvasItemMaterial.blend_mode = Add`；在浅色背景（青竹山）上加一层 Mix 混合的主色底，避免加色后发白。

### 5.4 UI
- 面板用九宫格：`NinePatchRect`，源图 64×64，边距 16。按钮和技能格单独切图。
- 技能图标 64×64（源图 128×128）；品质框 72×72，按五种品质各一张，或一张白框加 `modulate`。
- 字体：**标题/Logo 用书法体 Ma Shan Zheng**（副题、印章可用 Zhi Mang Xing / Ma Shan Zheng），数值和正文用 Noto Sans SC / Noto Serif SC。打包时建议子集化（书法字体单个 4~6MB），或用 Godot 的 MSDF 字体。伤害数字加 2–3px 深色描边。
- 标题 Logo 已做成图片（`ui/title_logo*.png`），游戏内标题优先用图片；如需运行时渲染，使用 `fonts/MaShanZheng-Regular.ttf`。
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
- 敌人和首领：`enm_wolf_run_06f.png`、`boss_golem_skill_08f.png`
- 背景：`bg_qingzhu_far.png`、`bg_qingzhu_fore_01.png`、`bg_leize_mid.png`
- 特效：`fx_sword_slash_06f.png`、`fx_thunder_hit_06f.png`、`fx_shield_ring.png`、`fx_loot_beam.png`
- UI：`ui_panel_9p.png`、`ui_icon_skill_feijian.png`、`ui_frame_quality_blue.png`、`title_logo.png`
- 目录：`res://art/{characters/<obj>,enemies,bosses,bg/<map>,fx,ui,fonts}/`

### 5.7 前端接入说明（第 1 批）

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

## 7. 字体

| 字体 | 用途 | 许可 | 来源 URL | 文件 |
| --- | --- | --- | --- | --- |
| Ma Shan Zheng（马善政楷书） | 标题「重走修仙路」、印章字 | SIL Open Font License 1.1 | https://fonts.google.com/specimen/Ma+Shan+Zheng （文件取自 https://github.com/google/fonts/tree/main/ofl/mashanzheng ） | `fonts/MaShanZheng-Regular.ttf`、`fonts/OFL_mashanzheng.txt` |
| Zhi Mang Xing（钟齐志莽行书） | 副题「一剑 一盾 一雷霆」 | SIL Open Font License 1.1 | https://fonts.google.com/specimen/Zhi+Mang+Xing （文件取自 https://github.com/google/fonts/tree/main/ofl/zhimangxing ） | `fonts/ZhiMangXing-Regular.ttf`、`fonts/OFL_zhimangxing.txt` |
| Noto Sans SC / Noto Serif SC | 数值、正文、按钮 | SIL Open Font License 1.1 | https://fonts.google.com/noto | 系统字体，打包时另行放入 |

- 曾比较 Liu Jian Mao Cao（草书），可读性不够，未采用。

## 8. 待确认 / 风险（第 1 批）
1. **AI 生图商用许可**：见第 6 节，需用户上线前确认。
2. **待机帧**：8 帧生图差异很小，但各帧笔触细节不完全一致（头顶高度差 1~3px），程序已加 1.4% 呼吸缩放和身后头发/披帛 ±2px 波动；播放时会有轻微「墨迹抖动」感，属于水墨风可接受范围，如需更稳可只用其中 1 帧加程序微动。
3. **施法**：第 4、5 帧几乎相同（生图重复），节奏上是一个短停顿，不影响使用。
4. **普攻第 4 帧**：剑光抠除后，该处原本叠在剑光下的墨（袍摆）有极少量变浅；备选图保留了剑光。
5. **受击**：原图受击行比同图死亡行大约 1.33 倍（缩放系数 0.536 对 0.714），已按受击第 3 帧（直立）高度缩放到 172px，和其他动作一致。
6. **背景**：中景、近景每 1280px 内容重复一次（2560 = 同一无缝块 × 2）；远景 1280 周期。在 0.5/1.0 视差下滚动约 2.5/1.3 屏重复一次，如需要更长不重复，请再生一张不同构图的中景/近景，我拼成真正的 2560。近景地面原图下半部的石块层被裁掉（只保留地面顶边以下 135px）。

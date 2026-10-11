# 重走修仙路 存档格式（阶段6，save_version = 1）

给后端 / 服务器存档对接与代码复审用。实现位置：

| 文件 | 职责 |
|---|---|
| `scripts/systems/save_codec.gd` (`SaveCodec`) | 纯函数：信封、校验和、链式迁移、严格校验（无文件读写） |
| `scripts/autoload/save_system.gd` (`SaveSystem`) | 读写文件、原子写入、损坏恢复、自动存档 / 防抖、Web 镜像、导入 / 导出 / 重置 |
| `scripts/systems/offline_system.gd` (`OfflineSystem`) | 离线结算（时钟回拨、封顶、pending）、领取 |
| `scripts/autoload/player_state.gd` | `to_dict()` / `from_dict()`、`important_change(reason)` 信号 |
| `tests/test_save.gd`、`tests/test_settings.gd` | 存档 / 离线 / 设置页测试 |

已按后端审查意见 `reviews/stage6_save_backend_review.md` 实现（逐条对照见文末第 11 节）。

## 1. 信封（顶层）

```json
{
  "save_version": 1,
  "game_version": "stage6+<commit>",
  "saved_at": 1800000000,
  "checksum": "sha256:<64位十六进制>",
  "data": { ... PlayerState.to_dict() ... }
}
```

- `save_version`（int）：存档结构版本，只在 `data` 结构变化时 +1，与游戏版本无关。
- `game_version`（string）：写档的构建（`stage<阶段>+<commit>`，本地开发为 `dev`），只作诊断，读档时不用。
- `saved_at`（int，unix 秒，UTC）：写档时的系统时间。读档时如果有多份合法副本，取它最大的一份。
- `checksum`：`"sha256:" + sha256(canonical_json(data))`。canonical_json 的规则：
  - 键按字典序排序；
  - 值为整数的浮点转成 int（Godot JSON 读回的数字都是 float）；
  - 其他浮点用 Godot 默认精度（`JSON.stringify(v, "", true, false)`）；
  - 不缩进。

  校验和**只用来发现损坏**（写坏、截断、手改），不防作弊，因为本地单机可以重算。
- 文件本身是带 Tab 缩进的 UTF-8 JSON。导出文件和存档文件完全相同，所以导出文件就是一份完整存档。

## 2. data 字段（v1）

| 字段 | 类型 | 说明 |
|---|---|---|
| `realm_id` | string | 境界 ID，须存在于 realms 表 |
| `lingshi`, `xiuwei` | int | 0 … 1e12 |
| `learned_skills` | {skill_id: int} | 等级 1 … SKILL_MAX_LEVEL；未知技能丢弃 |
| `active_slots` | [string] | 长度 = 技能栏数（当前 4）；"" 表示空。只能放已学的主动技能，不得重复 |
| `slot_auto` | [bool] | 每栏是否自动释放 |
| `passive_skill` | string | "" 或已学的被动技能 |
| `equipped` | {slot_id: gear} | 部位须与装备底子的部位一致 |
| `bag` | [gear] | 件数 ≤ 背包容量（100） |
| `books`, `items` | {id: int} | 0 … 1e6；未知 ID 丢弃（数量为 0 的项保留） |
| `auto_decompose` | {quality_id: bool} | 自动分解设置 |
| `pending_orange_choices` | [ {level_id, options:[gear]} ] | 未选的橙装三选一 |
| `next_uid` | int | ≥ 所有装备 uid 最大值 + 1 |
| `cleared_levels` | [level_id] | 已通关 |
| `auto_battle` | bool | 自动战斗开关 |
| `unstable_levels` | [level_id] | 自动战斗失败标记（地图上的“不稳定”） |
| `auto_fail_counts` | {level_id: int} | 自动战斗失败计数 |
| `tutorial` | dict | 新手引导进度 |
| `telegraph_alt` | bool | 设置：统一预警白 |
| `last_settle_at` | int unix 秒 | 上次结算（在线时每次保存都推到现在） |
| `max_seen_at` | int unix 秒 | 见过的最大系统时间，用来识别时钟回拨 |
| `pending_offline` | dict | 已结算、未领取的离线收益（见第 7 节）；{} = 没有 |

gear 的字段为 `{uid, base_id, quality_id, level, affixes:[{affix_id, value}], …}`，与 `GearItem.to_dict()` 一致。pending_offline 里的 gear 不带 uid（uid 为 0），领取时才分配。

**读档合并**：`PlayerState.from_dict(d)` 先执行 `reset_new_game()`，再把 d 覆盖到默认的 `to_dict()` 上。所以旧档里缺少的新字段会自动取新游戏的默认值，新增字段不必写迁移（`test_from_dict_merges_defaults`）。

## 3. 版本与迁移

- `SaveCodec.migrations()` = `{n: Callable(data) -> data}`，表示把 n 升级到 n+1。执行时逐级链式调用，每一步都是纯函数（深拷贝后修改，不碰全局状态）。
- 当前只有 `0 → 1`。v0 指阶段 1-5 的裸 `PlayerState.to_dict()`（没有信封，用于调试导出和测试夹具）。迁移会补上 `last_settle_at = 0`、`max_seen_at = 0`、`pending_offline = {}`、`telegraph_alt = false`。v0 没有时间戳，所以不会产生离线收益。
- 如果 `save_version` 高于游戏的 SAVE_VERSION，一律拒读（`too_new`）：
  - 启动时：不覆盖这份存档，本次运行**不写盘**（状态显示“存档只读”），以新游戏状态运行并给出提示；
  - 导入时：拒绝导入。
- 以后升到 v2：`SAVE_VERSION = 2`，在 migrations 里加 `1: _v1_to_v2`，并补测试（参照 `test_migration_chain_and_too_new`）。

## 4. 存放位置

| 平台 | 位置 |
|---|---|
| 桌面 | `user://`，即 Linux `~/.local/share/godot/app_userdata/重走修仙路/`，Windows `%APPDATA%\Godot\app_userdata\重走修仙路\`。设置页会显示实际路径。 |
| Web | `user://` 对应浏览器 IndexedDB（`/userfs`），另外**同步镜像**一份到 `localStorage["replayxian.save.v1"]`。同一域名下所有阶段（/stage5/、/stage6/ …）共用这份存档。 |

主要文件：
- `save.json`：主存档；
- `save.json.bak`：上一版；
- `save.json.tmp`：写入中的临时文件；
- `save.before_import.json` / `save.before_reset.json`：导入或重置前的备份；
- `save.corrupt.<YYYYMMDD_HHMMSS>[.ext][.n].json`：隔离的坏档。

**为什么 Web 要镜像**：Godot Web 的 IDBFS 没有开 autoPersist，文件关闭后要等主循环（requestAnimationFrame）里的 `FS.syncfs` 才会写进 IndexedDB。后台标签页里 rAF 暂停，关页时也可能来不及同步。localStorage 是同步写入的，所以每次保存都同时写一份，读档时取 `saved_at` 最新的合法副本。headless Chromium 已验证：刷新页面后存档保留。

## 5. 写入（原子）

`SaveSystem.write_atomic`：
1. 序列化，写入 `save.json.tmp` 并关闭；
2. 重读 tmp，完整执行 `SaveCodec.decode`（解析、校验和、校验）。失败就放弃这次写入，状态显示“保存失败”，旧档不动；
3. 删除旧的 `.bak`，把 `save.json` 改名为 `save.json.bak`；
4. 把 `save.json.tmp` 改名为 `save.json`；
5. （Web）写 localStorage 镜像。

写之前会把 `last_settle_at` 和 `max_seen_at` 更新为 now；如果 now 小于 max_seen_at（时钟回拨），max_seen_at 保持不变。

## 6. 读取与损坏恢复

`SaveSystem.load_best()`：
1. 候选依次为 `save.json`、`save.json.bak`、`save.json.tmp`（Web 再加 localStorage 镜像）。每份都完整 decode，取合法副本中 `saved_at` 最新的一份。
2. 如果 `save.json` 本身版本过新，结果为 `too_new`，见第 3 节。
3. 如果 `save.json` 损坏或缺失、但其他副本可用，结果为 `recovered`。坏的主档先隔离成 `save.corrupt.*.json`，以免下次写入时被改名成 `.bak`、覆盖掉好的备份。启动时提示“存档损坏，已从备份恢复”。
4. 如果全部损坏，结果为 `corrupt`：所有坏文件改名为 `save.corrupt.<时间>.json` 保留，开始新游戏，并提示“存档损坏且无法恢复…已另存为 <文件名>”。
5. 如果没有任何文件，结果为 `new`。

无论哪种情况都不会崩溃。decode 的错误码有：`too_big`、`parse`、`fields`、`too_new`、`checksum`、`migrate`、`range`、`ids`、`rules`。

## 7. 离线收益（offline_rewards.csv）

**结算**（`OfflineSystem.settle(now, rng)`，在启动读档后执行）：
- 时钟回拨：如果 `now < max_seen_at`，记为 `rollback`。本次收益为 0，`last_settle_at = now`，`max_seen_at` 不回改，并显示横幅“系统时间早于上次记录，本次不计闭关收益”。
- 否则 `delta = now - last_settle_at`（last_settle_at 为 0 时 delta 为 0），然后更新两个时间戳。
- 没有通关任何关卡：`no_clear`，不生成 pending。
- `minutes = floor(delta / 60)`。少于 `OFFLINE_MIN_MINUTES`（代码默认 1，表里暂无）时记为 `too_short`。
- 上限 = `min(OFFLINE_CAP_MINUTES (480), 当前行 cap_minutes)`。上次没领的 pending 会合并进来，合并后的总分钟数也不超过上限（`capped_full` / `capped`）。
- 收益行取**最近已通关的关卡**（按关卡顺序最后一个已通关）。

**产出**（生成 pending 时一次性随机，用启动时的 rng，领取时不再随机）：
- 灵石 / 修为 / 炼器材料：`floor(每分钟产出 × 分钟)`。
- 装备件数：`floor(equip_per_min × 分钟)`，小数部分按概率再加 1 件。品质按 `weight_set_id` 抽取，阶级取该关普通掉落表的装备阶级。
- 技能书：每分钟按 `book_chance_per_min` 独立判定一次（二项分布），书目从 `book_pool_id` 抽取。
- 灵石加成（lingshi_gain_pct）**不作用于**离线收益（表里的数字已是“在线效率的 50%”）。这一点待策划确认。

**pending 与领取**：结算完立即保存，所以 pending 跨重启保留，重开游戏也不会再算一次。领取（`claim()`）时**先清空 pending**再发放，然后发出 `important_change("offline_claim")`，立即保存。pending 为空时 claim 返回 `none`（防重复领取）。闭关页是模态的，Esc 不能跳过，只能点“收下”。

**背包满时（已定默认，待策划最终确认）**：offline_rewards.csv 中 `equip_per_min` 的说明是“配合背包100件与溢出转材料”，所以领取时装备走与在线掉落相同的 `add_gear` 规则：
- 先按自动分解设置处理；
- 背包放不下的转为炼器材料（MAT_REFINE），数量与在线溢出一样（refine_from_gear）；
- 闭关页提前提示“背包将满，N 件装备转为炼器材料”。

装备不会留在 pending 里，也不转成灵石。测试：`test_offline_bag_full_overflow_to_refine`。

## 8. 自动保存

- 每 `AUTOSAVE_INTERVAL`（10 秒）保存一次。`_process` 设为 PROCESS_MODE_ALWAYS，养成面板暂停时也照常保存，并把 last_settle_at 推到现在，所以暂停期间不额外产生离线收益。
- 重要操作：`PlayerState.important_change(reason)` 会触发 `request_save`，防抖到本帧末尾，同一帧多次操作只写一次。reason 包括：
  - breakthrough（突破）、equip（换装）、learn / upgrade（学习 / 升级功法）；
  - first_clear（首通）、orange_pick（橙装三选一）、offline_claim（离线领取）；
  - settings（设置，含自动战斗与统一预警白）；
  - loadout / book / decompose / reroll / auto_fail_mark。
- Web：通过 JavaScriptBridge 监听 `visibilitychange`（hidden）和 `pagehide`，触发时立即保存。
- 测试与 QA（无头运行，或场景是 test_runner / qa_runner / shot）**不启动**存档系统，不会碰真实的 user://。命令行参数可以改变这一行为：`-- --no-save` 关闭，`-- --save` 强制开启，`-- --save-dir=<目录>` 改存档目录。
- 右上【存】圆章下方显示存档状态：存档未启用 / 已保存 / 待保存 / 保存失败 / 存档只读。悬停显示上次保存的本地时间。点击圆章打开设置页。

## 9. 导入 / 导出 / 重置（设置页）

- **导出**：内容与第 1 节的存档文件相同，文件名 `replayxian_save_<本地时间>.json`。
  - Web：通过 `JavaScriptBridge.download_buffer` 触发浏览器下载；
  - 桌面：原生“另存为”对话框，另有“复制存档码”（剪贴板）作为备用。
- **导入**：
  - Web：用隐藏的 `<input type=file>` 加 FileReader 读入；
  - 桌面：原生打开对话框，另有“粘贴存档码”。

  导入流程：
  1. 读入后先做**严格预检**（`check_import` = 完整 decode）：
     - 大小 ≤ 1 MB，JSON 可解析，顶层必须是对象；
     - 必需字段齐全；版本不高于游戏；校验和正确；
     - 数值都是非负整数（拒绝 NaN、小数、字符串）且不超过上限；
     - 境界 ID 存在；技能等级在范围内；
     - 技能栏长度正确、不重复、只放已学的主动技能；
     - 背包不超容量；装备部位与底子一致。
  2. 未知的技能、书、物品、装备底子会丢弃，并提示丢弃的数量。
  3. 预检失败时提示具体原因，**当前进度不变**。
  4. 预检通过后要**两次确认**。第二次确认的按钮 0.8 秒后才能点，防止连点。
  5. 确认后先备份 `save.before_import.json`，再替换进度；导入的 `last_settle_at` 改为 now，避免靠导入刷离线收益。
- **重置**：同样两次确认，先备份 `save.before_reset.json`，再开新游戏。`max_seen_at` 保留，防止借重置绕过时钟回拨检查。

## 10. 防作弊范围（轻量）

单机本地存档无法真正防篡改。这里只保证三点：数值不越界、时钟回拨拿不到收益、不能重复领取。如果以后接服务器，建议：
- 由服务器保存 `last_settle_at` 并负责离线结算；
- 信封原样上传，服务器重新执行同一套校验规则（第 9 节）；
- checksum 改为服务器签名。

## 11. 对照后端审查意见

| 审查要求 | 实现 / 测试 |
|---|---|
| 信封 save_version/game_version/saved_at/checksum/data | 第 1 节；`test_roundtrip_save_load` |
| 迁移为链式纯函数；更高版本拒读 | 第 3 节；`test_migration_v0_bare_dict`、`test_migration_chain_and_too_new`、`test_too_new_save_not_overwritten` |
| from_dict 合并到默认值上 | 第 2 节；`test_from_dict_merges_defaults` |
| 导入严格校验，失败不改进度 | 第 9 节；`test_import_rejects_invalid`（18 种情况）、`test_import_drops_unknown_ids_and_clamps_time`、`test_import_export_string_roundtrip`；UI：`test_settings.test_import_fail_message_keeps_progress` |
| last_settle_at / max_seen_at 处理回拨 | 第 7 节；`test_offline_clock_rollback_zero` |
| pending 在读档时一次随机，领取时清空；跨重启保留 | 第 7 节；`test_offline_claim_once_and_persist_across_restart`；UI：`test_settings.test_offline_panel_claim_flow` |
| 8 小时封顶（读表） | `test_offline_cap_8h` |
| 原子写入 tmp → 校验 → bak → rename | 第 5 节；`test_second_save_rotates_bak` |
| 回退顺序 save.json → .bak → .tmp；全坏则隔离并开新档 | 第 6 节；`test_corrupt_main_recovers_from_bak`、`test_checksum_mismatch_counts_as_corrupt`、`test_leftover_tmp_used_when_main_missing`、`test_all_corrupt_new_game_never_crash` |
| Web visibilitychange 保存；防抖 | 第 4、8 节；`test_autosave_interval_from_table`、`test_important_actions_trigger_debounced_save`、`test_web_mirror_newer_wins`；Chromium 刷新验证 |
| 重置先备份 | `test_reset_backs_up_first`；UI：`test_settings.test_reset_two_step_confirm_with_arming` |
| 背包满时的离线掉落 | 第 7 节（转为炼器材料）；`test_offline_bag_full_overflow_to_refine` |

## 12. 待确认

1. 背包满时离线装备转为炼器材料（按表说明实现）。是否改成“留在 pending”或“转灵石”？
2. `OFFLINE_MIN_MINUTES`（代码默认 1 分钟）和 `ORANGE_CHOICE_AUTO_LATER_SEC`（默认 8 秒）是否收进 constants 表？
3. 灵石加成是否作用于离线灵石（目前不作用）？
4. Web 端多个阶段的页面共用同一份存档（同一域名），是否需要按阶段隔离？

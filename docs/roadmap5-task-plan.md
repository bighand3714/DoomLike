# Roadmap 5 - 最小单位可执行任务计划

> 依据：`docs/roadmap5-progression-difficulty-design.md`  
> 状态：待实施  
> 基准决策：10 分钟流程；击杀直接给经验；升级时暂停；护甲保持当前全额优先吸收；熔岩地狱允许 +10% 经验/掉落补偿。  
> 目标：以最小闭环实现玩家局内等级、三选一升级、升级效果、HUD 展示、动态刷怪和荒漠/熔岩地狱难度差异。

---

## 0. 执行原则

- 每个任务只解决一个明确问题，完成后游戏应仍可运行。
- 先做数据和接口，再接入 UI，再接入数值，再做难度曲线。
- 不直接修改原始 `.tres` 运行时资源；需要升级改数值时使用运行时副本或运行时倍率。
- 所有新增脚本注释继续使用中文。
- 每个阶段结束都做一次手动运行验证，避免到最后才发现状态机或暂停逻辑断掉。

---

## 1. 里程碑总览

| 里程碑 | 目标 | 完成标志 |
|---|---|---|
| M1 | 成长数据骨架 | 有 `UpgradeData / UpgradeCatalog / PlayerProgression`，可在代码中加经验升级 |
| M2 | 击杀经验闭环 | 击杀敌人后经验增加，满经验触发升级事件 |
| M3 | 三选一 UI | 升级时暂停，显示 3 个选项，选择后恢复 |
| M4 | 升级效果闭环 | 武器、铁鞭、生存、掉落至少各有可生效升级 |
| M5 | HUD 展示 | HUD 显示等级和经验条，升级通知正常 |
| M6 | 动态难度 | 刷怪强度同时参考时间和玩家等级 |
| M7 | 关卡差异化 | 熔岩地狱明显比荒漠更难，但有 +10% 经验/掉落 |
| M8 | 验证与调参 | 10 分钟流程可测，关键时间点等级和强度接近设计目标 |

---

## 2. M1 - 成长数据骨架

### R5-001 新建成长目录

涉及文件：

- `scripts/progression/`
- `assets/upgrades/`

任务：

- 新建成长系统脚本目录。
- 新建升级资源目录。

验收：

- 两个目录存在。
- 不修改现有运行逻辑。

### R5-002 新建 `UpgradeData`

涉及文件：

- `scripts/progression/upgrade_data.gd`

任务：

- 定义 `class_name UpgradeData extends Resource`。
- 增加 `Category` 和 `Operation` 枚举。
- 增加 `upgrade_id / display_name / description / category / max_level / rarity_weight / tags / prerequisites / exclusions / target_id / stat_key / operation / values_by_level / power_value_by_level` 字段。

验收：

- Godot 能识别 `UpgradeData` Resource。
- 字段可在编辑器导出配置。

### R5-003 新建 `UpgradeCatalog`

涉及文件：

- `scripts/progression/upgrade_catalog.gd`

任务：

- 定义 `class_name UpgradeCatalog extends RefCounted`。
- 提供 `setup(upgrades: Array[UpgradeData])`。
- 提供 `get_choices(selected_levels: Dictionary, count: int = 3) -> Array[UpgradeData]`。
- 过滤已满级、前置条件不满足、互斥冲突的升级。

验收：

- 输入 4 个测试升级时能返回 3 个不重复选项。
- 已满级升级不会被返回。

### R5-004 给目录创建第一批升级资源

涉及文件：

- `assets/upgrades/*.tres`

任务：

- 创建 12 个 MVP 升级资源：
  - `rifle_damage.tres`
  - `shotgun_damage.tres`
  - `reload_speed.tres`
  - `whip_range.tres`
  - `whip_cooldown.tres`
  - `whip_stun.tres`
  - `max_health.tres`
  - `max_armor.tres`
  - `move_speed.tres`
  - `ammo_loot.tres`
  - `health_loot.tres`
  - `drop_abundance.tres`

验收：

- 每个资源有唯一 `upgrade_id`。
- 每个资源有 `max_level` 和 `values_by_level`。

### R5-005 新建 `PlayerProgression`

涉及文件：

- `scripts/progression/player_progression.gd`

任务：

- 定义 `class_name PlayerProgression extends Node`。
- 增加 `level / xp / xp_to_next / selected_levels / pending_level_ups`。
- 实现 `reset() / add_xp(amount) / get_xp_to_next(level) / select_upgrade(index)`。
- 使用设计文档公式：`round(12 + 6 * level + 1.5 * pow(level, 1.5))`。

验收：

- 调用 `add_xp(20)` 可从 Lv1 升到 Lv2。
- 连续获得大量经验时能正确累计多次待升级。

---

## 3. M2 - 击杀经验闭环

### R5-006 扩展 `EnemyData` 经验字段

涉及文件：

- `scripts/enemy/enemy_data.gd`

任务：

- 增加 `@export var xp_value: int = 5`。
- 注释说明旧资源未配置时的回退逻辑由成长系统处理。

验收：

- 旧敌人资源不报错。
- 编辑器里可看到 `xp_value`。

### R5-007 为敌人资源补经验值

涉及文件：

- `assets/enemies/ground_enemy.tres`
- `assets/enemies/ranged_enemy.tres`
- `assets/enemies/flying_enemy.tres`
- `assets/enemies/orc_melee.tres`
- `assets/enemies/advanced_ground_enemy.tres`
- `assets/enemies/advanced_ranged_enemy.tres`
- `assets/enemies/advanced_flying_enemy.tres`
- `assets/enemies/flying_ranged_enemy.tres`
- `assets/enemies/elite_ground_enemy.tres`

任务：

- 按设计表写入 `xp_value`。

验收：

- 基础近战为 5。
- 精英为 30。
- 高级/远程/飞行敌人介于 8-16。

### R5-008 扩展 `GameBus` 成长信号

涉及文件：

- `scripts/core/game_bus.gd`

任务：

- 增加 `xp_changed(level, xp, xp_to_next)`。
- 增加 `level_up(new_level, options)`。
- 增加 `upgrade_applied(upgrade_id, upgrade_level)`。
- 增加 `player_power_changed(power_score)`。
- 增加共享引用 `player_progression = null`。

验收：

- 信号定义无语法错误。
- 现有 GameBus 信号不受影响。

### R5-009 将 `PlayerProgression` 接入 Main

涉及文件：

- `scripts/main.gd`

任务：

- preload `PlayerProgression`。
- 在 `_ready()` 或 `_start_level()` 创建成长节点。
- 设置 `GameBus.player_progression`。
- 在 `_reset_player_for_level()` 调用 `progression.reset()`。

验收：

- 每次进关玩家等级重置为 Lv1。
- 死亡、重开、切关后不会继承上一局升级。

### R5-010 击杀时给经验

涉及文件：

- `scripts/main.gd`
- `scripts/progression/player_progression.gd`

任务：

- 在 `_on_enemy_killed_for_score()` 中读取敌人的经验值。
- 如果当前 `enemy_killed` 信号没有传敌人实例，则先用 `score_value` 回退：`max(3, round(score_value * 0.5))`。
- 更完整的实现可扩展 `EnemyManager.enemy_killed` 信号携带 `xp_value`。

验收：

- 击杀基础近战敌人后经验增加。
- 击杀不同敌人获得不同经验或合理回退经验。

### R5-011 升级事件暂停入口

涉及文件：

- `scripts/progression/player_progression.gd`
- `scripts/main.gd`

任务：

- `PlayerProgression` 满经验后生成 3 个选项并发出 `level_up`。
- `main.gd` 监听 `GameBus.level_up` 或 progression 信号。
- 暂时只打印选项，不做 UI。

验收：

- 达到升级经验时游戏能进入“等待选择”的状态。
- 连续升级时 `pending_level_ups` 不丢失。

---

## 4. M3 - 三选一 UI

### R5-012 新增 `GameState.LEVEL_UP`

涉及文件：

- `scripts/core/game_state.gd`
- `scripts/main.gd`

任务：

- 在 `GameState.State` 中增加 `LEVEL_UP`。
- `main.gd` 进入 LEVEL_UP 时暂停游戏、显示鼠标。
- 从 LEVEL_UP 返回 PLAYING 时恢复鼠标捕获。

验收：

- Esc 暂停和升级暂停互不混淆。
- 升级状态下敌人和刷怪不继续运行。

### R5-013 新建升级面板脚本

涉及文件：

- `scripts/ui/level_up_panel.gd`

任务：

- 定义 `class_name LevelUpPanel extends CanvasLayer`。
- 创建居中背景和 3 个按钮/卡片。
- 提供 `show_options(level: int, options: Array)`。
- 发出 `upgrade_chosen(index: int)` 信号。

验收：

- 可独立实例化。
- 调用 `show_options()` 后能看到 3 个选项。

### R5-014 接入升级面板到 Main

涉及文件：

- `scripts/main.gd`
- `scripts/ui/level_up_panel.gd`

任务：

- `main.gd` 创建 `_level_up_panel` 并添加到 UI。
- 收到升级事件时调用 `show_options()`。
- 玩家选择后调用 `PlayerProgression.select_upgrade(index)`。
- 选择完成后判断是否还有待升级；有则继续弹，没有则恢复 PLAYING。

验收：

- 升级时暂停并显示三选一。
- 鼠标点击可选择。
- 选择后面板隐藏，游戏恢复。

### R5-015 增加键盘 1/2/3 选择

涉及文件：

- `scripts/ui/level_up_panel.gd`

任务：

- 在升级面板可见时监听 `weapon_1 / weapon_2 / weapon_3` 或原始键位。
- 对应选择第 1/2/3 个升级。

验收：

- 升级面板可用键盘快速选择。
- 面板隐藏时不吞正常武器切换。

### R5-016 升级面板基础文案

涉及文件：

- `scripts/ui/level_up_panel.gd`
- `assets/upgrades/*.tres`

任务：

- 卡片显示升级名、当前等级、最高等级、描述。
- 描述使用当前等级对应的下一档数值。

验收：

- 例如 `步枪膛线 Lv2/5` 能正确显示下一档效果。

---

## 5. M4 - 升级效果闭环

### R5-017 给武器节点增加运行时倍率

涉及文件：

- `scripts/weapon/weapon_node.gd`

任务：

- 增加 `damage_mult / fire_rate_mult / reload_time_mult / spread_mult / pellet_bonus`。
- 所有伤害读取改为 `weapon_data.damage * damage_mult`。
- 射速冷却读取改为 `1.0 / (weapon_data.fire_rate * fire_rate_mult)`。
- 换弹时间读取改为 `weapon_data.reload_time * reload_time_mult`。

验收：

- 默认倍率为 1 时现有武器表现不变。
- 手动设置 `damage_mult = 2` 后伤害数字翻倍。

### R5-018 给 WeaponManager 暴露升级接口

涉及文件：

- `scripts/weapon/weapon_manager.gd`

任务：

- 增加 `apply_weapon_upgrade(target_id: String, stat_key: String, value: float, operation: int)`。
- 支持按 `weapon_name` 或 `slot_index` 定位武器。
- 支持全武器升级 target_id=`all_weapons`。

验收：

- 能单独强化步枪。
- 能统一减少所有武器换弹时间。

### R5-019 让铁鞭使用运行时数据副本

涉及文件：

- `scripts/weapon/iron_whip.gd`
- `scripts/main.gd`

任务：

- `IronWhip.setup()` 中对传入 `WhipData` 做 `duplicate(true)`。
- 增加 `apply_whip_upgrade(stat_key, value, operation)`。

验收：

- 升级铁鞭不会改写 `assets/weapons/iron_whip.tres`。
- 重开关卡后铁鞭数值恢复初始。

### R5-020 实现生存升级接口

涉及文件：

- `scripts/player/player_controller.gd`
- `scripts/damage/damageable.gd`
- `scripts/progression/player_progression.gd`

任务：

- 支持最大生命增加，并同步当前生命增加同等数值。
- 支持最大护甲增加，并同步当前护甲增加同等数值。
- 支持移动速度倍率。

验收：

- 选择最大生命升级后 HUD 最大生命增加。
- 选择最大护甲升级后 HUD 最大护甲增加。
- 选择移动速度升级后玩家移动速度提升。

### R5-021 实现掉落升级接口

涉及文件：

- `scripts/pickup/drop_manager.gd`

任务：

- 增加 `ammo_amount_mult / health_amount_mult / armor_amount_mult / drop_chance_bonus / extra_drop_chance`。
- 掉落生成时应用数量倍率。
- 掉落判定时应用总概率加成。

验收：

- 选择弹药搜刮后后续弹药数量增加。
- 选择丰饶掉落后无掉落概率降低。

### R5-022 PlayerProgression 应用升级分发

涉及文件：

- `scripts/progression/player_progression.gd`
- `scripts/main.gd`

任务：

- `select_upgrade(index)` 增加对应升级等级。
- 根据 `category / target_id / stat_key` 分发到 WeaponManager、IronWhip、Damageable、DropManager。
- 发出 `upgrade_applied` 和 `player_power_changed`。

验收：

- 选择升级后选项等级记录正确。
- 达到 max_level 后该升级不再出现。

### R5-023 实现 12 个 MVP 升级效果

涉及文件：

- `assets/upgrades/*.tres`
- `scripts/progression/player_progression.gd`

任务：

- 确认 12 个 MVP 升级全部能分发并生效。

验收：

- 武器类至少 3 个生效。
- 铁鞭类至少 3 个生效。
- 生存类至少 3 个生效。
- 掉落类至少 3 个生效。

---

## 6. M5 - HUD 展示

### R5-024 HUD 增加等级与经验字段

涉及文件：

- `scripts/ui/player_status.gd`

任务：

- 在左上角时间/强度附近增加 `等级` 和经验显示。
- 增加经验条背景和填充。

验收：

- 游戏开始显示 `等级: 1`。
- 经验条随击杀增长。

### R5-025 连接成长信号到 HUD

涉及文件：

- `scripts/ui/player_status.gd`
- `scripts/main.gd`

任务：

- 监听 `xp_changed` 更新经验条。
- 监听 `upgrade_applied` 显示升级通知。

验收：

- 击杀后 HUD 经验更新不延迟。
- 选择升级后显示 `升级名 LvN` 通知。

### R5-026 调整 HUD reset

涉及文件：

- `scripts/ui/player_status.gd`

任务：

- `reset_kill_count()` 或新增 `reset_run_ui()` 中同步重置等级、经验、强度。

验收：

- 重开关卡后 HUD 不残留上一局等级/经验。

---

## 7. M6 - 动态难度

### R5-027 将 SpawnManager 强度参数改为数据表

涉及文件：

- `scripts/enemy/spawn_manager.gd`

任务：

- 用数组/字典替代 `_get_spawn_interval / _get_active_enemy_limit / _get_wave_budget` 的硬编码 match。
- 建立 8 档数据表。

验收：

- 0-10 分钟强度按设计表变化。
- 默认行为仍能刷怪。

### R5-028 增加预期等级表

涉及文件：

- `scripts/enemy/spawn_manager.gd`

任务：

- 增加 `EXPECTED_LEVEL_POINTS`。
- 实现 `_get_expected_level(time: float) -> int`。

验收：

- 60 秒返回 Lv3 附近。
- 300 秒返回 Lv11 附近。
- 600 秒返回 Lv20。

### R5-029 SpawnManager 读取玩家等级

涉及文件：

- `scripts/enemy/spawn_manager.gd`
- `scripts/main.gd`

任务：

- 在 `setup()` 增加 progression 参数，或从 `GameBus.player_progression` 获取。
- 增加 `_get_player_level()` 安全回退。

验收：

- 没有 progression 时仍按时间刷怪。
- 有 progression 时能读到当前等级。

### R5-030 实现成长修正

涉及文件：

- `scripts/enemy/spawn_manager.gd`

任务：

- 实现 `level_delta = player_level - expected_level`。
- 超前时提高波次预算和高级敌人权重。
- 落后时不降低主阶梯，但发出追赶修正数据供 XP/掉落使用。

验收：

- 玩家等级超前 5 级时强度临时 +1，但不超过当前时间下一档。
- 玩家落后时不会降低敌人强度。

### R5-031 追赶经验与掉落修正

涉及文件：

- `scripts/progression/player_progression.gd`
- `scripts/pickup/drop_manager.gd`
- `scripts/enemy/spawn_manager.gd`

任务：

- SpawnManager 或 main.gd 将追赶倍率传给成长/掉落系统。
- 落后 2 级给经验 +5%。
- 落后 3 级以上给经验 +10% 和掉落 +5pp。

验收：

- 落后时击杀经验提高。
- 落后严重时掉落概率提高。

---

## 8. M7 - 关卡差异化

### R5-032 建立 SpawnProfile 数据

涉及文件：

- `scripts/enemy/spawn_manager.gd`

任务：

- 增加 `SpawnProfile` 字典或内部类。
- 定义 `default / desert / lava` 三套参数。

验收：

- `desert` 使用上限 x0.90、间隔 x1.12、预算 x0.90。
- `lava` 使用上限 x1.20、间隔 x0.90、预算 x1.15。

### R5-033 熔岩地狱敌人运行时倍率

涉及文件：

- `scripts/enemy/spawn_manager.gd`

任务：

- 生成敌人时复制 `EnemyData`。
- 对 lava 应用生命 x1.10、伤害 x1.10、速度 x1.05。

验收：

- 熔岩关生成敌人的 `enemy_data` 是运行时副本。
- 荒漠关不受到熔岩倍率污染。

### R5-034 熔岩地狱 +10% 经验/掉落

涉及文件：

- `scripts/main.gd`
- `scripts/progression/player_progression.gd`
- `scripts/pickup/drop_manager.gd`

任务：

- 进入 lava 关时设置经验倍率 x1.10。
- 进入 lava 关时设置掉落收益或掉落概率 x1.10。

验收：

- 同一敌人在 lava 关给的经验高于 desert。
- lava 关掉落收益或概率高于 desert。

### R5-035 调整荒漠/熔岩敌人权重

涉及文件：

- `scripts/enemy/spawn_manager.gd`

任务：

- 荒漠偏近战、兽人、高阶近战，飞行少。
- 熔岩偏远程、飞行、飞行远程，高级敌人提前 1 档。

验收：

- 3 分钟时 lava 的远程/飞行比例明显高于 desert。
- 6 分钟后 lava 可低权重出现精英，desert 不早于 8 分钟。

---

## 9. M8 - 验证与调参

### R5-036 新增手动测试清单

涉及文件：

- `docs/manual-test-guide.md` 或 `docs/roadmap5-test-checklist.md`

任务：

- 写出 Roadmap 5 专属测试步骤：
  - 击杀给经验。
  - 升级暂停。
  - 三选一选择。
  - 各类升级生效。
  - 重开重置。
  - 荒漠/熔岩难度对比。

验收：

- 测试者能按步骤复现并记录结果。

### R5-037 添加调试快捷入口

涉及文件：

- `scripts/progression/player_progression.gd`
- `scripts/main.gd`

任务：

- 仅调试构建或临时变量控制，提供加经验方法。
- 可从控制台或临时按键触发 `add_xp(999)`。

验收：

- 能快速测试连续升级。
- 正式关闭调试入口后不影响游戏。

### R5-038 10 分钟荒漠流程调参

涉及文件：

- `assets/enemies/*.tres`
- `assets/upgrades/*.tres`
- `scripts/enemy/spawn_manager.gd`

任务：

- 运行荒漠关，记录 1/3/5/10 分钟等级、击杀、强度、死亡原因。
- 调整 XP、刷怪预算、升级数值。

验收：

- 1 分钟 Lv3 左右。
- 3 分钟 Lv7 左右。
- 5 分钟 Lv11 左右。
- 10 分钟 Lv20 左右。

### R5-039 10 分钟熔岩流程调参

涉及文件：

- `assets/enemies/*.tres`
- `scripts/enemy/spawn_manager.gd`
- `scripts/level/lava_arena.gd`

任务：

- 运行熔岩地狱，记录同时间点等级、击杀、强度、死亡原因。
- 调整熔岩 Profile，确保明显更难但不无解。

验收：

- 熔岩关同时间敌人压力高于荒漠。
- 熔岩关因 +10% 经验/掉落不会出现长期等级落后。

### R5-040 回归测试

涉及文件：

- 全局

任务：

- 测试主菜单、选关、暂停、死亡结算、重开、回主菜单。
- 测试武器切换、换弹、铁鞭抓取、盾牌、冲刺处决。
- 测试掉落拾取、护甲、生命 HUD。

验收：

- Roadmap 5 没有破坏 Roadmap 4 已完成功能。

---

## 10. 推荐实施顺序

1. R5-001 到 R5-005：先把成长系统数据骨架搭起来。
2. R5-006 到 R5-011：打通击杀经验和升级事件。
3. R5-012 到 R5-016：做升级 UI 和暂停选择。
4. R5-017 到 R5-023：逐类接入升级效果。
5. R5-024 到 R5-026：完善 HUD。
6. R5-027 到 R5-031：让刷怪系统理解玩家等级。
7. R5-032 到 R5-035：做荒漠/熔岩 Profile。
8. R5-036 到 R5-040：测试、调参、回归。

---

## 11. 第一轮最小可玩版本

如果要最快看到效果，第一轮只做这些任务：

- R5-001 到 R5-005
- R5-008 到 R5-014
- R5-017、R5-018、R5-020、R5-022
- R5-024、R5-025

第一轮完成后，应能实现：

- 击杀获得经验。
- 升级弹出三选一。
- 选择“步枪伤害 / 最大生命 / 移动速度”等基础升级立即生效。
- HUD 显示等级和经验。

随后再补铁鞭、掉落、动态难度和熔岩地狱差异化。


# Roadmap 5 - 可交由 AI 执行的最小任务清单

> 用途：把本文件中的任务逐条交给 DeepSeekV4Pro 或其他 AI 编码助手执行。  
> 依据：`docs/roadmap5-progression-difficulty-design.md` 与 `docs/roadmap5-task-plan.md`。  
> 执行方式：一次只执行一个任务；每个任务完成后运行验收，再进入下一个任务。  
> 重要基准：10 分钟流程；击杀直接给经验；升级暂停；护甲继续按当前代码行为；熔岩地狱允许 +10% 经验/掉落补偿。

---

## 0. 给执行 AI 的通用指令

每次执行任务前，先阅读：

- `AGENTS.md`
- `docs/roadmap5-progression-difficulty-design.md`
- `docs/roadmap5-task-plan.md`
- 本任务要求中列出的相关源码文件

通用约束：

- 只完成当前任务，不顺手做后续任务。
- 不重构无关系统。
- 不删除或回滚用户已有改动。
- 新增脚本注释使用中文，注释应保证新手友好。
- 运行时数值升级不得直接污染原始 `.tres` 资源。
- 每个任务完成后说明改了哪些文件、如何验证、还有什么风险。

Godot 验证优先级：

- 至少确保 GDScript 语法层面没有明显错误。
- 如果本地能启动 Godot，则运行主场景 `res://scenes/main.tscn` 做手动验证。
- 若无法运行 Godot，必须在最终说明中明确“未能运行 Godot 验证”。

---

## 1. T01 - 创建成长系统目录和 UpgradeData

目标：建立升级资源的数据结构，先不接入游戏逻辑。

允许修改：

- 新建 `scripts/progression/upgrade_data.gd`
- 新建目录 `scripts/progression/`
- 新建目录 `assets/upgrades/`

执行步骤：

1. 创建 `scripts/progression` 和 `assets/upgrades`。
2. 新建 `upgrade_data.gd`。
3. 定义 `class_name UpgradeData extends Resource`。
4. 定义枚举：
   - `Category { WEAPON, WHIP, SURVIVAL, ECONOMY, UTILITY }`
   - `Operation { ADD, MULTIPLY, SET }`
5. 导出字段：
   - `upgrade_id: String`
   - `display_name: String`
   - `description: String`
   - `category: Category`
   - `max_level: int`
   - `rarity_weight: float`
   - `tags: Array[String]`
   - `prerequisites: Array[String]`
   - `exclusions: Array[String]`
   - `target_id: String`
   - `stat_key: String`
   - `operation: Operation`
   - `values_by_level: Array[float]`
   - `power_value_by_level: Array[float]`
6. 增加方法：
   - `get_value_for_level(next_level: int) -> float`
   - `get_power_for_level(next_level: int) -> float`
   - `is_valid_for_level(next_level: int) -> bool`

验收标准：

- `UpgradeData` 可被其他 GDScript preload。
- 文件没有依赖尚未创建的成长系统类。

---

## 2. T02 - 创建 UpgradeCatalog 抽卡逻辑

目标：实现三选一升级池抽取，不接 UI。

允许修改：

- 新建 `scripts/progression/upgrade_catalog.gd`

可读取：

- `scripts/progression/upgrade_data.gd`

执行步骤：

1. 定义 `class_name UpgradeCatalog extends RefCounted`。
2. 内部保存 `var upgrades: Array[UpgradeData] = []`。
3. 实现 `setup(p_upgrades: Array[UpgradeData]) -> void`。
4. 实现 `get_choices(selected_levels: Dictionary, count: int = 3) -> Array[UpgradeData]`。
5. 过滤规则：
   - 已达到 `max_level` 的升级不出现。
   - `prerequisites` 中有未获得升级则不出现。
   - `exclusions` 中任一升级已获得则不出现。
   - 同一轮不重复。
6. 按 `rarity_weight` 加权随机。
7. 尽量避免 3 个选项同类别；如果做不到，允许重复类别但不能重复升级。

验收标准：

- 可以用手动构造的 4 个 `UpgradeData` 返回 3 个候选。
- 已满级升级不会返回。
- 候选不足 3 个时返回实际可用数量，不报错。

---

## 3. T03 - 创建 PlayerProgression 基础等级系统

目标：实现等级、经验、连续升级和待选项队列，不接击杀。

允许修改：

- 新建 `scripts/progression/player_progression.gd`

可读取：

- `scripts/progression/upgrade_data.gd`
- `scripts/progression/upgrade_catalog.gd`

执行步骤：

1. 定义 `class_name PlayerProgression extends Node`。
2. 增加信号：
   - `xp_changed(level: int, xp: int, xp_to_next: int)`
   - `level_up(new_level: int, options: Array)`
   - `upgrade_applied(upgrade_id: String, upgrade_level: int)`
   - `player_power_changed(power_score: float)`
3. 增加状态：
   - `level: int = 1`
   - `xp: int = 0`
   - `xp_to_next: int`
   - `selected_levels: Dictionary = {}`
   - `pending_level_ups: int = 0`
   - `current_options: Array = []`
   - `xp_mult: float = 1.0`
4. 实现 `reset() -> void`。
5. 实现 `get_xp_to_next(p_level: int) -> int`，公式：
   - `round(12 + 6 * p_level + 1.5 * pow(p_level, 1.5))`
6. 实现 `add_xp(amount: int) -> void`：
   - 应用 `xp_mult`
   - 支持一次获得大量经验连续升级
   - 升级时只增加 `pending_level_ups` 并触发下一次选项
7. 先提供临时空升级池逻辑：如果没有可选升级，只发空 options，不崩溃。

验收标准：

- `reset()` 后是 Lv1、0 XP。
- `add_xp(20)` 后能升到 Lv2。
- `add_xp(999)` 能产生多次待升级，不丢失。

---

## 4. T04 - 创建 12 个 MVP UpgradeData 资源

目标：提供第一批升级资源。

允许修改：

- 新建 `assets/upgrades/*.tres`

可读取：

- `scripts/progression/upgrade_data.gd`

执行步骤：

创建以下资源，字段必须完整：

1. `rifle_damage.tres`
   - `upgrade_id = "rifle_damage"`
   - 类别：WEAPON
   - 目标：`rifle`
   - 属性：`damage_mult`
   - 操作：MULTIPLY
   - 最高 5 级
   - 每级约 +10%
2. `shotgun_damage.tres`
   - 每级霰弹枪伤害约 +8%，最高 5 级
3. `reload_speed.tres`
   - 全武器换弹时间每级 -8%，最高 5 级
4. `whip_range.tres`
   - 铁鞭范围每级 +0.5m，最高 4 级
5. `whip_cooldown.tres`
   - 铁鞭冷却每级 -8%，最高 5 级
6. `whip_stun.tres`
   - 铁鞭眩晕每级 +12%，最高 5 级
7. `max_health.tres`
   - 最大生命每级 +20，最高 5 级
8. `max_armor.tres`
   - 最大护甲每级 +25，最高 4 级
9. `move_speed.tres`
   - 移动速度每级 +4%，最高 4 级
10. `ammo_loot.tres`
   - 弹药掉落数量每级 +20%，最高 5 级
11. `health_loot.tres`
   - 血包恢复量每级 +15%，最高 4 级
12. `drop_abundance.tres`
   - 总掉落概率每级 +5 个百分点，最高 4 级

验收标准：

- 所有 `.tres` 能被 Godot 加载。
- 每个 `upgrade_id` 唯一。
- `values_by_level` 长度不小于 `max_level`。

---

## 5. T05 - GameBus 增加成长信号

目标：让成长系统能与 Main、HUD、刷怪系统通信。

允许修改：

- `scripts/core/game_bus.gd`

执行步骤：

1. 增加信号：
   - `xp_changed(level: int, xp: int, xp_to_next: int)`
   - `level_up(new_level: int, options: Array)`
   - `upgrade_applied(upgrade_id: String, upgrade_level: int)`
   - `player_power_changed(power_score: float)`
2. 增加共享引用：
   - `var player_progression = null`

验收标准：

- 现有 GameBus 信号保持不变。
- 项目中旧调用不需要修改即可继续工作。

---

## 6. T06 - Main 接入 PlayerProgression

目标：每局创建/重置玩家成长系统，但先不接 UI。

允许修改：

- `scripts/main.gd`

可读取：

- `scripts/progression/player_progression.gd`
- `scripts/core/game_bus.gd`

执行步骤：

1. 在 `main.gd` preload `PlayerProgression`。
2. 增加 `_player_progression: PlayerProgression` 变量。
3. 在 `_ready()` 或 `_start_level()` 创建成长节点，并加入合适父节点。
4. 设置 `GameBus.player_progression = _player_progression`。
5. 在 `_reset_player_for_level()` 调用 `_player_progression.reset()`。
6. 连接 `_player_progression.xp_changed` 到 GameBus 或 HUD 需要的转发函数。
7. 连接 `_player_progression.level_up`，先只打印日志。

验收标准：

- 进关后成长系统存在。
- 重开/切关后等级和经验重置。
- 还没有升级 UI 时不影响正常游戏。

---

## 7. T07 - EnemyData 增加 xp_value 并补资源数值

目标：敌人具备经验值配置。

允许修改：

- `scripts/enemy/enemy_data.gd`
- `assets/enemies/ground_enemy.tres`
- `assets/enemies/ranged_enemy.tres`
- `assets/enemies/flying_enemy.tres`
- `assets/enemies/orc_melee.tres`
- `assets/enemies/advanced_ground_enemy.tres`
- `assets/enemies/advanced_ranged_enemy.tres`
- `assets/enemies/advanced_flying_enemy.tres`
- `assets/enemies/flying_ranged_enemy.tres`
- `assets/enemies/elite_ground_enemy.tres`

执行步骤：

1. 在 `EnemyData` 增加 `@export var xp_value: int = 5`。
2. 给资源写入经验：
   - `ground_enemy = 5`
   - `ranged_enemy = 8`
   - `flying_enemy = 8`
   - `orc_melee = 10`
   - `advanced_ground_enemy = 12`
   - `advanced_ranged_enemy = 14`
   - `advanced_flying_enemy = 15`
   - `flying_ranged_enemy = 16`
   - `elite_ground_enemy = 30`

验收标准：

- 旧敌人仍可生成。
- 每个目标资源都能看到 `xp_value`。

---

## 8. T08 - 击杀敌人获得经验

目标：打通“击杀 -> 经验增加”。

允许修改：

- `scripts/enemy/enemy_manager.gd`
- `scripts/main.gd`
- 如需要，`scripts/progression/player_progression.gd`

执行步骤：

1. 修改 `EnemyManager.enemy_killed` 信号，使其携带 `xp_value`：
   - 建议签名：`enemy_killed(enemy_name: String, score_value: int, xp_value: int)`
2. 在 `_on_enemy_died()` 中从 `enemy.enemy_data.xp_value` 读取经验。
3. 更新所有连接该信号的地方：
   - `main.gd`
   - `player_status.gd` 如有回调参数需要同步
4. 在 `main.gd._on_enemy_killed_for_score()` 中：
   - 继续加分
   - 调用 `_player_progression.add_xp(xp_value)`
5. 如果读不到 xp_value，则回退为 `max(3, round(score_value * 0.5))`。

验收标准：

- 击杀近战恶魔获得 5 XP。
- 击杀高价值敌人获得更多 XP。
- 击杀计数和分数仍正常。

---

## 9. T09 - 新增 LEVEL_UP 游戏状态

目标：升级时暂停且不与普通暂停混淆。

允许修改：

- `scripts/core/game_state.gd`
- `scripts/main.gd`

执行步骤：

1. 在 `GameState.State` 增加 `LEVEL_UP`。
2. 在 `main.gd._set_game_state()` 中处理：
   - 显示鼠标
   - `get_tree().paused = true`
   - 不显示暂停菜单
   - HUD 和准星可以保持可见
3. 从 LEVEL_UP 恢复 PLAYING 时：
   - 隐藏升级面板
   - 捕获鼠标
   - `get_tree().paused = false`

验收标准：

- 升级状态下敌人和刷怪不继续运行。
- Esc 暂停菜单仍可正常使用。

---

## 10. T10 - 创建 LevelUpPanel 三选一 UI

目标：做可见、可点击的升级选择面板。

允许修改：

- 新建 `scripts/ui/level_up_panel.gd`

可读取：

- `scripts/progression/upgrade_data.gd`

执行步骤：

1. 定义 `class_name LevelUpPanel extends CanvasLayer`。
2. `process_mode = Node.PROCESS_MODE_ALWAYS`，保证暂停时可点击。
3. 创建半透明背景。
4. 创建标题：`升级！选择一项能力`。
5. 创建 3 个卡片按钮。
6. 实现 `show_options(level: int, options: Array) -> void`。
7. 实现 `hide_panel() -> void`。
8. 发出 `upgrade_chosen(index: int)` 信号。
9. 支持键盘 `1 / 2 / 3` 选择。

验收标准：

- 调用 `show_options()` 后面板可见。
- 鼠标点击和键盘 1/2/3 都能发出选择信号。
- 面板隐藏时不吞输入。

---

## 11. T11 - Main 接入升级面板

目标：升级时真正显示三选一，选择后恢复游戏。

允许修改：

- `scripts/main.gd`
- `scripts/progression/player_progression.gd`
- `scripts/ui/level_up_panel.gd`

执行步骤：

1. `main.gd` preload `LevelUpPanel`。
2. 在 UI 下创建 `_level_up_panel`。
3. 连接 `_player_progression.level_up` 到 `_on_player_level_up`。
4. `_on_player_level_up(level, options)`：
   - 调用 `_set_game_state(GameState.State.LEVEL_UP)`
   - 调用 `_level_up_panel.show_options(level, options)`
5. 连接 `upgrade_chosen(index)`：
   - 调用 `_player_progression.select_upgrade(index)`
   - 如果还有待处理升级，继续显示下一组
   - 否则恢复 PLAYING

验收标准：

- 获得足够经验后弹出面板。
- 选择一项后面板关闭，游戏继续。
- 连续升级时能连续选择，不丢升级。

---

## 12. T12 - PlayerProgression 加载升级资源并应用选择

目标：三选一不再是空选项，能记录升级等级。

允许修改：

- `scripts/progression/player_progression.gd`

可读取：

- `assets/upgrades/*.tres`
- `scripts/progression/upgrade_catalog.gd`

执行步骤：

1. 在 `PlayerProgression` 中加载 12 个 MVP `.tres`。
2. 初始化 `UpgradeCatalog`。
3. 升级时调用 catalog 生成 3 个 options。
4. 实现 `select_upgrade(index)`：
   - 校验 index
   - 读取 upgrade
   - `selected_levels[upgrade_id] += 1`
   - 发出 `upgrade_applied`
   - 更新 power_score
   - 处理下一个 pending level up
5. 暂时只记录等级，不应用实际数值。

验收标准：

- 升级面板显示真实升级名。
- 选择后该升级等级增加。
- 满级后不再出现在选项里。

---

## 13. T13 - 武器运行时倍率

目标：让武器升级可以安全修改当前局数值。

允许修改：

- `scripts/weapon/weapon_node.gd`

执行步骤：

1. 增加运行时倍率字段：
   - `damage_mult: float = 1.0`
   - `fire_rate_mult: float = 1.0`
   - `reload_time_mult: float = 1.0`
   - `spread_mult: float = 1.0`
   - `pellet_bonus: int = 0`
2. 所有伤害读取改为 `weapon_data.damage * damage_mult`。
3. 射速冷却改为 `1.0 / (weapon_data.fire_rate * fire_rate_mult)`。
4. 换弹时间改为 `weapon_data.reload_time * reload_time_mult`。
5. 散布角改为 `weapon_data.spread_angle * spread_mult`。
6. 弹丸数量改为 `weapon_data.pellet_count + pellet_bonus`。
7. `reset_ammo()` 不重置升级倍率，新增 `reset_runtime_modifiers()` 重置倍率。

验收标准：

- 默认倍率下武器表现不变。
- 手动设置 `damage_mult = 2.0` 后造成双倍伤害。

---

## 14. T14 - WeaponManager 提供升级接口

目标：PlayerProgression 能按目标武器应用升级。

允许修改：

- `scripts/weapon/weapon_manager.gd`

执行步骤：

1. 增加 `apply_weapon_upgrade(target_id: String, stat_key: String, value: float, operation: int) -> void`。
2. 支持目标：
   - `"all_weapons"`
   - `"rifle"`
   - `"shotgun"`
   - `"pistol"`
   - `"fist"`
3. 支持属性：
   - `damage_mult`
   - `fire_rate_mult`
   - `reload_time_mult`
   - `spread_mult`
   - `pellet_bonus`
4. 支持操作 ADD、MULTIPLY、SET。
5. 增加 `reset_runtime_modifiers()`，遍历所有武器重置倍率。

验收标准：

- 能单独强化步枪。
- 能对所有武器应用换弹倍率。
- 重开关卡时倍率重置。

---

## 15. T15 - 铁鞭运行时升级接口

目标：铁鞭类升级能修改当前局副本。

允许修改：

- `scripts/weapon/iron_whip.gd`
- `scripts/main.gd`

执行步骤：

1. 在 `IronWhip.setup()` 中对传入 `WhipData` 执行 `duplicate(true)`。
2. 增加 `apply_whip_upgrade(stat_key: String, value: float, operation: int) -> void`。
3. 支持属性：
   - `whip_range`
   - `cooldown`
   - `stun_damage`
   - `dash_distance`
   - `dash_damage`
   - `throw_damage`
4. 支持 ADD、MULTIPLY、SET。

验收标准：

- 升级铁鞭范围不会修改 `assets/weapons/iron_whip.tres`。
- 重开后铁鞭恢复初始数值。

---

## 16. T16 - 生存属性升级接口

目标：生命、护甲、移速升级可生效。

允许修改：

- `scripts/player/player_controller.gd`
- `scripts/damage/damageable.gd`

执行步骤：

1. 在 PlayerController 增加运行时移速倍率：
   - `var move_speed_mult: float = 1.0`
2. 计算移动速度时使用 `move_speed * move_speed_mult * _speed_multiplier`。
3. 增加 `apply_survival_upgrade(stat_key, value, operation)` 或等价方法。
4. 支持：
   - `max_health`：增加 Damageable 最大生命，并同步当前生命增加。
   - `max_armor`：增加 Damageable 最大护甲，并同步当前护甲增加。
   - `move_speed_mult`：提高移动速度倍率。
5. 增加重置运行时属性的方法，用于关卡重开。

验收标准：

- 选择最大生命升级后最大生命和当前生命都增加。
- 选择最大护甲升级后最大护甲和当前护甲都增加。
- 选择移速升级后移动速度提升。

---

## 17. T17 - DropManager 掉落升级接口

目标：掉落数量和概率升级可生效。

允许修改：

- `scripts/pickup/drop_manager.gd`

执行步骤：

1. 增加字段：
   - `ammo_amount_mult: float = 1.0`
   - `health_amount_mult: float = 1.0`
   - `armor_amount_mult: float = 1.0`
   - `drop_chance_bonus: float = 0.0`
   - `extra_drop_chance: float = 0.0`
2. 在掉落概率计算中应用 `drop_chance_bonus`。
3. 在生成弹药、血包、护甲时应用数量倍率。
4. 增加 `apply_drop_upgrade(stat_key, value, operation)`。
5. 增加 `reset_runtime_modifiers()`。

验收标准：

- 弹药数量升级后新生成弹药补给量增加。
- 掉落概率升级后无掉落概率降低。

---

## 18. T18 - PlayerProgression 分发升级效果

目标：选择升级后实际改动武器/铁鞭/生存/掉落。

允许修改：

- `scripts/progression/player_progression.gd`
- `scripts/main.gd`

可读取：

- `scripts/weapon/weapon_manager.gd`
- `scripts/weapon/iron_whip.gd`
- `scripts/pickup/drop_manager.gd`
- `scripts/player/player_controller.gd`

执行步骤：

1. 给 `PlayerProgression` 增加引用注入方法：
   - `setup_targets(player, weapon_manager, iron_whip, drop_manager)`
2. 在 `main.gd` 每次创建/重置铁鞭和 DropManager 后更新 progression targets。
3. `select_upgrade()` 里根据 category 分发：
   - WEAPON -> WeaponManager
   - WHIP -> IronWhip
   - SURVIVAL -> PlayerController/Damageable
   - ECONOMY -> DropManager 或自身 xp_mult
4. 支持 `stat_key == "xp_mult"` 时修改 `PlayerProgression.xp_mult`。

验收标准：

- 12 个 MVP 升级至少 10 个能实际生效。
- 升级后 `upgrade_applied` 发出。
- 重开关卡后升级效果重置。

---

## 19. T19 - HUD 显示等级和经验条

目标：玩家能看到当前等级和经验进度。

允许修改：

- `scripts/ui/player_status.gd`
- 如需要，`scripts/main.gd`

执行步骤：

1. 在左上角分数/击杀/时间/强度附近新增：
   - 等级 Label
   - XP Label
   - XP 条背景和填充
2. 监听 `GameBus.xp_changed` 或 progression 信号。
3. 监听 `GameBus.upgrade_applied` 显示通知。
4. 重开关卡时重置显示。

验收标准：

- 开局显示 Lv1 和 0 XP。
- 击杀后 XP 条增长。
- 升级后等级增加，XP 条归入下一等级。

---

## 20. T20 - 升级通知显示真实名称

目标：选择升级后显示“升级名 LvN”，而不是只显示 id。

允许修改：

- `scripts/progression/player_progression.gd`
- `scripts/ui/player_status.gd`
- `scripts/core/game_bus.gd` 如信号需要扩展

执行步骤：

1. 扩展 `upgrade_applied` 信号，携带 display_name：
   - 推荐：`upgrade_applied(upgrade_id, display_name, upgrade_level)`
2. 更新所有 emit 和 connect。
3. HUD 通知显示：`{display_name} Lv{upgrade_level}`。

验收标准：

- 选择“步枪膛线”后显示“步枪膛线 Lv1”。
- 不破坏已有 pickup 通知。

---

## 21. T21 - SpawnManager 使用 8 档难度表

目标：把现有 6 档强度改为设计文档的 8 档。

允许修改：

- `scripts/enemy/spawn_manager.gd`

执行步骤：

1. 定义 `DIFFICULTY_TIERS` 数据表，包含：
   - tier
   - start_time
   - expected_level
   - active_limit
   - spawn_interval
   - wave_budget
2. 替换 `_update_intensity()` 的硬编码时间段。
3. 替换 `_get_spawn_interval()`。
4. 替换 `_get_active_enemy_limit()`。
5. 替换 `_get_wave_budget()`。

验收标准：

- 0:00 是强度 1。
- 10:00 后进入强度 8。
- 游戏仍能正常刷怪。

---

## 22. T22 - SpawnManager 读取玩家等级并做成长修正

目标：刷怪根据玩家等级轻微修正。

允许修改：

- `scripts/enemy/spawn_manager.gd`
- `scripts/main.gd`

执行步骤：

1. `SpawnManager.setup()` 增加 progression 参数，或从 `GameBus.player_progression` 获取。
2. 实现 `_get_player_level() -> int`。
3. 实现 `_get_expected_level(time: float) -> int`。
4. 实现 `_get_growth_adjusted_tier(base_tier: int) -> int`：
   - 玩家超前 >= 5 级：临时 +1 档，但不超过当前时间下一档。
   - 玩家超前 3-4 级：不改档，预算/高级权重增加。
   - 玩家落后不降低档。
5. 让预算和权重读取成长修正。

验收标准：

- 等级超前时刷怪压力略增。
- 等级落后时刷怪强度不降低。

---

## 23. T23 - 落后追赶经验和掉落修正

目标：玩家落后时获得轻微追赶资源。

允许修改：

- `scripts/enemy/spawn_manager.gd`
- `scripts/progression/player_progression.gd`
- `scripts/pickup/drop_manager.gd`
- `scripts/main.gd`

执行步骤：

1. SpawnManager 计算 `level_delta = player_level - expected_level`。
2. 当 `level_delta <= -3`：
   - progression 经验倍率额外 +10%
   - drop_manager 掉落概率额外 +5pp
3. 当 `level_delta` 在 -2 到 -1：
   - progression 经验倍率额外 +5%
4. 注意与熔岩地狱 +10% 经验/掉落叠加时不要重复覆盖基础倍率。

验收标准：

- 落后严重时击杀经验提高。
- 落后严重时掉落概率提高。
- 玩家追上后追赶倍率回落。

---

## 24. T24 - SpawnProfile 关卡差异化

目标：荒漠更标准，熔岩地狱更难。

允许修改：

- `scripts/enemy/spawn_manager.gd`

执行步骤：

1. 定义 `SpawnProfile` 数据结构或字典。
2. 添加 `desert`：
   - active_limit x0.90
   - spawn_interval x1.12
   - wave_budget x0.90
3. 添加 `lava`：
   - active_limit x1.20
   - spawn_interval x0.90
   - wave_budget x1.15
   - enemy_health x1.10
   - enemy_damage x1.10
   - enemy_speed x1.05
4. 应用到刷怪上限、间隔、预算。

验收标准：

- 同时间 lava 场上敌人数倾向高于 desert。
- lava 刷怪更快。

---

## 25. T25 - 熔岩地狱敌人运行时倍率

目标：lava 敌人更强，但不污染资源。

允许修改：

- `scripts/enemy/spawn_manager.gd`

执行步骤：

1. 生成敌人时加载 EnemyData 后执行 `duplicate(true)`。
2. 如果 profile 是 lava：
   - `max_health *= 1.10`
   - `attack_damage *= 1.10`
   - `move_speed *= 1.05`
3. 把副本设置给敌人。

验收标准：

- lava 关生成敌人的数据是副本。
- 回到 desert 后敌人数值不带 lava 倍率。

---

## 26. T26 - 熔岩地狱 +10% 经验/掉落补偿

目标：高风险高收益。

允许修改：

- `scripts/main.gd`
- `scripts/progression/player_progression.gd`
- `scripts/pickup/drop_manager.gd`

执行步骤：

1. 进入 lava 关时设置基础经验倍率 x1.10。
2. 进入 lava 关时设置基础掉落收益或掉落概率 x1.10。
3. 进入 desert/test 时恢复基础倍率 x1.00。
4. 确保此倍率可与落后追赶倍率叠加。

验收标准：

- 同一敌人在 lava 给更多 XP。
- lava 掉落收益或概率高于 desert。
- 切回 desert 后倍率恢复。

---

## 27. T27 - 调整荒漠/熔岩敌人权重和解锁

目标：关卡体验差异明显。

允许修改：

- `scripts/enemy/spawn_manager.gd`

执行步骤：

1. 荒漠权重：
   - 提高 ground_enemy、orc_melee、advanced_ground_enemy
   - 降低 flying 和 flying_ranged
   - elite 不早于强度 7
2. 熔岩权重：
   - 提高 ranged、advanced_ranged、flying、advanced_flying、flying_ranged
   - 高级敌人解锁提前 1 档
   - elite 强度 6 起低权重出现
3. 保留当前可运行的随机选择方式。

验收标准：

- 3 分钟 lava 的远程/飞行比例明显高于 desert。
- 6 分钟 lava 可能出现精英，desert 不应过早出现。

---

## 28. T28 - Roadmap 5 专项手动测试文档

目标：给调试和后续验收留下明确步骤。

允许修改：

- 新建 `docs/roadmap5-test-checklist.md`

执行步骤：

1. 写测试步骤：
   - 开局等级/经验显示
   - 击杀加经验
   - 升级暂停
   - 三选一选择
   - 武器升级
   - 铁鞭升级
   - 生存升级
   - 掉落升级
   - 重开重置
   - 荒漠/熔岩对比
2. 写每项预期结果。
3. 写记录表格：时间、等级、击杀、强度、敌人压力、备注。

验收标准：

- 测试者不读源码也能按文档验证 Roadmap 5。

---

## 29. T29 - 临时调试加经验入口

目标：快速测试连续升级。

允许修改：

- `scripts/main.gd`
- `scripts/progression/player_progression.gd`
- 如需要，`project.godot` 输入映射

执行步骤：

1. 增加一个明确标记为调试用途的 `debug_add_xp(amount)`。
2. 可选：绑定临时按键，比如 `F9` 加 200 XP。
3. 必须用 `@export var debug_progression_enabled := false` 或类似开关保护。

验收标准：

- 开启调试后能快速触发升级。
- 默认关闭时不会影响正常游戏。

---

## 30. T30 - 10 分钟荒漠流程调参

目标：让荒漠流程接近目标等级节奏。

允许修改：

- `scripts/enemy/spawn_manager.gd`
- `assets/enemies/*.tres`
- `assets/upgrades/*.tres`

执行步骤：

1. 运行荒漠关。
2. 记录 1/3/5/10 分钟：
   - 等级
   - XP
   - 击杀
   - 强度
   - 场上敌人数量
   - 死亡原因或压力来源
3. 调整经验值、刷怪预算、刷新间隔或升级数值。
4. 目标：
   - 1 分钟 Lv3 左右
   - 3 分钟 Lv7 左右
   - 5 分钟 Lv11 左右
   - 10 分钟 Lv20 左右

验收标准：

- 荒漠 10 分钟流程可玩。
- 等级曲线接近目标。

---

## 31. T31 - 10 分钟熔岩地狱流程调参

目标：熔岩明显更难，但不是无解。

允许修改：

- `scripts/enemy/spawn_manager.gd`
- `assets/enemies/*.tres`
- `scripts/level/lava_arena.gd`

执行步骤：

1. 运行熔岩地狱。
2. 记录 1/3/5/10 分钟等级、击杀、强度、死亡原因。
3. 确认远程/飞行/高级敌人比例高于荒漠。
4. 若过难，优先调低飞行远程权重或精英出现率，不要取消关卡特色。
5. 保留 +10% 经验/掉落补偿。

验收标准：

- 熔岩同时间压力明显高于荒漠。
- 玩家有成长追赶空间。

---

## 32. T32 - Roadmap 5 回归测试与修复

目标：确保新系统没有破坏已有功能。

允许修改：

- 只修改本任务发现的 bug 相关文件

执行步骤：

1. 测试主菜单。
2. 测试选关。
3. 测试暂停和恢复。
4. 测试死亡结算。
5. 测试重开。
6. 测试武器切换、射击、换弹。
7. 测试铁鞭抓取、盾牌、甩出、冲刺处决。
8. 测试掉落、生命、护甲。
9. 测试升级暂停和连续升级。
10. 修复发现的问题。

验收标准：

- Roadmap 4 已有战斗和 UI 功能仍正常。
- Roadmap 5 核心闭环稳定。

---

## 33. 建议投喂给 AI 的顺序

第一轮最小闭环：

1. T01
2. T02
3. T03
4. T04
5. T05
6. T06
7. T07
8. T08
9. T09
10. T10
11. T11
12. T12
13. T13
14. T14
15. T16
16. T18
17. T19

第一轮完成后，游戏应具备：

- 击杀获得经验。
- 满经验升级。
- 升级时暂停。
- 出现三选一。
- 选择武器/生命/移速升级后立即生效。
- HUD 显示等级和经验。

第二轮补完整系统：

1. T15
2. T17
3. T20
4. T21
5. T22
6. T23
7. T24
8. T25
9. T26
10. T27

第三轮验证和打磨：

1. T28
2. T29
3. T30
4. T31
5. T32


# DoomLike Roadmap 2 — 生存关卡、铁鞭与敌人体系

> 目标：在现有 FPS 原型基础上，转向“圆形竞技场生存”核心循环。玩家从开始菜单进入选关界面，在荒漠或熔岩地狱中坚持更久、击杀更多敌人、获得更高分。所有 3D 模型先用简单几何体和不同颜色区分，先保证玩法结构完整。

## 设计边界

- [ ] 两个关卡均为大圆形可移动区域，基础地形用平面组成。
- [ ] 圆形边界必须有明显视觉标志，玩家继续向外移动时提示“已到达边界”。
- [ ] 敌人从圆形区域边界外刷新，并向玩家活动区域推进。
- [ ] 枯树、熔岩河流、柱状岩石每次开始游戏时随机生成位置。
- [ ] 第一关：荒漠场景，枯树作为掩体。
- [ ] 第二关：熔岩地狱场景，熔岩河流持续伤害，柱状岩石作为掩体。
- [ ] 鼠标左键保留现有枪械射击，鼠标右键新增左手铁鞭。
- [ ] 铁鞭可击退敌人、增加眩晕值；敌人眩晕满后可被拉至身前并抓取。
- [ ] 抓取敌人后，玩家移动速度受敌人重量影响；抓取敌人可处决，也可作为盾牌抵挡攻击。
- [ ] 不同武器对敌人造成不同眩晕值。
- [ ] 敌人拥有血量、眩晕值、重量、移动速度、分数等参数。
- [ ] 随游戏时间增加，敌人刷新频率逐渐提高。

## Phase 0：前置整理与运行稳定 ✅

> 在进入新系统前，先把会影响后续扩展的基础问题收束，避免菜单、关卡、刷怪、抓取互相踩状态。

### 0.1 建立当前基线

- [x] 运行一次项目，记录当前能否进入主场景、能否移动、能否射击、敌人是否攻击玩家。
- [x] 如果 Godot 命令行不可用，记录本机 Godot 可执行文件路径，后续统一使用同一个运行方式验证。
- [x] 打开 `scenes/main.tscn`，确认当前主场景仍为 `Main -> Player / Level / UI`。
- [x] 打开 `scenes/player/player.tscn`，确认 `WeaponManager` 位于 `Player/Camera3D/WeaponHolder/WeaponManager`。
- [x] 打开 `scripts/main.gd`，标记当前 `_load_level()` 只是初始化场景内已有 Level，不再视为 LevelData 加载管线。
- [x] 在 `docs/project_roadmap.md` 顶部或相关阶段旁补充说明：Phase 5、Phase 6 暂缓，新方向以 `project_roadmap2.md` 为准。

### 0.2 固定目录和职责边界

- [x] 新建目录 `scripts/core/`，用于运行状态、存档、统计。
- [x] 新建目录 `scripts/level/`，用于竞技场关卡、随机生成、关卡注册。
- [x] 新建目录 `scripts/level/props/`，用于枯树、岩柱等掩体。
- [x] 新建目录 `scripts/level/hazards/`，用于熔岩等危险区域。
- [x] 新建目录 `scenes/levels/`，用于荒漠和熔岩关卡场景。
- [x] 新建目录 `scenes/ui/`，用于主菜单、选关、结算界面。
- [x] 明确 `Main` 只负责游戏状态切换、关卡实例化/卸载、全局信号连接。
- [x] 明确当前关卡节点只负责自身地形、边界、随机物件、危险区域和刷怪接口。
- [x] 明确 `UI` 下的菜单和 HUD 只显示状态，不直接创建敌人或改关卡结构。

### 0.3 修复武器输入归属

- [x] 在 `scripts/weapon/weapon_node.gd` 增加 `_is_equipped: bool`。
- [x] `_on_equip()` 中设置 `_is_equipped = true`，并显示当前武器。
- [x] `_on_unequip()` 中设置 `_is_equipped = false`，并隐藏当前武器。
- [x] `WeaponNode._input()` 开头检查 `_is_equipped`，未装备时直接返回。
- [x] `WeaponNode._process()` 中全自动开火逻辑也检查 `_is_equipped`。
- [x] 切到手枪时开火，确认霰弹枪弹药不减少。
- [x] 切到霰弹枪时开火，确认手枪弹药不减少。
- [x] 切武器时 HUD 弹药显示与当前武器一致。

### 0.4 修复换弹和延迟动作的旧 timer

- [x] 在 `WeaponNode` 中增加 `_reload_token: int`。
- [x] 每次 `_start_reload()` 时递增 token，并把当前 token 绑定给 `_finish_reload(token)`。
- [x] `_finish_reload(token)` 先检查 token 是否仍等于 `_reload_token`，不一致则返回。
- [x] `_on_unequip()` 中递增 `_reload_token`，使旧换弹 timer 失效。
- [x] 在泵动流程中增加类似 `_pump_token`，切武器后旧泵动 timer 不再恢复开火状态。
- [x] 在 `DemonSoldier` 延迟射击中增加有效性检查：敌人死亡、玩家为空、状态不允许攻击时不再造成伤害。
- [x] 验证：换弹中切武器，等待原换弹时间结束，旧武器不会偷偷补弹或触发 HUD。

### 0.5 统一玩家引用方式

- [x] 在 `scripts/player/player_controller.gd` 的 `_ready()` 中调用 `add_to_group("player")`。
- [x] 给玩家创建 Damageable 前，先检查是否已有 `Damageable` 子节点，避免重复创建。
- [x] 在 `scripts/enemy/enemy.gd` 中优先通过 `get_tree().get_first_node_in_group("player")` 获取玩家。
- [x] 保留 `/root/Main/Player` 作为临时 fallback，但注释说明后续应移除硬编码路径。
- [x] 验证敌人放在测试场景或未来关卡子场景时，也能找到玩家并追击。

### 0.6 修复 EnemyManager 注册模型

- [x] 在 `scripts/enemy/enemy_manager.gd` 中新增 `register_enemy(enemy: Enemy) -> void`。
- [x] `register_enemy()` 检查敌人是否已存在，避免重复加入 `active_enemies`。
- [x] `register_enemy()` 连接 `enemy_died` 信号，连接前检查是否已连接。
- [x] 新增 `unregister_enemy(enemy: Enemy) -> void`，用于敌人死亡或关卡卸载时清理。
- [x] 修改 `spawn_enemy()`：先创建敌人、设置 `enemy_data` 和位置，再 `add_child()`，最后调用 `register_enemy()`。
- [x] 在 `EnemyManager._ready()` 中扫描父节点或当前关卡下已有敌人，并调用 `register_enemy()`。
- [x] 验证主场景中手动摆放的敌人死亡后，HUD 击杀计数会更新。
- [x] 验证动态生成的敌人死亡后，`active_enemies` 会减少。

### 0.7 修复 CSG 碰撞启用范围

- [x] 在 `scripts/main.gd` 中停止对整个 `Level` 递归启用所有 CSG 碰撞。
- [x] 给关卡地形节点加入 `level_geometry` group，或约定名称前缀 `Ground_`、`Wall_`、`Boundary_`。
- [x] `_enable_csg_collision()` 只处理 `level_geometry` group 或符合命名前缀的节点。
- [x] 明确跳过敌人、武器、装饰模型中用于视觉占位的 CSGBox3D。
- [x] 更新 `scenes/main.tscn` 中现有地板节点，把它加入关卡几何识别规则。
- [x] 验证敌人身体部件仍保持 `use_collision = false`，敌人只使用 Capsule 碰撞体。
- [x] 验证玩家仍能站在地面上，子弹仍能命中地面/墙体。

### 0.8 Phase 0 验收

- [x] 项目能正常进入主场景。
- [x] 玩家移动、跳跃、鼠标视角正常。
- [x] 当前装备武器唯一响应开火和换弹。
- [x] 敌人能找到玩家并攻击。
- [x] 手动摆放敌人和动态生成敌人都能被 EnemyManager 统计。
- [x] 关卡几何有碰撞，敌人视觉 CSG 不被强制打开碰撞。
- [x] 切武器、敌人死亡、玩家死亡后没有旧 timer 继续造成明显副作用。

## Phase 1：游戏流程、菜单与记录

### 1.1 创建运行状态枚举

- [x] 在 `scripts/core/game_state.gd` 或 `scripts/main.gd` 中定义状态：`BOOT`、`MAIN_MENU`、`LEVEL_SELECT`、`PLAYING`、`PAUSED`、`GAME_OVER`。
- [x] 在 `main.gd` 中新增 `_game_state` 字段，默认进入 `BOOT`。
- [x] 新增 `_set_game_state(next_state)` 方法，统一处理状态切换。
- [x] 状态进入 `MAIN_MENU` 时显示主菜单，隐藏选关、结算、HUD。
- [x] 状态进入 `LEVEL_SELECT` 时显示选关，隐藏主菜单、结算。
- [x] 状态进入 `PLAYING` 时隐藏菜单，显示 HUD，捕获鼠标。
- [x] 状态进入 `GAME_OVER` 时释放鼠标，显示结算界面，暂停或停止刷怪。
- [x] 临时保留 `Esc` 释放鼠标行为，但确保不会在菜单中直接退出游戏。

### 1.2 主菜单 UI

- [x] 新建 `scenes/ui/main_menu.tscn`，根节点使用 `Control`。
- [x] 新建 `scripts/ui/main_menu.gd` 并挂到主菜单根节点。
- [x] 主菜单添加标题 `DoomLike`。
- [x] 主菜单添加“开始游戏”按钮。
- [x] 主菜单添加“退出游戏”按钮。
- [x] `main_menu.gd` 定义 `start_requested` 信号。
- [x] 点击“开始游戏”发出 `start_requested`。
- [x] 点击“退出游戏”调用 `get_tree().quit()`。
- [x] 在 `main.gd` 中实例化或引用主菜单，并连接 `start_requested` 到进入 `LEVEL_SELECT`。

### 1.3 选关 UI

- [x] 新建 `scenes/ui/level_select.tscn`，根节点使用 `Control`。
- [x] 新建 `scripts/ui/level_select.gd` 并挂到选关根节点。
- [x] 选关界面创建左右两个大按钮或面板。
- [x] 左侧显示“第一关：荒漠”。
- [x] 右侧显示“第二关：熔岩地狱”。
- [x] 每个关卡面板显示历史最高分。
- [x] 每个关卡面板显示历史最长时间。
- [x] `level_select.gd` 定义 `level_selected(level_id: String)` 信号。
- [x] 点击荒漠发出 `level_selected("desert")`。
- [x] 点击熔岩地狱发出 `level_selected("lava")`。
- [x] 添加“返回”按钮，返回主菜单。
- [x] 在 `main.gd` 中连接 `level_selected`，进入对应关卡加载流程。

### 1.4 结算 UI

- [x] 新建 `scenes/ui/game_over_screen.tscn`，根节点使用 `Control`。
- [x] 新建 `scripts/ui/game_over_screen.gd` 并挂到结算根节点。
- [x] 结算界面显示本局关卡名称。
- [x] 结算界面显示本局分数。
- [x] 结算界面显示本局坚持时间。
- [x] 结算界面显示本局击杀数。
- [x] 结算界面显示该关历史最高分。
- [x] 结算界面显示该关历史最长时间。
- [x] 如果刷新纪录，显示“新纪录”提示。
- [x] 添加“重新开始本关”按钮。
- [x] 添加“返回选关”按钮。
- [x] 添加“返回主菜单”按钮。
- [x] 在 `main.gd` 中连接三个按钮信号到对应流程。

### 1.5 当前局统计 RunStats

- [x] 新建 `scripts/core/run_stats.gd`，`class_name RunStats extends RefCounted`。
- [x] 添加字段：`level_id: String`、`score: int`、`kills: int`、`survival_time: float`、`is_running: bool`。
- [x] 添加 `start(level_id: String)`，重置分数、击杀、时间并开始计时。
- [x] 添加 `stop()`，停止计时。
- [x] 添加 `update(delta)`，只在 `is_running` 时累加 `survival_time`。
- [x] 添加 `add_score(amount: int)`。
- [x] 添加 `add_kill(score_value: int)`，同时增加击杀数和分数。
- [x] 在 `main.gd` 的 `_process(delta)` 中更新当前 RunStats。
- [x] 让这些数据都实时显示到左上角FPS下面。
- [x] 敌人死亡时先临时按固定分数加分，后续 Phase 5 再接入 `EnemyData.score_value`。

### 1.6 存档 SaveData

- [x] 新建 `scripts/core/save_data.gd`，`class_name SaveData extends RefCounted`。
- [x] 使用 `ConfigFile` 读写 `user://save.cfg`。
- [x] 定义每关记录字段：`best_score`、`best_time`。
- [x] 添加 `load_records()`。
- [x] 添加 `save_records()`。
- [x] 添加 `get_best_score(level_id: String) -> int`。
- [x] 添加 `get_best_time(level_id: String) -> float`。
- [x] 添加 `submit_run(level_id: String, score: int, time: float) -> Dictionary`。
- [x] `submit_run()` 返回是否刷新最高分、是否刷新最长时间。
- [x] 第一次启动没有存档时，自动返回 0 分和 0 秒。
- [x] 验证关闭游戏再打开后，选关界面仍能显示历史记录。

### 1.7 关卡启动和结束流程

- [x] 在 `main.gd` 中新增 `_start_level(level_id: String)`。
- [x] `_start_level()` 调用 Phase 2 的关卡加载接口；Phase 2 未完成前可先加载占位空关卡。
- [x] `_start_level()` 重置玩家位置、玩家生命值、武器弹药、EnemyManager、HUD。
- [x] `_start_level()` 调用 `run_stats.start(level_id)`。
- [x] `_start_level()` 切换状态到 `PLAYING`。
- [x] 在玩家 `Damageable.died` 时调用 `_end_run()`。
- [x] `_end_run()` 停止 RunStats。
- [x] `_end_run()` 调用 SaveData 提交记录。
- [x] `_end_run()` 把本局数据和历史数据传给结算 UI。
- [x] `_end_run()` 切换状态到 `GAME_OVER`。

### 1.8 HUD 扩展

- [x] 在 `scripts/ui/player_status.gd` 中增加分数 Label。
- [x] 在 `scripts/ui/player_status.gd` 中增加坚持时间 Label。
- [x] 在 `scripts/ui/player_status.gd` 中增加当前强度 Label，Phase 7 前可显示 `强度: 1`。
- [x] 新增 `set_run_stats(stats: RunStats)` 或通过 `main.gd` 定时推送数据。
- [x] 游戏未开始时隐藏分数和时间。
- [x] 游戏开始后每 0.1 秒刷新分数和时间。
- [x] 新增边界提示 Label，默认隐藏。
- [x] 添加 `show_boundary_warning()` 方法，显示“已到达边界”并在短时间后隐藏。

### 1.9 Phase 1 验收

- [x] 启动后先看到主菜单，而不是直接进入战斗。
- [x] 点击“开始游戏”进入选关。
- [x] 选关界面左侧荒漠、右侧熔岩地狱显示正确。
- [x] 两个关卡面板能显示历史最高分和最长时间。
- [x] 选择任意关卡后进入 `PLAYING` 状态，HUD 显示分数和时间。
- [x] 玩家死亡后进入结算界面。
- [x] 结算界面显示本局数据和历史数据。
- [x] 新纪录能写入 `user://save.cfg`。
- [x] 从结算返回选关后，记录显示已更新。

## Phase 2：圆形竞技场基础系统

### 2.1 关卡注册表

- [x] 新建 `scripts/level/level_registry.gd`，`class_name LevelRegistry extends RefCounted`。
- [x] 定义 `const DESERT := "desert"`。
- [x] 定义 `const LAVA := "lava"`。
- [x] 添加 `static func get_level_ids() -> Array[String]`，返回两个关卡 id。
- [x] 添加 `static func get_display_name(level_id: String) -> String`。
- [x] 添加 `static func get_scene_path(level_id: String) -> String`。
- [x] 荒漠路径先指向 `res://scenes/levels/desert_arena.tscn`。
- [x] 熔岩路径先指向 `res://scenes/levels/lava_arena.tscn`。
- [x] 添加 `static func get_description(level_id: String) -> String`，供选关界面显示。
- [x] 选关 UI 不硬编码关卡文字，改为读取 LevelRegistry。

### 2.2 ArenaLevel 基类脚本

- [x] 新建 `scripts/level/arena_level.gd`，`class_name ArenaLevel extends Node3D`。
- [x] 添加信号 `boundary_warning_requested()`。
- [x] 添加信号 `level_ready(arena: ArenaLevel)`。
- [x] 导出 `arena_radius: float = 45.0`。
- [x] 导出 `spawn_outer_radius: float = 55.0`。
- [x] 导出 `boundary_marker_count: int = 64`。
- [x] 导出 `random_seed: int = 0`。
- [x] 导出 `use_random_seed: bool = true`。
- [x] 添加节点容器字段：`_geometry_root`、`_boundary_root`、`_props_root`、`_hazards_root`、`_spawn_root`。
- [x] `_ready()` 中创建缺失的容器节点。
- [x] `_ready()` 中初始化随机数生成器。
- [x] `_ready()` 中调用 `_build_base_arena()`。
- [x] `_ready()` 中调用 `_build_boundary_markers()`。
- [x] `_ready()` 中发出 `level_ready`。

### 2.3 生成基础圆形地面

- [x] 在 `ArenaLevel` 中实现 `_build_base_arena()`。
- [x] 先使用一个大 `CSGBox3D` 或 `MeshInstance3D PlaneMesh` 作为地面，占位尺寸覆盖完整圆形区域。
- [x] 地面节点加入 `level_geometry` group。
- [x] 地面节点开启碰撞。
- [x] 添加 `_is_inside_arena(pos: Vector3) -> bool`，只检查 XZ 到中心距离。
- [x] 添加 `get_arena_center() -> Vector3`，默认返回关卡根节点 `global_position`。
- [x] 添加 `get_arena_radius() -> float`。
- [x] 后续正式圆形视觉可再替换，当前先保证移动和边界逻辑。

### 2.4 生成边界标志

- [x] 在 `ArenaLevel` 中实现 `_build_boundary_markers()`。
- [x] 按 `boundary_marker_count` 均匀遍历圆周角度。
- [x] 每个角度生成一个细高 CSGBox3D 作为边界柱。
- [x] 边界柱颜色使用高亮黄/红，便于远处识别。
- [x] 边界柱加入 `level_geometry` group。
- [x] 边界柱可开启碰撞，也可只作为视觉标志；先优先开启碰撞。
- [x] 给边界柱统一命名 `BoundaryMarker_%03d`。
- [x] 验证从中心看向任意方向都能看到边界标志。

### 2.5 玩家边界限制

- [x] 在 `ArenaLevel` 中添加 `player: CharacterBody3D` 引用。
- [x] 添加 `set_player(player_node: CharacterBody3D)`，由 `Main` 在加载关卡后调用。
- [x] 在 `_physics_process(delta)` 中检查玩家是否超过 `arena_radius`。
- [x] 如果玩家超过边界，计算从中心指向玩家的 XZ 方向。
- [x] 将玩家位置夹回 `arena_radius - 0.5` 内。
- [x] 清除或削弱玩家继续向外的水平速度，避免持续抖动。
- [x] 越界时发出 `boundary_warning_requested`。
- [x] 在 `main.gd` 中连接该信号到 HUD 的 `show_boundary_warning()`。
- [x] 验证玩家冲向边界时不会离开圆形区域。

### 2.6 ArenaRandomizer

- [x] 新建 `scripts/level/arena_randomizer.gd`，`class_name ArenaRandomizer extends RefCounted`。
- [x] 添加 `rng: RandomNumberGenerator` 字段。
- [x] 添加 `setup(seed_value: int, use_random_seed: bool)`。
- [x] 添加 `random_angle() -> float`。
- [x] 添加 `get_random_point_inside(center: Vector3, radius: float, margin: float) -> Vector3`。
- [x] 随机内部点使用 `sqrt(randf())` 分布，避免点集中在中心。
- [x] 添加 `get_random_point_outside_boundary(center: Vector3, arena_radius: float, spawn_outer_radius: float) -> Vector3`。
- [x] 外部刷新点在 `arena_radius` 和 `spawn_outer_radius` 之间选取。
- [x] 添加 `is_far_enough(point: Vector3, used_points: Array[Vector3], min_distance: float) -> bool`。
- [x] 添加 `try_get_non_overlapping_point(...) -> Dictionary`，返回 `{ "ok": bool, "position": Vector3 }`。

### 2.7 障碍物随机放置接口

- [x] 在 `ArenaLevel` 中维护 `_used_spawn_points: Array[Vector3]`。
- [x] 添加 `clear_randomized_content()`，清空 `_props_root` 和 `_hazards_root`。
- [x] 添加 `register_occupied_point(pos: Vector3)`。
- [x] 添加 `get_random_prop_position(min_distance: float, center_safe_radius: float) -> Dictionary`。
- [x] 随机点必须在 `arena_radius` 内。
- [x] 随机点必须距离中心出生点大于 `center_safe_radius`。
- [x] 随机点必须与已注册点保持 `min_distance`。
- [x] 随机失败超过最大尝试次数时返回 `ok = false`，调用方跳过该物件。

### 2.8 关卡场景占位

- [x] 新建 `scenes/levels/desert_arena.tscn`，根节点为 `Node3D`，挂 `arena_level.gd` 或后续 `desert_arena.gd`。
- [x] 设置荒漠 `arena_radius = 45.0`、`spawn_outer_radius = 56.0`。
- [x] 暂时把地面颜色设为沙黄色。
- [x] 新建 `scenes/levels/lava_arena.tscn`，根节点为 `Node3D`，挂 `arena_level.gd` 或后续 `lava_arena.gd`。
- [x] 设置熔岩 `arena_radius = 45.0`、`spawn_outer_radius = 56.0`。
- [x] 暂时把地面颜色设为暗红/黑色。
- [x] 两个场景先不生成枯树、熔岩、岩柱，只验证可加载和边界。

### 2.9 Main 关卡加载和卸载

- [x] 在 `main.gd` 中新增 `_current_level: Node3D`。
- [x] 在 `main.gd` 中新增 `_current_level_id: String`。
- [x] 在主场景 `Level` 下新增或复用一个 `CurrentLevelRoot` 容器。
- [x] 实现 `_unload_current_level()`：清理当前关卡、敌人、投射物、危险区域。
- [x] 实现 `_load_arena_level(level_id: String)`。
- [x] `_load_arena_level()` 通过 `LevelRegistry.get_scene_path(level_id)` 加载 PackedScene。
- [x] 实例化关卡后挂到 `CurrentLevelRoot`。
- [x] 如果关卡是 `ArenaLevel`，调用 `set_player(_player)`。
- [x] 连接关卡的 `boundary_warning_requested` 到 HUD。
- [x] 关卡加载后把玩家传送到关卡中心或 `PlayerStart`。
- [x] 加载失败时回到选关界面并显示错误提示。

### 2.10 玩家出生和重置

- [x] 在 `ArenaLevel` 中添加 `get_player_spawn_transform() -> Transform3D`。
- [x] 默认出生点为竞技场中心上方，朝向圆心外某个固定方向。
- [x] 如果关卡场景内存在 `PlayerStart`，优先使用 `PlayerStart.global_transform`。
- [x] 在 `_start_level()` 中使用 `get_player_spawn_transform()` 放置玩家。
- [x] 重置玩家水平和垂直速度。
- [x] 重置鼠标视角 yaw/pitch 或提供 `PlayerController.reset_view(transform)`。
- [x] 重置玩家 Damageable 血量到 max_health。
- [x] 重置武器弹药到开局状态。

### 2.11 Phase 2 验收

- [x] 从选关界面选择荒漠，能加载沙黄色圆形竞技场占位。
- [x] 从选关界面选择熔岩，能加载暗红色圆形竞技场占位。
- [x] 两个关卡都显示明显圆形边界柱。
- [x] 玩家无法走出圆形边界。
- [x] 玩家触碰边界时 HUD 显示“已到达边界”。
- [x] 退出本关再进入另一关，旧关卡节点已被清理。
- [x] 重复进入同一关不会叠加多个地面、边界或信号连接。
- [x] 随机数接口可以返回区域内点和边界外刷新点。

## Phase 3：第一关荒漠竞技场

### 3.1 DesertArena 脚本

- [ ] 新建 `scripts/level/desert_arena.gd`，`class_name DesertArena extends ArenaLevel`。
- [ ] 导出 `dead_tree_count: int = 24`。
- [ ] 导出 `dead_tree_min_distance: float = 5.0`。
- [ ] 导出 `dead_tree_safe_radius: float = 8.0`，避免出生点附近生成枯树。
- [ ] 导出 `ground_color: Color`，默认沙黄色。
- [ ] 导出 `boundary_color: Color`，默认偏黄白高亮。
- [ ] 覆写 `_get_ground_material()` 或提供类似方法，让基类地面使用荒漠颜色。
- [ ] 覆写 `_get_boundary_material()` 或提供类似方法，让边界柱使用荒漠边界颜色。
- [ ] 在 `_ready()` 或基类提供的生成钩子中调用 `_spawn_dead_trees()`。
- [ ] 保持 `ArenaLevel` 的边界、出生、随机点接口不变。

### 3.2 荒漠场景搭建

- [ ] 新建或更新 `scenes/levels/desert_arena.tscn`。
- [ ] 根节点命名为 `DesertArena`，类型为 `Node3D`。
- [ ] 根节点挂载 `scripts/level/desert_arena.gd`。
- [ ] 设置 `arena_radius = 45.0`。
- [ ] 设置 `spawn_outer_radius = 56.0`。
- [ ] 设置 `boundary_marker_count = 72`，让边界足够明显。
- [ ] 添加 `PlayerStart` 节点，放在圆心附近，例如 `(0, 1.6, 0)`。
- [ ] 添加 `DirectionalLight3D`，使用暖色光，模拟荒漠日照。
- [ ] 添加 `OmniLight3D` 或环境补光，避免占位模型过暗。
- [ ] 确认场景路径和 `LevelRegistry.DESERT` 的路径一致。

### 3.3 荒漠地面和边界表现

- [ ] 地面使用沙黄色材质。
- [ ] 地面碰撞加入 `level_geometry` group。
- [ ] 边界柱使用浅黄/白色，和地面有明显区分。
- [ ] 边界柱高度至少高于玩家视线附近，远处也可识别。
- [ ] 在圆形边界外可额外生成一圈更暗的荒漠地面占位，作为“不可进入远景”，但不参与移动区域。
- [ ] 保持地形仍为平面，不加入高低起伏。
- [ ] 验证玩家从中心向任意方向移动，都能提前看见边界标志。

### 3.4 枯树道具脚本

- [ ] 新建 `scripts/level/props/dead_tree_prop.gd`，`class_name DeadTreeProp extends Node3D`。
- [ ] 导出 `trunk_height: float`、`trunk_width: float`、`branch_count: int`。
- [ ] 在 `_ready()` 中调用 `_build_model()`，自动生成占位模型。
- [ ] `_build_model()` 创建棕色树干 CSGBox3D。
- [ ] `_build_model()` 创建若干深棕色枝干 CSGBox3D。
- [ ] 枝干使用随机或固定角度倾斜，让不同枯树轮廓不完全一样。
- [ ] 添加 `StaticBody3D` 或直接让 CSGBox3D 使用碰撞，确保枯树能挡住玩家和射线。
- [ ] 所有碰撞用简单盒子即可，不追求精确树形碰撞。
- [ ] 枯树根节点加入 `cover_prop` group。
- [ ] 枯树几何加入 `level_geometry` group，方便碰撞启用规则识别。

### 3.5 枯树场景资源

- [ ] 新建 `scenes/props/dead_tree_prop.tscn`。
- [ ] 根节点命名为 `DeadTreeProp`，挂 `dead_tree_prop.gd`。
- [ ] 打开场景确认运行后能自动生成树干和枝干。
- [ ] 确认材质颜色为棕色系，与荒漠地面明显区分。
- [ ] 确认碰撞体高度和树干模型大致一致。
- [ ] 确认作为 PackedScene 实例化时不依赖主场景节点。

### 3.6 枯树随机生成

- [ ] 在 `DesertArena` 中预加载 `res://scenes/props/dead_tree_prop.tscn`。
- [ ] 实现 `_spawn_dead_trees()`。
- [ ] 生成前调用 `clear_randomized_content()` 或确保只清理荒漠道具，不清理地面和边界。
- [ ] 每棵枯树通过 `get_random_prop_position(dead_tree_min_distance, dead_tree_safe_radius)` 获取位置。
- [ ] 如果随机失败，跳过该棵树并打印调试信息。
- [ ] 枯树实例挂到 `_props_root`。
- [ ] 枯树 `rotation_degrees.y` 随机，避免朝向完全相同。
- [ ] 枯树缩放可在 `0.8` 到 `1.3` 之间随机，让掩体大小略有变化。
- [ ] 生成后调用 `register_occupied_point()`，后续枯树避开它。
- [ ] 保证枯树不会生成到 `arena_radius - 2.0` 以外，避免贴边卡住玩家。

### 3.7 枯树掩体行为验证

- [ ] 玩家走向枯树时会被阻挡。
- [ ] 子弹射线命中枯树时不会穿透打到后方敌人。
- [ ] 敌人追击玩家时会被枯树阻挡或绕不过时短暂卡住；高级避障后续再处理。
- [ ] 枯树之间留有足够通道，不形成完全封闭围栏。
- [ ] 玩家出生点周围至少有一个安全开阔区域。
- [ ] 重进荒漠关卡后枯树位置变化。
- [ ] 使用固定 `random_seed` 时，枯树位置可复现。

### 3.8 荒漠关卡验收

- [ ] 从选关界面选择荒漠后能正常进入关卡。
- [ ] 荒漠地面、暖色灯光、边界标志能形成明确主题。
- [ ] 玩家出生在圆形区域中心附近。
- [ ] 边界限制和“已到达边界”提示正常。
- [ ] 枯树每次开局随机生成。
- [ ] 枯树能作为掩体阻挡移动和射线。
- [ ] 返回选关再进入荒漠，不会叠加上一局的枯树。
- [ ] 荒漠关卡不依赖熔岩或岩柱相关脚本。

## Phase 4：第二关熔岩地狱竞技场

### 4.1 LavaArena 脚本

- [ ] 新建 `scripts/level/lava_arena.gd`，`class_name LavaArena extends ArenaLevel`。
- [ ] 导出 `lava_river_count: int = 2`。
- [ ] 导出 `rock_column_count: int = 18`。
- [ ] 导出 `rock_column_min_distance: float = 5.0`。
- [ ] 导出 `center_safe_radius: float = 10.0`，保证出生区域不被熔岩和岩柱堵住。
- [ ] 导出 `lava_min_distance_from_spawn: float = 8.0`。
- [ ] 导出暗红/黑色地面材质颜色。
- [ ] 导出亮橙/红色边界材质颜色。
- [ ] 覆写地面和边界材质方法，让熔岩关卡主题与荒漠区分明显。
- [ ] 在生成钩子中依次调用 `_spawn_lava_rivers()` 和 `_spawn_rock_columns()`。

### 4.2 熔岩场景搭建

- [ ] 新建或更新 `scenes/levels/lava_arena.tscn`。
- [ ] 根节点命名为 `LavaArena`，类型为 `Node3D`。
- [ ] 根节点挂载 `scripts/level/lava_arena.gd`。
- [ ] 设置 `arena_radius = 45.0`。
- [ ] 设置 `spawn_outer_radius = 56.0`。
- [ ] 设置 `boundary_marker_count = 72`。
- [ ] 添加 `PlayerStart`，放在圆心附近。
- [ ] 添加红橙色 `DirectionalLight3D`。
- [ ] 添加低强度补光，避免黑色地面吞掉视觉信息。
- [ ] 确认 `LevelRegistry.LAVA` 指向该场景。

### 4.3 熔岩河流脚本

- [ ] 新建 `scripts/level/hazards/lava_river.gd`，`class_name LavaRiver extends Node3D`。
- [ ] 导出 `river_length: float = 28.0`。
- [ ] 导出 `river_width: float = 4.0`。
- [ ] 导出 `damage_per_second: float = 18.0`。
- [ ] 导出 `tick_interval: float = 0.25`。
- [ ] 导出 `visual_height: float = 0.04`，让熔岩略高于地面避免闪烁。
- [ ] `_ready()` 中调用 `_build_visual()` 和 `_build_damage_area()`。
- [ ] `_build_visual()` 创建红橙色扁平 CSGBox3D 或 MeshInstance3D。
- [ ] 视觉材质开启 emission，强化熔岩危险感。
- [ ] `_build_damage_area()` 创建 `Area3D` 和 `CollisionShape3D`，尺寸覆盖河流矩形。
- [ ] `Area3D` 只负责检测玩家，不阻挡玩家移动。
- [ ] 根节点加入 `hazard` group。

### 4.4 熔岩持续伤害

- [ ] `LavaRiver` 维护 `_bodies_in_lava: Array[Node]` 或 Dictionary。
- [ ] 连接 `body_entered`，玩家进入时加入列表。
- [ ] 连接 `body_exited`，玩家离开时移出列表。
- [ ] 使用 `_process(delta)` 累计 tick 时间。
- [ ] 每个 tick 对列表中的玩家查找 `Damageable`。
- [ ] 伤害数值为 `damage_per_second * tick_interval`。
- [ ] 调用 `Damageable.take_damage()`，伤害类型可临时使用 `WeaponData.DamageType.EXPLOSION` 或后续新增 `HAZARD`。
- [ ] 玩家离开熔岩后不再继续扣血。
- [ ] 玩家死亡后不再重复造成伤害或刷屏报错。
- [ ] 熔岩伤害应触发玩家受伤闪红。

### 4.5 熔岩河流随机生成

- [ ] 新建 `scenes/hazards/lava_river.tscn`，根节点挂 `lava_river.gd`。
- [ ] 在 `LavaArena` 中预加载熔岩河流场景。
- [ ] 实现 `_spawn_lava_rivers()`。
- [ ] 每条熔岩河流随机选取中心点、长度和旋转角度。
- [ ] 河流中心点必须在竞技场内部。
- [ ] 河流矩形的主要部分应留在 `arena_radius - 3.0` 内。
- [ ] 河流不能覆盖玩家出生安全半径。
- [ ] 多条河流之间保持最小距离，避免一开局就把地图切成死路。
- [ ] 河流生成后，把中心点和近似占用半径注册到随机占位列表。
- [ ] 如果找不到合法位置，减少该局河流数量而不是强行生成。

### 4.6 柱状岩石脚本

- [ ] 新建 `scripts/level/props/rock_column_prop.gd`，`class_name RockColumnProp extends Node3D`。
- [ ] 导出 `column_height: float`、`column_width: float`、`segment_count: int`。
- [ ] `_ready()` 中调用 `_build_model()`。
- [ ] 用深灰/黑色 CSGBox3D 堆叠成柱状岩石。
- [ ] 每段方块可轻微旋转或缩放，形成粗糙柱体轮廓。
- [ ] 添加碰撞，能阻挡玩家、敌人、射线和投射物。
- [ ] 岩柱根节点加入 `cover_prop` group。
- [ ] 岩柱几何加入 `level_geometry` group。

### 4.7 柱状岩石场景和随机生成

- [ ] 新建 `scenes/props/rock_column_prop.tscn`。
- [ ] 根节点命名为 `RockColumnProp`，挂 `rock_column_prop.gd`。
- [ ] 在 `LavaArena` 中预加载岩柱场景。
- [ ] 实现 `_spawn_rock_columns()`。
- [ ] 岩柱通过 `get_random_prop_position(rock_column_min_distance, center_safe_radius)` 获取位置。
- [ ] 岩柱不得生成在熔岩河流的近似占用范围内。
- [ ] 岩柱不得过于贴近边界，避免玩家沿边界移动时被卡住。
- [ ] 岩柱高度和缩放可随机，形成掩体层次。
- [ ] 生成后注册占用点。

### 4.8 熔岩关卡综合验证

- [ ] 玩家出生点附近没有熔岩河流。
- [ ] 熔岩河流和岩柱每次开局位置不同。
- [ ] 熔岩河流不阻挡玩家移动，但会持续造成伤害。
- [ ] 岩柱阻挡玩家移动和射线。
- [ ] 岩柱不会生成在熔岩上。
- [ ] 熔岩和岩柱不会完全封死从中心到边界的大部分路线。
- [ ] 边界标志在红橙环境中仍清晰可见。
- [ ] 返回选关再进入熔岩关卡，不会叠加上一局河流和岩柱。

### 4.9 熔岩关卡验收

- [ ] 从选关界面选择熔岩地狱后能正常进入关卡。
- [ ] 熔岩地面、红橙灯光、发光边界形成明确主题。
- [ ] 玩家站在熔岩中会持续掉血，离开后停止。
- [ ] 熔岩伤害触发玩家受伤 UI。
- [ ] 柱状岩石能作为掩体。
- [ ] 随机生成不会破坏出生安全区。
- [ ] 熔岩关卡不依赖荒漠枯树脚本。

## Phase 5：敌人数据模型与通用 AI

### 5.1 EnemyData 字段扩展

- [x] 更新 `scripts/enemy/enemy_data.gd`。
- [x] 添加基础分类字段：`enemy_id: String`、`enemy_role: String`。
- [x] 添加 `score_value: int = 10`。
- [x] 添加 `spawn_cost: int = 1`。
- [x] 添加 `weight: float = 1.0`。
- [x] 添加 `max_stun: float = 100.0`。
- [x] 添加 `stun_recovery_rate: float = 12.0`。
- [x] 添加 `stun_resistance: float = 0.0`，范围建议 `0.0` 到 `0.9`。
- [x] 添加 `knockback_resistance: float = 0.0`，范围建议 `0.0` 到 `0.9`。
- [x] 添加 `preferred_range: float = 2.0`，近战等于攻击距离附近，远程用于保持距离。
- [x] 添加 `min_range: float = 0.0`，远程敌人太近时后退。
- [x] 添加 `attack_windup: float = 0.2`。
- [x] 添加 `attack_duration: float = 0.1`。
- [x] 添加 `attack_recovery: float = 0.3`。
- [x] 添加 `is_flying: bool = false`。
- [x] 添加 `hover_height: float = 3.0`。
- [x] 添加 `vertical_move_speed: float = 4.0`。
- [x] 添加 `model_color: Color`，用于 Phase 6 立方体占位模型。
- [x] 确认已有 `imp.tres` 和 `demon_soldier.tres` 在新增字段后仍能加载。

### 5.2 伤害与眩晕接口

- [x] 在 `Enemy` 基类中新增 `_stun: float = 0.0`。
- [x] 新增 `_is_stun_full: bool = false`。
- [x] 新增信号 `stun_changed(current: float, max_value: float)`。
- [x] 新增信号 `stun_filled(enemy: Enemy)`。
- [x] 新增方法 `apply_stun(amount: float) -> void`。
- [x] `apply_stun()` 根据 `enemy_data.stun_resistance` 减免眩晕值。
- [x] 眩晕值限制在 `0` 到 `enemy_data.max_stun`。
- [x] 眩晕首次满时发出 `stun_filled`。
- [x] 新增方法 `is_stunned_or_grabbable() -> bool`。
- [x] 暂时不要求现有枪械都调用 `apply_stun`，Phase 8 接入武器眩晕值。

### 5.3 Enemy 状态机扩展

- [x] 扩展 `EnemyState`：`SPAWNING`、`STUNNED`、`GRABBED`、`EXECUTED`。
- [x] 新增 `_previous_state`，用于眩晕结束后返回追击或攻击。
- [x] 新增 `_state_entered(state)` 钩子，集中处理进入状态时的初始化。
- [x] 新增 `_state_exit(state)` 钩子，集中处理离开状态时的清理。
- [x] `_transition_to()` 调用 exit/enter 钩子。
- [x] `DEATH`、`GRABBED`、`EXECUTED` 状态下不再执行普通 AI。
- [x] `STUNNED` 状态下不移动、不攻击，但仍可被伤害。
- [x] 死亡后清理抓取、眩晕和延迟攻击 timer。
- [x] 保证旧的 `IDLE`、`CHASE`、`ATTACK`、`PAIN`、`DEATH` 流程仍能运行。

### 5.4 眩晕恢复和可抓取窗口

- [x] 新增导出或数据字段 `stun_full_duration: float = 2.0`，可直接放 EnemyData 或 Enemy 基类。
- [x] 眩晕未满时，敌人每帧按 `stun_recovery_rate * delta` 恢复。
- [x] 眩晕满后进入 `STUNNED` 或设置可抓取窗口计时。
- [x] 可抓取窗口期间不自动降低眩晕值。
- [x] 可抓取窗口结束后，如果未被抓取，眩晕值逐步回落。
- [x] 再次受到眩晕伤害时刷新可抓取窗口。
- [x] 添加调试打印或临时头顶 Label，显示眩晕百分比。

### 5.5 击退接口

- [x] 在 `Enemy` 基类新增 `_knockback_velocity: Vector3`。
- [x] 新增方法 `apply_knockback(direction: Vector3, force: float) -> void`。
- [x] 击退力度根据 `enemy_data.weight` 和 `enemy_data.knockback_resistance` 减免。
- [x] `_physics_process()` 中将击退速度叠加到移动速度。
- [x] 击退速度随时间衰减。
- [x] 死亡、抓取、处决状态下忽略普通击退。
- [x] 验证手动调用 `apply_knockback()` 能把敌人短暂推开。

### 5.6 抓取和处决占位接口

- [x] 在 `Enemy` 基类新增 `_grab_owner: Node3D = null`。
- [x] 新增方法 `can_be_grabbed() -> bool`，眩晕满且未死亡时返回 true。
- [x] 新增方法 `start_grab(owner: Node3D) -> bool`。
- [x] `start_grab()` 成功后切换到 `GRABBED`。
- [x] 新增方法 `update_grabbed_position(target_transform: Transform3D, delta: float)`。
- [x] `GRABBED` 状态下关闭导航/主动移动/攻击。
- [x] 新增方法 `release_grab()`，释放后回到 `STUNNED` 或 `CHASE`。
- [x] 新增方法 `execute()`，切换到 `EXECUTED` 并造成死亡或大量伤害。
- [x] Phase 8 铁鞭只调用这些接口，不直接改 Enemy 内部状态。

### 5.7 通用移动基础

- [x] 新增 `_get_player_flat_direction() -> Vector3`。
- [x] 新增 `_get_player_distance_xz() -> float`。
- [x] 新增 `_move_towards_player(delta, speed)`。
- [x] 新增 `_move_away_from_player(delta, speed)`。
- [x] 新增 `_strafe_around_player(delta, speed)`，供远程敌人横向移动。
- [x] 新增 `_face_player_flat()`，只绕 Y 轴看向玩家。
- [x] 地面敌人使用 `move_and_slide()`。
- [x] 飞行敌人使用高度修正后再移动，仍可用 CharacterBody3D。

### 5.8 近战 AI 模板

- [x] 在 `Enemy` 基类或新建 `scripts/enemy/melee_enemy_base.gd` 中实现近战模板。
- [x] 敌人距离玩家大于 `attack_range` 时追击。
- [x] 进入攻击范围后切换 `ATTACK`。
- [x] `ATTACK` 分为 windup、damage、recovery 三段计时。
- [x] windup 阶段面向玩家但不造成伤害。
- [x] damage 阶段检查距离和角度，命中则伤害玩家 Damageable。
- [x] recovery 阶段不能再次攻击。
- [x] 攻击结束后根据距离回到 `CHASE` 或继续 `ATTACK`。
- [x] 使用 `enemy_data.attack_damage` 和 `enemy_data.attack_cooldown`。

### 5.9 远程 AI 模板

- [x] 在 `Enemy` 基类或新建 `scripts/enemy/ranged_enemy_base.gd` 中实现远程模板。
- [x] 距离大于 `preferred_range` 时靠近玩家。
- [x] 距离小于 `min_range` 时后退。
- [x] 位于合适距离时可横向移动或停下射击。
- [x] 攻击前检查视线，避免隔着掩体直接命中。
- [x] 远程攻击先复用现有 `Projectile` 或 hitscan 方法。
- [x] 投射物颜色根据敌人类型后续设置。
- [x] 攻击同样使用 windup、damage/fire、recovery 三段。
- [x] 玩家离开射程后回到 `CHASE`。

### 5.10 空中 AI 模板

- [x] 在 `Enemy` 基类中支持 `enemy_data.is_flying`。
- [x] 飞行敌人目标高度为玩家高度加 `hover_height`。
- [x] 每帧按 `vertical_move_speed` 调整 Y 轴高度。
- [x] 飞行敌人仍遵守圆形边界，不飞到过远区域。
- [x] 空中近战敌人可使用近战模板，但允许从空中贴近。
- [x] 空中远程敌人可使用远程模板，并保持悬浮高度。
- [x] 飞行敌人被击退时允许 XZ 击退，Y 轴击退可减弱。
- [x] 飞行敌人被抓取时下降或直接移动到玩家身前，避免卡在空中。

### 5.11 敌人死亡、计分和注册

- [x] `Enemy` 死亡时继续发出 `enemy_died(enemy)`。
- [x] `EnemyManager` 从 `enemy.enemy_data.score_value` 读取分数。
- [x] `EnemyManager.enemy_killed` 信号扩展为携带 `enemy_name` 和 `score_value`，或新增 `enemy_scored(score_value)`。
- [x] `RunStats.add_kill(score_value)` 接入 EnemyManager。
- [x] HUD 击杀数和分数同时更新。
- [x] 敌人被熔岩、枪械、铁鞭、处决杀死时都只计一次分。
- [x] 死亡后敌人从 `active_enemies` 移除。

### 5.12 敌人调试可视化

- [x] 给 Enemy 临时添加头顶眩晕条，使用 `Label3D`、`ProgressBar` 方案或简单 CSG 条。
- [x] 眩晕条默认显示当前眩晕比例。
- [x] 血量低于满值时可临时显示血条，方便验证伤害。
- [x] 状态变化时可在调试模式下打印状态名。
- [x] 给敌人模型颜色读取 `enemy_data.model_color`。
- [x] 所有调试显示后续可通过导出开关关闭。

### 5.13 Phase 5 验收

- [x] 旧 Imp 和 DemonSoldier 在新增字段后仍能运行。
- [x] 敌人能被普通伤害杀死并正确计分。
- [x] 手动调用 `apply_stun()` 可以让敌人进入眩晕满状态。
- [x] 眩晕值会随时间恢复。
- [x] 手动调用 `apply_knockback()` 可以击退敌人。
- [x] 手动调用 `start_grab()` 后敌人停止攻击和移动。
- [x] 手动调用 `release_grab()` 后敌人能恢复行为。
- [x] 近战模板能靠近玩家并造成伤害。
- [x] 远程模板能保持距离并发射攻击。
- [x] 空中模板能保持悬浮高度。
- [x] EnemyManager、RunStats、HUD 的击杀和分数链路正常。

## Phase 6：八类敌人实现

> 所有敌人先用不同颜色立方体模型。优先共用 Enemy 基类和少量行为脚本，通过 EnemyData 拉开差异。

### 6.1 敌人变体实现策略

- [ ] 先保留 `Enemy` 基类作为统一生命、眩晕、击退、抓取、计分入口。
- [ ] 为近战、远程、空中行为建立最少数量的行为脚本，避免八类敌人复制大量代码。
- [ ] 优先通过 `EnemyData` 区分血量、速度、重量、分数、眩晕抗性、攻击方式。
- [ ] 每类敌人都提供一个 `.tres` 数据资源。
- [ ] 每类敌人都提供一个 `.tscn` 场景资源，方便 SpawnManager 直接实例化。
- [ ] 每类敌人模型先用不同颜色的立方体，不制作正式模型。
- [ ] 每类敌人都必须能被现有武器击杀、计分、进入眩晕流程。

### 6.2 通用占位模型生成

- [ ] 在 `Enemy` 基类中新增或整理 `_setup_placeholder_model()`。
- [ ] 根据 `enemy_data.model_color` 设置身体颜色。
- [ ] 根据敌人类型调整立方体尺寸：普通小、高级中、精英大、空中稍小。
- [ ] 地面敌人使用一个主体立方体加一个顶部小方块区分朝向。
- [ ] 远程敌人增加一个前方小枪管方块。
- [ ] 空中敌人增加左右小翼方块或上方标记方块。
- [ ] 所有视觉 CSG 默认 `use_collision = false`。
- [ ] 每个敌人只使用一个 Capsule 或 Box CollisionShape 作为物理碰撞。
- [ ] 头顶眩晕条位置根据模型高度自动调整。

### 6.3 EnemyData 资源创建

- [ ] 新建 `assets/enemies/ground_enemy.tres`。
- [ ] 新建 `assets/enemies/advanced_ground_enemy.tres`。
- [ ] 新建 `assets/enemies/elite_ground_enemy.tres`。
- [ ] 新建 `assets/enemies/ranged_enemy.tres`。
- [ ] 新建 `assets/enemies/advanced_ranged_enemy.tres`。
- [ ] 新建 `assets/enemies/flying_enemy.tres`。
- [ ] 新建 `assets/enemies/advanced_flying_enemy.tres`。
- [ ] 新建 `assets/enemies/flying_ranged_enemy.tres`。
- [ ] 每个资源填写 `enemy_id`，必须和 SpawnManager 使用的 id 一致。
- [ ] 每个资源填写 `enemy_name`，用于 HUD 和调试。
- [ ] 每个资源填写 `score_value` 和 `spawn_cost`。
- [ ] 每个资源填写 `weight`，供铁鞭抓取阶段使用。
- [ ] 每个资源填写 `model_color`，用于占位模型。

### 6.4 地面近战敌人

- [ ] 新建 `scripts/enemy/ground_enemy.gd`，继承 `Enemy` 或近战模板脚本。
- [ ] `GroundEnemy` 使用普通追击 + 近战攻击。
- [ ] `GroundEnemy` 配置为低血量、低重量、低分数、低眩晕抗性。
- [ ] 新建 `scripts/enemy/advanced_ground_enemy.gd`。
- [ ] `AdvancedGroundEnemy` 使用同样近战模板，但速度更快、血量更高。
- [ ] `AdvancedGroundEnemy` 可增加轻微左右移动，避免完全直线靠近。
- [ ] 新建 `scripts/enemy/elite_ground_enemy.gd`。
- [ ] `EliteGroundEnemy` 使用大型模型、高血量、高重量、高分数。
- [ ] `EliteGroundEnemy` 攻击前摇更明显，但伤害更高。
- [ ] 三类地面敌人都从边界外刷新后能向玩家推进。

### 6.5 地面远程敌人

- [ ] 新建 `scripts/enemy/ranged_enemy.gd`，继承 `Enemy` 或远程模板脚本。
- [ ] `RangedEnemy` 到达 `preferred_range` 后停止推进。
- [ ] `RangedEnemy` 使用慢速投射物攻击。
- [ ] 投射物颜色使用蓝色或浅蓝色。
- [ ] `RangedEnemy` 玩家太近时可以缓慢后退。
- [ ] 新建 `scripts/enemy/advanced_ranged_enemy.gd`。
- [ ] `AdvancedRangedEnemy` 使用更快投射物或更短攻击冷却。
- [ ] `AdvancedRangedEnemy` 横向移动概率更高。
- [ ] 两类远程敌人攻击前都检查玩家视线。
- [ ] 远程敌人被枯树/岩柱遮挡时，应尝试换位或继续靠近。

### 6.6 空中敌人

- [ ] 新建 `scripts/enemy/flying_enemy.gd`。
- [ ] `FlyingEnemy` 使用空中近战模板，保持悬浮高度后靠近玩家。
- [ ] `FlyingEnemy` 血量较低、速度较快、分数中等。
- [ ] 新建 `scripts/enemy/advanced_flying_enemy.gd`。
- [ ] `AdvancedFlyingEnemy` 速度更快、重量更高、眩晕抗性更高。
- [ ] `AdvancedFlyingEnemy` 可在攻击前短暂停顿，给玩家反应时间。
- [ ] 新建 `scripts/enemy/flying_ranged_enemy.gd`。
- [ ] `FlyingRangedEnemy` 保持空中距离并发射投射物。
- [ ] `FlyingRangedEnemy` 优先保持高度，避免贴地移动。
- [ ] 空中敌人死亡后下落、缩小或直接变灰消失，先用简单效果。

### 6.7 敌人场景资源

- [ ] 新建 `scenes/enemies/ground_enemy.tscn`。
- [ ] 新建 `scenes/enemies/advanced_ground_enemy.tscn`。
- [ ] 新建 `scenes/enemies/elite_ground_enemy.tscn`。
- [ ] 新建 `scenes/enemies/ranged_enemy.tscn`。
- [ ] 新建 `scenes/enemies/advanced_ranged_enemy.tscn`。
- [ ] 新建 `scenes/enemies/flying_enemy.tscn`。
- [ ] 新建 `scenes/enemies/advanced_flying_enemy.tscn`。
- [ ] 新建 `scenes/enemies/flying_ranged_enemy.tscn`。
- [ ] 每个场景根节点为 `CharacterBody3D`。
- [ ] 每个场景挂对应脚本。
- [ ] 每个场景挂对应 `EnemyData` 资源。
- [ ] 每个场景包含基础碰撞体。
- [ ] 打开每个场景单独运行或实例化测试，确认 `_ready()` 不报错。

### 6.8 敌人单体测试

- [ ] 在临时测试关卡中放置 `GroundEnemy`，确认能追击和近战攻击。
- [ ] 放置 `AdvancedGroundEnemy`，确认速度和血量区别明显。
- [ ] 放置 `EliteGroundEnemy`，确认更难击退和眩晕。
- [ ] 放置 `RangedEnemy`，确认能保持距离并发射投射物。
- [ ] 放置 `AdvancedRangedEnemy`，确认射速或弹速更高。
- [ ] 放置 `FlyingEnemy`，确认能悬浮并靠近玩家。
- [ ] 放置 `AdvancedFlyingEnemy`，确认速度和抗性区别明显。
- [ ] 放置 `FlyingRangedEnemy`，确认能在空中远程攻击。
- [ ] 所有敌人死亡后都能加分且只加一次。

### 6.9 Phase 6 验收

- [ ] 八类敌人均有脚本、场景和数据资源。
- [ ] 八类敌人颜色区分明显。
- [ ] 八类敌人都能被 SpawnManager 或 EnemyManager 注册。
- [ ] 八类敌人都能被击杀并计分。
- [ ] 地面、远程、空中三种行为差异能在游戏内感受到。
- [ ] 所有敌人都支持眩晕、击退、抓取占位接口。

## Phase 7：刷怪与难度曲线

### 7.1 SpawnManager 基础

- [ ] 新建 `scripts/enemy/spawn_manager.gd`，`class_name SpawnManager extends Node`。
- [ ] 添加 `arena: ArenaLevel` 引用。
- [ ] 添加 `enemy_manager: EnemyManager` 引用。
- [ ] 添加 `run_stats: RunStats` 引用。
- [ ] 添加 `is_active: bool`。
- [ ] 添加 `active_enemy_limit: int = 60`。
- [ ] 添加 `spawn_timer: float`。
- [ ] 添加 `current_intensity: int = 1`。
- [ ] 添加 `setup(arena, enemy_manager, run_stats)`。
- [ ] 添加 `start()`、`stop()`、`reset()`。
- [ ] 关卡开始时由 `Main` 创建或启用 SpawnManager。
- [ ] 关卡结束、玩家死亡、返回菜单时停止 SpawnManager。

### 7.2 敌人池和条目配置

- [ ] 新建 `scripts/enemy/spawn_entry.gd` 或在 SpawnManager 内使用 Dictionary 定义条目。
- [ ] 每个条目包含 `enemy_id`、`scene_path`、`enemy_data_path`、`min_intensity`、`weight`。
- [ ] 注册八类敌人的场景路径。
- [ ] 普通地面敌人 `min_intensity = 1`。
- [ ] 普通远程敌人 `min_intensity = 2`。
- [ ] 普通空中敌人 `min_intensity = 3`。
- [ ] 高级地面和高级远程 `min_intensity = 4`。
- [ ] 高级空中和空中远程 `min_intensity = 5`。
- [ ] 精英地面敌人 `min_intensity = 6`。
- [ ] 条目权重用于同强度下随机选择。

### 7.3 时间强度曲线

- [ ] 根据 `run_stats.survival_time` 计算当前强度。
- [ ] 0 到 30 秒为强度 1。
- [ ] 30 到 75 秒为强度 2。
- [ ] 75 到 130 秒为强度 3。
- [ ] 130 到 210 秒为强度 4。
- [ ] 210 到 320 秒为强度 5。
- [ ] 320 秒后进入强度 6，并继续缓慢提升预算。
- [ ] 强度变化时发出 `intensity_changed(new_intensity)` 信号。
- [ ] HUD 当前强度显示接入该信号。
- [ ] 强度曲线先写死，后续可改成 Resource。

### 7.4 刷新间隔和波次预算

- [ ] 添加 `get_spawn_interval() -> float`。
- [ ] 初期刷新间隔较长，例如 4.0 秒。
- [ ] 随强度提高逐步缩短到 1.2 到 1.5 秒。
- [ ] 添加 `get_wave_budget() -> int`。
- [ ] 初期每波预算 1 到 2。
- [ ] 中期每波预算 3 到 5。
- [ ] 后期每波预算 6 以上，但受存活上限限制。
- [ ] 每个敌人的 `spawn_cost` 从 EnemyData 或 spawn entry 读取。
- [ ] 每波按预算挑选敌人，直到预算不足或达到本波上限。
- [ ] 如果当前存活敌人超过 `active_enemy_limit`，暂停刷新。

### 7.5 边界外刷新点

- [ ] SpawnManager 调用 `arena.get_random_point_outside_boundary()` 或 ArenaRandomizer。
- [ ] 刷新点必须在 `arena_radius` 外、`spawn_outer_radius` 内。
- [ ] 刷新点与玩家保持最小距离，避免贴脸突然出现。
- [ ] 刷新点与其他刚生成敌人保持最小距离。
- [ ] 刷新点朝向玩家或竞技场中心。
- [ ] 如果找不到合法点，延迟到下一次刷新。
- [ ] 飞行敌人刷新时额外设置 Y 轴高度。

### 7.6 刷新预警

- [ ] 新建简单预警节点，可用半透明红色 CSGBox3D 或发光小柱。
- [ ] SpawnManager 先创建预警节点，等待 `spawn_warning_time`。
- [ ] 预警结束后再实例化敌人。
- [ ] 玩家能看见边界外即将出现敌人的位置。
- [ ] 预警节点在敌人生成后自动销毁。
- [ ] 关卡结束时清理所有预警节点。

### 7.7 关卡差异化刷怪

- [ ] 荒漠关卡刷怪偏向地面敌人和普通远程敌人。
- [ ] 熔岩关卡更早加入空中敌人和远程敌人。
- [ ] 在 ArenaLevel 或 LevelRegistry 中提供 `spawn_profile`。
- [ ] SpawnManager 根据当前关卡 profile 调整敌人权重。
- [ ] 没有 profile 时使用默认权重。

### 7.8 击杀计分链路

- [ ] EnemyManager 死亡信号传递 `score_value`。
- [ ] RunStats 接收击杀并增加分数。
- [ ] HUD 实时刷新分数和击杀数。
- [ ] 处决额外分数接口先预留，Phase 8 再接入。
- [ ] 被熔岩或环境伤害击杀的敌人是否给分先统一为给分，后续可调。
- [ ] 同一个敌人死亡只结算一次。

### 7.9 SpawnManager 验收

- [ ] 进入关卡后，敌人从圆形边界外刷新。
- [ ] 刷新前有短暂预警。
- [ ] 随时间推进，敌人数量和强度逐渐增加。
- [ ] 不同强度阶段出现不同敌人类型。
- [ ] 敌人数量达到上限后暂停刷新。
- [ ] 玩家死亡或返回菜单后不再刷新。
- [ ] 荒漠和熔岩刷怪权重有明显差异。

## Phase 8：铁鞭、眩晕、抓取与处决

### 8.1 输入和节点结构

- [ ] 在 `project.godot` 中新增输入动作 `secondary_fire`，绑定鼠标右键。
- [ ] 在 Player 场景的 Camera3D 下新增 `LeftHandHolder` 或在脚本中动态创建。
- [ ] 新建 `scripts/weapon/iron_whip.gd`，`class_name IronWhip extends Node3D`。
- [ ] IronWhip 挂在左手节点下。
- [ ] IronWhip 只处理鼠标右键，不影响现有左键枪械。
- [ ] 抓取状态下 `reload` 输入交给处决逻辑，非抓取状态仍交给武器换弹。
- [ ] 确认菜单状态下鼠标右键不会触发铁鞭。

### 8.2 铁鞭数据参数

- [ ] 新建 `assets/weapons/iron_whip.tres` 或专用 `WhipData` 资源。
- [ ] 参数包含 `damage: float`。
- [ ] 参数包含 `stun_damage: float`。
- [ ] 参数包含 `knockback_force: float`。
- [ ] 参数包含 `range: float`。
- [ ] 参数包含 `cooldown: float`。
- [ ] 参数包含 `pull_speed: float`。
- [ ] 参数包含 `grab_distance: float`。
- [ ] 参数包含 `execution_damage: float`。
- [ ] 手枪和霰弹枪的 WeaponData 也增加 `stun_damage`。
- [ ] 调整手枪、霰弹枪、铁鞭眩晕值，铁鞭应明显更偏控制。

### 8.3 铁鞭视觉占位

- [ ] 铁鞭未攻击时显示左手小型深灰色立方体。
- [ ] 攻击瞬间生成一条细长 CSGBox3D 或 ImmediateMesh 作为鞭影。
- [ ] 鞭影从玩家左手方向延伸到命中点或最大距离。
- [ ] 鞭影持续很短时间后自动隐藏。
- [ ] 命中敌人时让敌人短暂闪色或眩晕条增长。
- [ ] 未命中时也播放短暂挥鞭视觉，保证输入有反馈。

### 8.4 铁鞭命中判定

- [ ] 第一版使用摄像机中心射线判定，范围使用 `range`。
- [ ] 射线优先命中敌人，也能被掩体阻挡。
- [ ] 后续可替换为扇形 Area3D，但第一版先保证稳定。
- [ ] 命中敌人后调用 `take_damage(damage)`。
- [ ] 命中敌人后调用 `apply_stun(stun_damage)`。
- [ ] 命中敌人后调用 `apply_knockback(direction, knockback_force)`。
- [ ] 命中眩晕满敌人时，不做普通击退，改为进入拉取流程。
- [ ] 铁鞭冷却期间再次按右键无效。

### 8.5 拉取流程

- [ ] IronWhip 维护 `_pulled_enemy: Enemy`。
- [ ] 命中 `enemy.can_be_grabbed()` 为 true 的敌人时，设置为拉取目标。
- [ ] 拉取期间敌人停止普通 AI。
- [ ] 每帧把敌人向玩家身前目标点移动。
- [ ] 如果敌人与玩家距离小于 `grab_distance`，调用 `enemy.start_grab(player)`。
- [ ] 拉取过程中如果敌人死亡，清空拉取目标。
- [ ] 拉取过程中如果玩家死亡或切回菜单，释放目标。
- [ ] 拉取过程中如果距离过远或被遮挡时间过长，可取消拉取。

### 8.6 抓取状态和移动惩罚

- [ ] 玩家或 IronWhip 维护 `_grabbed_enemy: Enemy`。
- [ ] 抓取成功后敌人固定在玩家前方偏左或正前方。
- [ ] 每帧调用 `enemy.update_grabbed_position()`。
- [ ] 在 PlayerController 中新增移动速度倍率接口，例如 `set_external_speed_multiplier(multiplier)`。
- [ ] 抓取敌人后根据 `enemy_data.weight` 降低玩家移动速度。
- [ ] 轻敌人移动惩罚小，精英重敌人移动惩罚大。
- [ ] 释放或处决敌人后恢复玩家移动速度。
- [ ] 玩家同一时间只能抓取一个敌人。

### 8.7 盾牌抵挡

- [ ] 新建 `scripts/combat/shield_blocker.gd` 或在 IronWhip 中实现盾牌判定。
- [ ] 敌人攻击玩家前，先查询玩家是否有抓取盾牌。
- [ ] 对 hitscan 攻击，判断攻击来源是否在玩家前方角度范围内。
- [ ] 对投射物攻击，投射物碰到被抓取敌人时优先伤害该敌人。
- [ ] 盾牌抵挡成功时，被抓取敌人承受伤害。
- [ ] 盾牌抵挡成功时，玩家不受伤或受到降低后的伤害。
- [ ] 被抓取敌人死亡后自动解除抓取。
- [ ] HUD 可临时显示“盾牌抵挡”调试文本。

### 8.8 处决

- [ ] 抓取状态下按 `R` 调用 `_execute_grabbed_enemy()`。
- [ ] 未抓取状态下按 `R` 仍执行当前武器换弹。
- [ ] 处决时锁定短暂时间，避免重复触发。
- [ ] 处决对被抓取敌人造成 `execution_damage` 或直接调用 `execute()`。
- [ ] 处决播放简单动画：敌人变白、缩小、下沉或爆开成方块占位。
- [ ] 处决成功后给额外分数。
- [ ] 处决成功后恢复玩家移动速度。
- [ ] 处决成功后清空 `_grabbed_enemy`。

### 8.9 与武器系统整合

- [ ] `WeaponData` 新增 `stun_damage` 后，枪械命中敌人时调用 `apply_stun()`。
- [ ] 手枪眩晕值较低。
- [ ] 霰弹枪每颗弹丸眩晕值较低，但近距离全中总眩晕更高。
- [ ] 铁鞭眩晕值最高，但攻击频率低。
- [ ] HUD 或敌人头顶条能看到不同武器造成的眩晕差异。
- [ ] 隐藏武器不应触发眩晕，沿用 Phase 0 的装备检查。

### 8.10 Phase 8 验收

- [ ] 鼠标右键能稳定挥鞭。
- [ ] 铁鞭命中敌人能造成伤害、眩晕和击退。
- [ ] 铁鞭不能穿过枯树、岩柱命中敌人。
- [ ] 眩晕满敌人能被铁鞭拉到身前。
- [ ] 抓取敌人后玩家移动速度降低。
- [ ] 抓取敌人能抵挡正面攻击。
- [ ] 抓取状态下按 `R` 处决。
- [ ] 未抓取状态下按 `R` 换弹。
- [ ] 抓取、处决、释放不会留下无效敌人引用。

## Phase 9：整合、平衡与验证

### 9.1 完整流程回归

- [ ] 启动游戏进入主菜单。
- [ ] 点击开始游戏进入选关。
- [ ] 选关界面正确显示两关历史最高分和最长时间。
- [ ] 选择荒漠进入生存局。
- [ ] 荒漠随机生成枯树。
- [ ] 荒漠敌人从边界外刷新。
- [ ] 荒漠玩家死亡后进入结算。
- [ ] 返回选关后选择熔岩地狱。
- [ ] 熔岩随机生成河流和岩柱。
- [ ] 熔岩敌人从边界外刷新。
- [ ] 熔岩玩家死亡后进入结算。
- [ ] 两关记录互不覆盖。

### 9.2 战斗系统回归

- [ ] 手枪能伤害敌人并增加少量眩晕。
- [ ] 霰弹枪能多弹丸伤害敌人并增加眩晕。
- [ ] 铁鞭能伤害、眩晕、击退敌人。
- [ ] 眩晕满的敌人能被拉取。
- [ ] 被抓取敌人能作为盾牌。
- [ ] 被抓取敌人能被处决。
- [ ] 玩家没有抓取敌人时，`R` 是换弹。
- [ ] 玩家抓取敌人时，`R` 是处决。
- [ ] 玩家死亡后所有抓取和拉取状态清空。

### 9.3 关卡系统回归

- [ ] 玩家无法离开荒漠圆形边界。
- [ ] 玩家无法离开熔岩圆形边界。
- [ ] 触碰边界显示提示。
- [ ] 枯树能阻挡玩家、敌人和射线。
- [ ] 岩柱能阻挡玩家、敌人和射线。
- [ ] 熔岩只造成持续伤害，不阻挡玩家。
- [ ] 随机物件不会生成在玩家出生安全区。
- [ ] 重复进入关卡不会叠加旧随机物件。

### 9.4 敌人系统回归

- [ ] 八类敌人都能从 SpawnManager 刷新。
- [ ] 地面近战敌人能接近并攻击玩家。
- [ ] 远程敌人能保持距离并攻击玩家。
- [ ] 空中敌人能保持悬浮高度。
- [ ] 高级敌人的数值明显高于普通敌人。
- [ ] 精英敌人能形成阶段性压力。
- [ ] 敌人死亡只计分一次。
- [ ] 敌人被抓取、处决、环境伤害击杀时都不会报错。

### 9.5 难度和平衡首轮

- [ ] 荒漠前 60 秒主要刷普通地面敌人。
- [ ] 荒漠 60 秒后逐步加入远程和空中敌人。
- [ ] 熔岩更早加入远程或空中敌人。
- [ ] 90 秒内玩家应能理解边界、掩体、铁鞭、抓取。
- [ ] 3 分钟后敌人压力明显提高。
- [ ] 5 分钟后允许出现精英敌人和混合敌群。
- [ ] 普通敌人应易于眩晕和抓取。
- [ ] 精英敌人应难以眩晕和抓取，但处决收益高。
- [ ] 铁鞭冷却不能短到让玩家无限控场。
- [ ] 熔岩伤害不能瞬间秒杀玩家，但必须迫使玩家离开。

### 9.6 性能和清理检查

- [ ] 连续游玩 10 分钟，敌人和投射物不会无限堆积。
- [ ] 返回选关后，当前关卡节点被释放。
- [ ] 返回主菜单后，SpawnManager 停止。
- [ ] 玩家死亡后，所有投射物或预警节点能被清理或自然消失。
- [ ] 多次重新开始同一关，不出现重复信号连接。
- [ ] 多次切换关卡，不出现重复 HUD、重复菜单或重复敌人管理器。
- [ ] 当前占位 CSG 数量不会造成明显卡顿。

### 9.7 调试开关

- [ ] 添加全局调试开关或导出变量，控制敌人状态打印。
- [ ] 添加开关控制眩晕条是否显示。
- [ ] 添加开关控制刷怪预警是否显示。
- [ ] 添加开关控制固定随机种子。
- [ ] 添加开关控制是否暂停刷怪，方便测试铁鞭。
- [ ] 调试开关默认适合开发，发布前再统一关闭或隐藏。

### 9.8 Phase 9 验收

- [ ] 主菜单、选关、两关游玩、死亡结算、记录保存形成完整闭环。
- [ ] 荒漠和熔岩地狱在玩法上有明显差异。
- [ ] 八类敌人都能在合适时间段出现。
- [ ] 铁鞭、眩晕、抓取、盾牌、处决全部可用。
- [ ] 分数和最长时间能按关卡分别记录。
- [ ] 连续游玩和反复切换关卡没有明显残留状态。

## 建议文件清单

### 新增脚本

- [ ] `scripts/core/game_state.gd`
- [ ] `scripts/core/run_stats.gd`
- [ ] `scripts/core/save_data.gd`
- [ ] `scripts/level/level_registry.gd`
- [ ] `scripts/level/arena_level.gd`
- [ ] `scripts/level/arena_randomizer.gd`
- [ ] `scripts/level/desert_arena.gd`
- [ ] `scripts/level/lava_arena.gd`
- [ ] `scripts/level/props/dead_tree_prop.gd`
- [ ] `scripts/level/props/rock_column_prop.gd`
- [ ] `scripts/level/hazards/lava_river.gd`
- [ ] `scripts/enemy/spawn_entry.gd`
- [ ] `scripts/enemy/spawn_manager.gd`
- [ ] `scripts/enemy/ground_enemy.gd`
- [ ] `scripts/enemy/advanced_ground_enemy.gd`
- [ ] `scripts/enemy/elite_ground_enemy.gd`
- [ ] `scripts/enemy/ranged_enemy.gd`
- [ ] `scripts/enemy/advanced_ranged_enemy.gd`
- [ ] `scripts/enemy/flying_enemy.gd`
- [ ] `scripts/enemy/advanced_flying_enemy.gd`
- [ ] `scripts/enemy/flying_ranged_enemy.gd`
- [ ] `scripts/combat/shield_blocker.gd`
- [ ] `scripts/weapon/iron_whip.gd`
- [ ] `scripts/ui/main_menu.gd`
- [ ] `scripts/ui/level_select.gd`
- [ ] `scripts/ui/game_over_screen.gd`

### 新增场景

- [ ] `scenes/levels/desert_arena.tscn`
- [ ] `scenes/levels/lava_arena.tscn`
- [ ] `scenes/props/dead_tree_prop.tscn`
- [ ] `scenes/props/rock_column_prop.tscn`
- [ ] `scenes/hazards/lava_river.tscn`
- [ ] `scenes/enemies/ground_enemy.tscn`
- [ ] `scenes/enemies/advanced_ground_enemy.tscn`
- [ ] `scenes/enemies/elite_ground_enemy.tscn`
- [ ] `scenes/enemies/ranged_enemy.tscn`
- [ ] `scenes/enemies/advanced_ranged_enemy.tscn`
- [ ] `scenes/enemies/flying_enemy.tscn`
- [ ] `scenes/enemies/advanced_flying_enemy.tscn`
- [ ] `scenes/enemies/flying_ranged_enemy.tscn`
- [ ] `scenes/ui/main_menu.tscn`
- [ ] `scenes/ui/level_select.tscn`
- [ ] `scenes/ui/game_over_screen.tscn`

### 新增资源

- [ ] `assets/enemies/ground_enemy.tres`
- [ ] `assets/enemies/advanced_ground_enemy.tres`
- [ ] `assets/enemies/elite_ground_enemy.tres`
- [ ] `assets/enemies/ranged_enemy.tres`
- [ ] `assets/enemies/advanced_ranged_enemy.tres`
- [ ] `assets/enemies/flying_enemy.tres`
- [ ] `assets/enemies/advanced_flying_enemy.tres`
- [ ] `assets/enemies/flying_ranged_enemy.tres`
- [ ] `assets/weapons/iron_whip.tres` 或专用 `WhipData .tres`
- [ ] 两个关卡的配置资源：半径、障碍数量、颜色、刷怪曲线。

### 重点修改文件

- [ ] `scripts/main.gd`
- [ ] `scripts/player/player_controller.gd`
- [ ] `scripts/ui/player_status.gd`
- [ ] `scripts/weapon/weapon_data.gd`
- [ ] `scripts/weapon/weapon_node.gd`
- [ ] `scripts/weapon/weapon_manager.gd`
- [ ] `scripts/enemy/enemy_data.gd`
- [ ] `scripts/enemy/enemy.gd`
- [ ] `scripts/enemy/enemy_manager.gd`
- [ ] `scripts/enemy/projectile.gd`
- [ ] `project.godot`

## 推荐实现顺序

1. 完成 Phase 0，先让现有运行结构适合继续扩展。
2. 完成 Phase 1，建立开始游戏、选关、结算和记录。
3. 完成 Phase 2，做出可复用圆形竞技场。
4. 完成 Phase 3 和 Phase 4，分别落地荒漠与熔岩地狱。
5. 完成 Phase 5，统一敌人属性、眩晕、重量、AI 状态。
6. 完成 Phase 6，逐个加入八类敌人。
7. 完成 Phase 7 的 SpawnManager，让单局形成持续压力。
8. 完成 Phase 8，加入铁鞭、抓取、盾牌、处决。
9. 完成 Phase 9，集中做整合验证和数值调整。

## 暂不处理

- [ ] 正式 3D 模型、动画、材质贴图。
- [ ] 完整音频系统。
- [ ] 复杂地图编辑器或 `.tres` 关卡导出流程。
- [ ] 多阶段剧情关卡。
- [ ] 高级导航网格和复杂寻路，初期优先用简单直线追踪与避障。

# DoomLike - Godot 4.6 DOOM风格FPS游戏

## 项目概览

Godot 4.6 项目，正在构建一款DOOM风格的第一人称射击游戏。当前处于**Roadmap 2 Phase 2 已完成**——圆形竞技场加载管线、关卡注册表、随机数工具、边界限制已可运行，选关后能进入荒漠/熔岩竞技场（带地面+边界柱）。下一步 Phase 3：荒漠竞技场道具生成。

- **引擎**：Godot 4.6 (Forward Plus, D3D12)
- **物理**：Jolt Physics
- **主场景**：`res://scenes/main.tscn`
- **窗口**：1280×720

## 目录结构

```
scripts/        GDScript 源代码
  main.gd           主游戏控制器（ArenaLevel加载管线/状态机/菜单信号/命中标记）
  core/             运行状态、存档、统计（Phase 1 实现）
    game_state.gd     GameState 枚举（BOOT→MAIN_MENU→LEVEL_SELECT→PLAYING→PAUSED→GAME_OVER）
    run_stats.gd      当前局统计（分数/击杀/时间）
    save_data.gd      ConfigFile 存档管理（最高分/最长时间）
  player/           玩家相关（player_controller.gd）
  ui/               UI系统
    player_status.gd  战斗HUD（位置/状态/生命条/护甲/击杀/武器/弹药/分数/时间/强度/边界警告）
    main_menu.gd      主菜单（开始游戏/退出）
    pause_menu.gd     暂停菜单（继续/返回主菜单）
    level_select.gd   选关界面（从 LevelRegistry 动态读取关卡数据）
    game_over_screen.gd 结算界面（本局+历史数据/新纪录/三按钮）
  weapon/           武器系统
    weapon_data.gd     WeaponData Resource + DamageType/FireMode 枚举
    weapon_node.gd     武器基类（射线射击/散布/弹药/换弹/后坐力/重置弹药）
    weapon_manager.gd  武器栏位管理（切换/重置所有武器）
    pistol.gd          手枪（半自动，CSG占位模型）
    shotgun.gd         霰弹枪（泵动式+多弹丸散射，CSG占位模型）
  damage/           伤害系统
    damageable.gd      可受伤接口（血量/护甲/减伤/重置/治疗信号）
    shooting_target.gd 射击靶子（测试用，自动创建Damageable）
  enemy/            敌人系统
    enemy_data.gd      EnemyData Resource 配置（生命/速度/AI/伤害参数）
    enemy.gd           Enemy 基类（CharacterBody3D，6状态机/视线检测/追击/受击/死亡）
    projectile.gd      投射物基类（Area3D，飞行/碰撞/伤害/火球外观）
    imp.gd             小恶魔（远程火球投射物 + 近战爪击，CSG人形模型）
    demon_soldier.gd   恶魔士兵（hitscan射击 + 举枪前摇+有效性检查，装甲外观）
    enemy_manager.gd   敌人生成与管理（register/unregister/spawn/存活追踪/重置）
  pickup/           拾取系统
    pickup.gd          Pickup 基类（Area3D + 悬浮旋转动画）
    health_pickup.gd   血包（红色，恢复生命）
    armor_pickup.gd    护甲（蓝色，装备护甲）
    ammo_pickup.gd     弹药（黄色，补充备弹）
  level/            关卡系统（Phase 2 实现）
    level_registry.gd  关卡注册表（id/名称/描述/场景路径/主题色 唯一权威来源）
    arena_level.gd     竞技场基类（圆形地面/边界柱/玩家边界限制/随机放置接口/出生点）
    arena_randomizer.gd 随机数工具类（圆内均匀取点/环内取点/互斥检测/非重叠点重试）
    props/             枯树、岩柱等掩体（Phase 3/4）
    hazards/           熔岩等危险区域（Phase 4）
  utils/            FPS计数器（fps_counter.gd）
scenes/         Godot 场景文件
  main.tscn          主场景
  player/            player.tscn（Player 场景）
  enemies/           imp.tscn, demon_soldier.tscn
  levels/            关卡场景
    desert_arena.tscn 荒漠竞技场（挂 ArenaLevel，arena_radius=45，72边界柱）
    lava_arena.tscn   熔岩地狱（挂 ArenaLevel，arena_radius=45，72边界柱）
  ui/                UI场景（当前均为代码创建，无 .tscn 文件）
assets/         游戏资源
  weapons/          WeaponData .tres（pistol.tres, shotgun.tres）
  enemies/          EnemyData .tres（imp.tres, demon_soldier.tres）
  audio/fonts/textures 子目录（当前为空）
shaders/        自定义着色器（当前为空）
docs/           文档（project_roadmap.md 原路线图, project_roadmap2.md 新路线图）
```

## 场景树结构

```
Main (Node3D)                          ← main.gd
├── Player (CharacterBody3D)           ← player_controller.gd [%Player]
│   ├── Damageable                     (100HP/100护甲，支持 reset())
│   ├── Camera3D                       [%Camera3D]
│   ├── CollisionShape3D               (胶囊体: 半径0.4, 高1.8)
│   └── WeaponHolder (Node3D)
│       └── WeaponManager (Node3D)     ← weapon_manager.gd (支持 reset_all_weapons())
│           ├── Pistol (WeaponNode)    ← pistol.gd (reset_ammo())
│           └── Shotgun (WeaponNode)   ← shotgun.gd (reset_ammo())
├── Level (Node3D)                     [%Level] ← 动态加载的关卡场景挂在这里
│   └── DesertArena/LavaArena (ArenaLevel) ← Phase 2.9 通过 PackedScene 实例化
│       ├── GeometryRoot               (_geometry_root) 地面
│       ├── BoundaryRoot               (_boundary_root) 64/72根边界柱
│       ├── PropsRoot                  (_props_root) 道具（Phase 3/4）
│       ├── HazardsRoot                (_hazards_root) 危险区（Phase 4）
│       └── SpawnRoot                  (_spawn_root) 刷怪点（Phase 7）
├── UI (CanvasLayer)
│   ├── DamageFlash (ColorRect)         [%DamageFlash] ← 全屏受伤闪红
│   ├── Crosshair (ColorRect)           [%Crosshair] ← 4×4像素绿色准星
│   ├── FPS (Label)                     ← fps_counter.gd
│   ├── PlayerStatus (Node)             ← player_status.gd (新增强度/边界警告)
│   ├── MainMenu (CanvasLayer)         ← main_menu.gd
│   ├── PauseMenu (CanvasLayer)        ← pause_menu.gd
│   ├── LevelSelect (CanvasLayer)      ← level_select.gd (读取 LevelRegistry)
│   └── GameOverScreen (CanvasLayer)   ← game_over_screen.gd
```

## 输入映射

| 动作 | 键位 | 用途 |
|------|------|------|
| `move_forward/back/left/right` | WASD | 移动 |
| `jump` | Space | 跳跃 |
| `primary_fire` | 鼠标左键 | 开枪 |
| `reload` | R | 换弹 |
| `weapon_1` / `weapon_2` | 1 / 2 | 切换武器栏位 |
| `ui_cancel` | Escape | 暂停/恢复 |

## 编码约定

- 注释使用**中文**
- 类名/枚举：`PascalCase`，变量/函数：`snake_case`，私有成员：`_前缀`
- 使用 `@export` 暴露可调参数到编辑器
- 使用 `%UniqueName` 引用场景节点（如 `%Player`、`%Level`）
- 类型注解：`func _ready() -> void`、`var speed: float = 8.0`
- 跨文件 class_name 解析用 `preload()` + `extends "path"` 处理加载顺序

## 当前架构说明

- **无自动加载（Autoload）**，所有节点手动实例化
- **关卡系统（Phase 2）**：`LevelRegistry` 管理关卡元数据 → `main.gd` 的 `_start_level()` 通过 PackedScene 加载 ArenaLevel → 实例化到 `_level_root`。ArenaLevel 自动生成圆形地面（CSGBox3D）+ 边界标志柱（沿圆周均匀排列）。玩家边界限制在 `_process()` 中检测，越界时夹回并发出 `boundary_warning_requested` 信号 → HUD 显示"已到达边界"。
- **关卡切换流程**：`_start_level(id)` → `_unload_current_level()`（清理旧关卡+信号）→ `_load_arena_level(id)`（PackedScene.instantiate + 连接边界信号）→ `_reset_player_for_level()`（传送出生点+重置血量/护甲/弹药/HUD）→ PLAYING
- **武器系统**：`WeaponData`(Resource) → `WeaponNode`(基类) → `WeaponManager`(栏位管理)。支持半自动/全自动/泵动式，`reset_ammo()` 和 `reset_all_weapons()` 用于关卡重启。
- **伤害系统**：`Damageable` 接口（血量/护甲/减伤），护甲吸收 50% 伤害（经典 DOOM 规则），`reset()` 恢复到满血满护甲。
- **敌人系统**：`Enemy` 基类 6 状态机，`Imp`（火球+近战）和 `DemonSoldier`（hitscan+前摇）。`EnemyManager` 统一管理注册/反注册/生成，`reset()` 清理所有追踪。
- **战斗HUD**：生命条（绿→橙→红+闪烁）、护甲（蓝色）、击杀（黄色）、武器栏位、命中标记、受伤闪红、拾取通知、分数/时间/强度（左上角，从 RunStats 读取）、边界警告（屏幕中下，橙红色大字，1.5秒自动消失）
- **菜单系统**：主菜单 → 选关（动态读取 LevelRegistry）→ 加载竞技场 → 结算（从 LevelRegistry 获取关卡名）
- **存档系统**：`SaveData` 用 ConfigFile 读写 `user://save.cfg`，`submit_run()` 比较并更新最高分/最长时间。选关和结算界面每次显示时刷新记录。
- 部分 assets 子目录为空（audio/fonts/textures）

## 关卡加载链路（Phase 2.9）

```
选关 → _on_level_selected("desert")
  → _start_level("desert")
    → _unload_current_level()          # 清理旧竞技场
    → _load_arena_level("desert")      # LevelRegistry.get_scene_path → PackedScene.instantiate
      → _current_arena.set_player()    # 注入玩家引用
      → boundary_warning_requested 信号连接
    → _reset_player_for_level()        # 传送出生点/重置血量/护甲/弹药/HUD
    → _set_game_state(PLAYING)         # 连接死亡信号/恢复物理/捕获鼠标
```

## 关卡竞技场参数（arena_level.gd）

| 参数 | 荒漠 | 熔岩 | 说明 |
|------|------|------|------|
| `arena_radius` | 45.0m | 45.0m | 可玩区域半径（直径90m） |
| `spawn_outer_radius` | 56.0m | 56.0m | 刷怪外环半径 |
| `boundary_marker_count` | 72 | 72 | 边界柱数量 |
| `random_seed` | 0 | 0 | 随机种子（0=随机） |
| `use_random_seed` | true | true | 是否使用固定种子 |
| 地面颜色 | 沙黄色 | 暗红/黑 | 由子类 `_get_ground_color()` 覆写 |
| 边界柱颜色 | 浅黄/白 | 亮橙/红 | 由子类 `_get_boundary_color()` 覆写 |

## 关键参数（player_controller.gd）

| 参数 | 值 | 说明 |
|------|-----|------|
| `move_speed` | 8.0 | 移动速度 (m/s) |
| `acceleration` | 40.0 | 加速度 |
| `friction` | 30.0 | 摩擦力 |
| `gravity` | 20.0 | 重力（比现实大，DOOM手感） |
| `jump_velocity` | 12.0 | 跳跃初速（约3.6米高） |
| `mouse_sensitivity` | 0.002 | 鼠标灵敏度 |
| `vertical_limit` | 90.0° | 垂直视角限制 |

## 武器参数（weapon_data.gd / WeaponData Resource）

| 属性 | 手枪默认值 | 霰弹枪默认值 | 说明 |
|------|-----------|-------------|------|
| `damage` | 15.0 | 10.0 | 每颗弹丸伤害（霰弹枪×7弹丸=70点上限） |
| `max_range` | 50.0m | 25.0m | 射线最大射程 |
| `fire_rate` | 2.5发/秒 | 2.0发/秒 | 理论射速（泵动式由动画控制） |
| `fire_mode` | SEMI(0) | PUMP(2) | 半自动/全自动/泵动式 |
| `mag_size` | 8 | 2 | 弹匣容量 |
| `reserve_ammo` | 50 | 20 | 备弹数 |
| `reload_time` | 1.2秒 | 2.0秒 | 换弹耗时 |
| `spread_angle` | 2.0° | 10.0° | 散布圆锥半角 |
| `pellet_count` | 1 | 7 | 每次射击弹丸数 |
| `move_spread_mult` | 1.5 | 1.5 | 移动散布惩罚倍数 |
| `damage_type` | HITSCAN(0) | HITSCAN(0) | 伤害类型 |

## 敌人参数（enemy_data.gd / EnemyData Resource）

| 属性 | 小恶魔 (Imp) | 恶魔士兵 (Demon Soldier) | 说明 |
|------|-------------|------------------------|------|
| `max_health` | 80 | 120 | 生命值 |
| `attack_damage` | 15 | 8 | 每次攻击伤害 |
| `damage_type` | PROJECTILE(1) | HITSCAN(0) | 火球飞行弹 / 瞬时射线 |
| `move_speed` | 5.0m/s | 3.0m/s | 追击速度（比玩家8.0慢） |
| `attack_range` | 12.0m | 20.0m | 攻击触发距离 |
| `sight_range` | 30.0m | 35.0m | 发现玩家距离 |
| `attack_cooldown` | 1.0s | 1.5s | 攻击间隔 |
| `pain_duration` | 0.3s | 0.3s | 受击硬直时间 |
| `knockback_force` | 3.0 | 3.0 | 击退力度 |
| `death_duration` | 2.0s | 2.5s | 尸体停留时间 |

## 射击流程（weapon_node.gd）

```
玩家按左键 → _try_fire() 检查（冷却/换弹/泵动/弹药）
  → _fire() 循环 pellet_count 次：
     → _get_spread_direction() 计算随机散布方向
     → _fire_single_pellet() 发射 PhysicsRayQueryParameters3D
     → intersect_ray() 物理检测
     → 命中则调用 target.take_damage(amount, type)
  → 扣弹药 → 设冷却 → _apply_recoil() → 发射信号
  → 命中敌人时 main.gd 准星闪红 80ms
```

## 敌人AI流程（enemy.gd）

```
IDLE/PATROL → 射线检测玩家视线 + 距离 < sight_range
  → CHASE → 朝玩家直线移动（XZ平面）
    → 距离 < attack_range → ATTACK
      Imp: 近战(≤2m,爪击) / 远程(>2m,火球10m/s)
      Soldier: hitscan射线(举枪前摇0.15s)
    → 攻击冷却后距离 > attack_range*1.2 → 回归CHASE
  → 受到伤害 → PAIN(0.3s硬直+闪白+击退) → CHASE
  → 生命归零 → DEATH(缩小/变灰/下沉) → queue_free
  → enemy_died信号 → EnemyManager追踪 → 全灭all_cleared
```

## 战斗HUD布局（player_status.gd）

```
左上角                          右上角
FPS: 60                          位置: 0.0  1.6  0.0
分数: 0                          地面  静止
时间: 0.0                        生命条（绿→橙→红，低血闪烁）
强度: 1                          生命: 100 / 100
                                  护甲: 0 / 100
屏幕中上                          击杀: 0  (小恶魔)
+30 弹药 (拾取通知)              手枪
屏幕中下                          8 / 50
已到达边界 (边界警告)            [1] 手枪  2  霰弹枪
                                  换弹中...
```

## 菜单流程（Phase 2.9）

```
启动 → MAIN_MENU（"DOOM-LIKE" + 开始游戏/退出）
  → 开始游戏 → LEVEL_SELECT（从 LevelRegistry 动态读取两个关卡面板）
    → 选荒漠 → _start_level("desert") → 加载 desert_arena.tscn → PLAYING
    → 选熔岩 → _start_level("lava") → 加载 lava_arena.tscn → PLAYING
  → 战斗中按 Esc → PAUSED（继续/返回主菜单）
  → 玩家死亡 → GAME_OVER（结算界面：本局统计 + 历史记录 + 新纪录提示）
    → 重新开始本关 → _start_level(当前关卡) → 卸载旧关 → 加载新关
    → 返回选关 → LEVEL_SELECT
    → 返回主菜单 → MAIN_MENU
  → 退出 → quit()
```

## 护甲减伤规则（damageable.gd）

```
受到伤害 X 点，有护甲 A：
  护甲吸收 = min(X × 0.5, A)     # 吸收 50%，最多耗尽护甲
  血量扣减 = X - 护甲吸收
  例：20伤 60甲 → 血量-10 护甲-10
  例：20伤 5甲  → 血量-15 护甲归零
```

## 关卡重启重置清单（_reset_player_for_level）

- 玩家位置 → `get_player_spawn_transform()`（圆心上方1.6m 或 PlayerStart 节点）
- 玩家速度 → `.velocity = Vector3.ZERO`
- Damageable → `.reset()`（满血满护甲）
- WeaponManager → `.reset_all_weapons()`（弹药回满 + 切回第一把武器）
- HUD 击杀计数 → `.reset_kill_count()`（击杀数归零）

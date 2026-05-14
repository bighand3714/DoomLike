# DoomLike - Godot 4.6 DOOM风格FPS游戏

## 项目概览

Godot 4.6 项目，正在构建一款DOOM风格的第一人称射击游戏。当前处于**Roadmap 2 Phase 0 已完成**——核心移动 + 武器/射击/伤害 + 敌人AI/投射物 + 菜单/拾取系统已可运行。Phase 5/6（旧路线图）暂缓，新方向以 `docs/project_roadmap2.md` 为准。下一步 Phase 1：游戏流程、菜单与记录。

- **引擎**：Godot 4.6 (Forward Plus, D3D12)
- **物理**：Jolt Physics
- **主场景**：`res://scenes/main.tscn`
- **窗口**：1280×720

## 目录结构

```
scripts/        GDScript 源代码
  main.gd           主游戏控制器（关卡加载/CSG碰撞/出生点/菜单协调/命中标记/拾取通知）
  core/             运行状态、存档、统计（Phase 1+ 实现）
  player/           玩家相关（player_controller.gd）
  ui/               UI系统
    player_status.gd  战斗HUD（位置/状态/生命条/护甲/击杀/武器/弹药/拾取通知）
    main_menu.gd      主菜单（开始游戏/退出）
    pause_menu.gd     暂停菜单（继续/返回主菜单）
  weapon/           武器系统
    weapon_data.gd     WeaponData Resource + DamageType/FireMode 枚举
    weapon_node.gd     武器基类（射线射击、散布、弹药、换弹、后坐力、_is_equipped/token机制）
    weapon_manager.gd  武器栏位管理（切换、输入转发）
    pistol.gd          手枪（半自动，CSG占位模型）
    shotgun.gd         霰弹枪（泵动式+多弹丸散射，CSG占位模型）
  damage/           伤害系统
    damageable.gd      可受伤接口（血量/护甲/减伤/治疗信号）
    shooting_target.gd 射击靶子（测试用，自动创建Damageable）
  enemy/            敌人系统
    enemy_data.gd      EnemyData Resource 配置（生命/速度/AI/伤害参数）
    enemy.gd           Enemy 基类（CharacterBody3D，6状态机、视线检测、追击、受击、死亡）
    projectile.gd      投射物基类（Area3D，飞行、碰撞、伤害、火球外观）
    imp.gd             小恶魔（远程火球投射物 + 近战爪击，CSG人形模型）
    demon_soldier.gd   恶魔士兵（hitscan射击 + 举枪前摇+有效性检查，装甲外观）
    enemy_manager.gd   敌人生成与管理（register/unregister/spawn、存活追踪、击杀信号）
  pickup/           拾取系统
    pickup.gd          Pickup 基类（Area3D + 悬浮旋转动画）
    health_pickup.gd   血包（红色，恢复生命）
    armor_pickup.gd    护甲（蓝色，装备护甲）
    ammo_pickup.gd     弹药（黄色，补充备弹）
  level/            关卡系统（Roadmap 2 Phase 2+ 实现）
    props/             枯树、岩柱等掩体（Phase 3/4）
    hazards/           熔岩等危险区域（Phase 4）
  utils/            FPS计数器（fps_counter.gd）
scenes/         Godot 场景文件
  main.tscn          主场景
  player/            player.tscn（Player 场景）
  enemies/           imp.tscn, demon_soldier.tscn
  levels/            关卡场景（Phase 2+ 实现）
  ui/                UI场景（Phase 1+ 实现）
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
├── Player (CharacterBody3D)           ← player_controller.gd [%Player] (player.tscn)
│   ├── Damageable                     (100HP/100护甲，自动创建)
│   ├── Camera3D                       [%Camera3D]
│   ├── CollisionShape3D               (胶囊体: 半径0.4, 高1.8)
│   └── WeaponHolder (Node3D)
│       └── WeaponManager (Node3D)     ← weapon_manager.gd (栏位管理)
│           ├── Pistol (WeaponNode)    ← pistol.gd (半自动)
│           └── Shotgun (WeaponNode)   ← shotgun.gd (泵动式)
├── Level (Node3D)                     [%Level] ← 编辑器手动搭建的关卡几何体
│   ├── Ground_MainFloor (CSGBox3D)    地板（level_geometry group）
│   ├── PlayerStart (Node3D)           玩家出生点标记
│   ├── EnemyManager (Node)            [%EnemyManager] ← register/unregister/spawn
│   └── Imp / DemonSoldier             敌人实例（通过 .tscn 拖入，_ready 自动注册）
├── UI (CanvasLayer)
│   ├── DamageFlash (ColorRect)         [%DamageFlash] ← 全屏受伤闪红
│   ├── Crosshair (ColorRect)           [%Crosshair] ← 4×4像素绿色准星
│   ├── FPS (Label)                     ← fps_counter.gd
│   ├── PlayerStatus (Node)             ← player_status.gd
│   ├── MainMenu (CanvasLayer)         ← main_menu.gd
│   └── PauseMenu (CanvasLayer)        ← pause_menu.gd
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
- **关卡在编辑器中手动搭建**：CSG 节点放在 `Level` 下，`main.gd` 用 `_enable_csg_collision()` 只对 `level_geometry` group 或 `Ground_`/`Wall_`/`Boundary_` 前缀节点启用碰撞。通过 `PlayerStart` 节点标记出生点
- **武器系统已实现**：`WeaponData`(Resource) → `WeaponNode`(基类) → `WeaponManager`(栏位管理)。射击使用 `PhysicsRayQueryParameters3D` 从摄像机发射线，支持半自动/全自动/泵动式三种模式。**Phase 0 修复**：`_is_equipped` 检查（未装备武器不响应输入）、`_reload_token`/`_pump_token` 机制（切武器后旧 timer 失效）
- **伤害系统已实现**：`Damageable` 可受伤接口（血量/护甲/减伤）。护甲吸收 50% 伤害（经典 DOOM 规则）。Player 自动创建 Damageable（100HP/100护甲），先检查已有节点避免重复创建
- **敌人系统已实现**：`Enemy` 基类 6 状态机（IDLE→CHASE→ATTACK→PAIN→DEATH），视线射线检测，`Imp`（火球+近战）和 `DemonSoldier`（hitscan+前摇+有效性检查）两种敌人。**Phase 0 修复**：玩家引用优先使用 `get_first_node_in_group("player")`（Player 在 `_ready` 中加入 `player` group）；`EnemyManager` 通过 `register_enemy()`/`unregister_enemy()` 统一管理敌人注册，`_ready` 中扫描已有敌人
- **投射物系统已实现**：`Projectile` Area3D 基类，飞行移动、碰撞伤害、生命周期。Imp 火球 10m/s
- **战斗HUD已实现**：生命条（绿→橙→红+闪烁）、护甲（蓝色）、击杀计数（黄色）、武器栏位指示器、命中标记（准星闪红）、受伤效果（全屏闪红）、拾取通知（中上浮出淡入淡出）
- **菜单系统已实现**：主菜单（开始游戏/退出）、暂停菜单（继续/返回主菜单，Esc 快捷键）
- **拾取系统已实现**：`Pickup` Area3D 基类（悬浮旋转动画），血包/护甲/弹药三种拾取物
- 部分 assets 子目录为空（audio/fonts/textures）

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
右上角，从上到下排列：
  位置:  0.0   1.6   0.0        (白色14号)
  地面  静止                    (灰色14号)
  ████████████████              (生命条 绿→橙→红，低血闪烁)
  生命: 100 / 100               (白色14号，覆盖在生命条上)
  护甲: 0 / 100                 (蓝色14号)
  击杀: 0  (小恶魔)             (黄色14号)
  手枪                          (灰色15号)
  8 / 50                        (白色22号大字)
  [1] 手枪  2  霰弹枪          (当前武器高亮)
  换弹中...                     (橙色14号，隐藏)

  屏幕中上：拾取通知（浮出淡入淡出，1.5秒）
```

## 菜单流程

```
启动 → 主菜单（"DOOM-LIKE" + 开始游戏/退出）
  → 开始游戏 → 捕获鼠标、恢复物理、进入战斗
  → 战斗中按 Esc → 暂停菜单（继续/返回主菜单）
    → 继续 → 恢复战斗
    → 返回主菜单 → 回到主菜单
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

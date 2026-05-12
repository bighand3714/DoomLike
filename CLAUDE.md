# DoomLike - Godot 4.6 DOOM风格FPS游戏

## 项目概览

Godot 4.6 项目，正在构建一款DOOM风格的第一人称射击游戏。当前处于**第二阶段（武器与射击）已完成**——核心移动 + 武器/射击/伤害系统已可运行，敌人/地图编辑器等系统待实现。总进度 37/116 任务（32%）。

- **引擎**：Godot 4.6 (Forward Plus, D3D12)
- **物理**：Jolt Physics
- **主场景**：`res://scenes/main.tscn`
- **窗口**：1280×720

## 目录结构

```
scripts/        GDScript 源代码
  main.gd           主游戏控制器（初始化、测试房间搭建、靶子放置、准星）
  player/           玩家相关（player_controller.gd）
  level/            关卡系统（level_data.gd 数据蓝图, level_builder.gd 建造器）
  editor/           编辑器模式切换（game_mode.gd）
  utils/            FPS计数器（fps_counter.gd）
  ui/               HUD 状态显示（player_status.gd）
  weapon/           武器系统
    weapon_data.gd     WeaponData Resource + DamageType/FireMode 枚举
    weapon_node.gd     武器基类（射线射击、散布、弹药、换弹、后坐力）
    weapon_manager.gd  武器栏位管理（切换、输入转发）
    pistol.gd          手枪（半自动，CSG占位模型）
    shotgun.gd         霰弹枪（泵动式+多弹丸散射，CSG占位模型）
  damage/           伤害系统
    damageable.gd      可受伤接口（血量、受伤/死亡信号）
    shooting_target.gd 射击靶子（测试用，自动创建Damageable）
scenes/         Godot 场景文件（main.tscn + 子场景占位目录）
assets/         游戏资源
  weapons/          WeaponData .tres 配置文件（pistol.tres, shotgun.tres）
  audio/fonts/levels/textures 子目录（当前为空）
shaders/        自定义着色器（当前为空）
docs/           文档（project_roadmap.md 路线图）
```

## 场景树结构

```
Main (Node3D)                          ← main.gd
├── Player (CharacterBody3D)           ← player_controller.gd [%Player]
│   ├── Camera3D                       [%Camera3D]
│   ├── CollisionShape3D               (胶囊体: 半径0.4, 高1.8)
│   └── WeaponHolder (Node3D)
│       └── WeaponManager (Node3D)     ← weapon_manager.gd (栏位管理)
│           ├── Pistol (WeaponNode)    ← pistol.gd (半自动)
│           └── Shotgun (WeaponNode)   ← shotgun.gd (泵动式)
├── Level (Node3D)                     [%Level] ← 程序化CSG几何体生成位置
└── UI (CanvasLayer)
    ├── Crosshair (ColorRect)           [%Crosshair]
    ├── FPS (Label)                     ← fps_counter.gd
    └── PlayerStatus (Node)             ← player_status.gd (位置/状态/武器HUD)
```

## 输入映射

| 动作 | 键位 | 用途 |
|------|------|------|
| `move_forward/back/left/right` | WASD | 移动 |
| `jump` | Space | 跳跃 |
| `primary_fire` | 鼠标左键 | 开枪 |
| `reload` | R | 换弹 |
| `weapon_1` / `weapon_2` | 1 / 2 | 切换武器栏位 |
| `ui_cancel` | Escape | 释放/捕获鼠标 |

## 编码约定

- 注释使用**中文**
- 类名/枚举：`PascalCase`，变量/函数：`snake_case`，私有成员：`_前缀`
- 使用 `@export` 暴露可调参数到编辑器
- 使用 `%UniqueName` 引用场景节点（如 `%Player`、`%Level`）
- 类型注解：`func _ready() -> void`、`var speed: float = 8.0`

## 当前架构说明

- **无自动加载（Autoload）**，所有节点手动实例化
- **关卡管线未连接**：`LevelData`/`LevelBuilder` 已定义但未被 `main.gd` 调用，当前测试房间直接通过 `_build_test_room()` 硬编码 CSG 生成
- **武器系统已实现**：`WeaponData`(Resource) → `WeaponNode`(基类) → `WeaponManager`(栏位管理)。射击使用 `PhysicsRayQueryParameters3D` 从摄像机发射线，支持半自动/全自动/泵动式三种模式，弹药/换弹/散布/后坐力全部可配
- **伤害系统已实现**：`Damageable` 可受伤接口（血量/信号），`ShootingTarget` 测试靶子（闪白/变灰/关闭碰撞）
- **编辑器模式切换器**（GameModeManager）已定义但未挂载到场景树
- 部分 assets 子目录为空（audio/fonts/levels/textures）

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
| `damage_type` | HITSCAN(0) | HITSCAN(0) | 伤害类型（HITSCAN/PROJECTILE/EXPLOSION/MELEE） |

## 射击流程（weapon_node.gd）

```
玩家按左键 → _try_fire() 检查（冷却/换弹/泵动/弹药）
  → _fire() 循环 pellet_count 次：
     → _get_spread_direction() 计算随机散布方向
     → _fire_single_pellet() 发射 PhysicsRayQueryParameters3D
     → intersect_ray() 物理检测
     → 命中则调用 target.take_damage(amount, type)
  → 扣弹药 → 设冷却 → _apply_recoil() → 发射信号
```

# DoomLike - Godot 4.6 DOOM风格FPS游戏

## 项目概览

Godot 4.6 项目，正在构建一款DOOM风格的第一人称射击游戏。当前处于**第四阶段（关卡管线）已完成**——核心移动 + 武器/射击/伤害 + 敌人AI/投射物 + 关卡数据驱动加载系统已可运行，地图编辑器等系统待实现。总进度 95/156 任务（61%）。

- **引擎**：Godot 4.6 (Forward Plus, D3D12)
- **物理**：Jolt Physics
- **主场景**：`res://scenes/main.tscn`
- **窗口**：1280×720

## 目录结构

```
scripts/        GDScript 源代码
  main.gd           主游戏控制器（关卡加载、创建/回退、命中标记、受伤闪红）
  player/           玩家相关（player_controller.gd）
  level/            关卡系统
    level_data.gd       LevelData Resource（Sector/WallDef/ThingDef 数据结构）
    level_builder.gd    关卡建造器（数据→3D场景、墙壁/地板/天花板/灯光/实体生成、反向序列化）
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
  enemy/            敌人系统（Phase 3）
    enemy_data.gd      EnemyData Resource 配置（生命/速度/AI/伤害参数）
    enemy.gd           Enemy 基类（CharacterBody3D，6状态机、视线检测、追击、受击、死亡）
    projectile.gd      投射物基类（Area3D，飞行、碰撞、伤害、火球外观）
    imp.gd             小恶魔（远程火球投射物 + 近战爪击，CSG人形模型）
    demon_soldier.gd   恶魔士兵（hitscan射击 + 举枪前摇，装甲外观）
    enemy_manager.gd   敌人生成与管理（追踪存活、击杀信号、all_clear检测）
scenes/         Godot 场景文件（main.tscn）
assets/         游戏资源
  weapons/          WeaponData .tres 配置文件（pistol.tres, shotgun.tres）
  enemies/          EnemyData .tres 配置文件（imp.tres, demon_soldier.tres）
  levels/           关卡数据（test_room.tres 预留目录）
  audio/fonts/textures 子目录（当前为空）
shaders/        自定义着色器（当前为空）
docs/           文档（project_roadmap.md 路线图）
```

## 场景树结构

```
Main (Node3D)                          ← main.gd
├── Player (CharacterBody3D)           ← player_controller.gd [%Player]
│   ├── Damageable                     (100HP，自动创建)
│   ├── Camera3D                       [%Camera3D]
│   ├── CollisionShape3D               (胶囊体: 半径0.4, 高1.8)
│   └── WeaponHolder (Node3D)
│       └── WeaponManager (Node3D)     ← weapon_manager.gd (栏位管理)
│           ├── Pistol (WeaponNode)    ← pistol.gd (半自动)
│           └── Shotgun (WeaponNode)   ← shotgun.gd (泵动式)
├── Level (Node3D)                     [%Level] ← 关卡几何体容器
│   ├── LevelBuilder (Node3D)          ← level_builder.gd (数据→3D场景)
│   │   └── Sector_N (Node3D)         每个扇区一个容器
│   │       ├── Floor (CSGBox3D)      地板
│   │       ├── Ceiling (CSGBox3D)    天花板
│   │       ├── Wall ×N (CSGBox3D)    墙壁（实墙有碰撞/Portal无碰撞）
│   │       └── SectorLight (OmniLight3D) 扇区灯光
│   ├── EnemyManager (Node)            [%EnemyManager] ← 敌人实例化 + 追踪
│   ├── GlobalDirectionalLight         主方向光
│   └── GlobalFillLight                补光
├── UI (CanvasLayer)
│   ├── DamageFlash (ColorRect)         [%DamageFlash] ← 全屏受伤闪红
│   ├── Crosshair (ColorRect)           [%Crosshair] ← 4×4像素绿色准星
│   ├── FPS (Label)                     ← fps_counter.gd
│   └── PlayerStatus (Node)             ← player_status.gd (位置/状态/生命/击杀/武器HUD)
```

## 测试关卡布局（3扇区连通空间）

```
                ← Z=-9 →
             ┌──────────────────┐
             │   北室 S1        │  6×6m  h=3m  偏暗(120)
             │   1×Demon Soldier │
     Z=-4    │    ╔══════╗      │  ← 3m宽门洞
┌────────────┴────╨──────╨──────┴────────────┐
│            ║              ║                │
│            ║   主大堂 S0  ║                │
│            ║   10×8m      ║                │
│            ║    h=4m(160) ╠════╗           │
│            ║              ║    ╚═══════════→X=10
│       出生 ║              ║                │
│     (0,3)  ║              ║   Z=5           │
│            ║              ║                │
└────────────╨──────────────╨──┐              │
     Z=-5    ║              ║  │              │
             ╚══════════════╝  │              │
             │   东翼 S2       │              │
             │   5×10m  h=5m  最亮(200)       │
             │   1×Imp                         │
             └─────────────────────────────────┘

═══ 门洞 (portal, 无碰撞)  ─── 实墙 (有碰撞)
```

| 扇区 | 范围 | 面积 | 天花板 | 亮度 | 敌人 |
|------|------|------|--------|------|------|
| S0 主大堂 | X:-5~5, Z:-4~4 | 10×8m | 4m | 160 | 2 Imp |
| S1 北室 | X:-3~3, Z:-9~-3 | 6×6m | 3m | 120 | 1 Demon Soldier |
| S2 东翼 | X:5~10, Z:-5~5 | 5×10m | 5m | 200 | 1 Imp |

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
- 跨文件 class_name 解析用 `preload()` + `extends "path"` 处理加载顺序

## 当前架构说明

- **无自动加载（Autoload）**，所有节点手动实例化
- **关卡管线已连接**：`main.gd` 调用 `_create_test_level()` 构建 LevelData → `LevelBuilder.build()` 生成 3D 场景。优先加载 `.tres`，不存在时回退到代码构建。支持 `serialize()` 反向提取
- **武器系统已实现**：`WeaponData`(Resource) → `WeaponNode`(基类) → `WeaponManager`(栏位管理)。射击使用 `PhysicsRayQueryParameters3D` 从摄像机发射线，支持半自动/全自动/泵动式三种模式，弹药/换弹/散布/后坐力全部可配
- **伤害系统已实现**：`Damageable` 可受伤接口（血量/信号），`ShootingTarget` 测试靶子（闪白/变灰/关闭碰撞）。Player 自动创建 Damageable（100HP）
- **敌人系统已实现**：`Enemy` 基类 6 状态机（IDLE→CHASE→ATTACK→PAIN→DEATH），视线射线检测，`Imp`（火球+近战）和 `DemonSoldier`（hitscan+前摇）两种敌人。`EnemyManager` 追踪击杀并检测清场
- **投射物系统已实现**：`Projectile` Area3D 基类，飞行移动、碰撞伤害、生命周期。Imp 火球 10m/s
- **战斗HUD已实现**：生命值（绿→红低血警告）、击杀计数（黄色）、命中标记（准星闪红）、受伤效果（全屏闪红）
- **编辑器模式切换器**（GameModeManager）已定义但未挂载到场景树
- 部分 assets 子目录为空（audio/fonts/textures）

## 关卡数据流

```
main.gd: _create_test_level() 或 .tres 文件
  → LevelData (Sector/WallDef/ThingDef 数据)
  → LevelBuilder.build()
    → 遍历 sectors: _build_sector()
      → _build_wall()    WallDef 2D线段 → CSGBox3D 3D薄墙（含Portal碰撞控制）
      → _build_floor()   AABB → CSGBox3D 地板
      → _build_ceiling() AABB → CSGBox3D 天花板
      → _build_light()   light_level → OmniLight3D
    → 遍历 things: _place_thing()
      → PLAYER_START → 记录出生点
      → ENEMY → EnemyManager.spawn_enemy()
      → PICKUP → 发光方块占位
      → DECORATION → 柱子/火把等
  → Player 传送到出生点
  → LevelBuilder.serialize() 可反向提取
```

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
  生命: 100 / 100               (绿色→低血变红 15号)
  击杀: 0  (小恶魔)             (黄色14号)
  手枪                          (灰色15号)
  8 / 50                        (白色22号大字)
  换弹中...                     (橙色14号，隐藏)
```

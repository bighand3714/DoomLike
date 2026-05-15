# DoomLike - Godot 4.6 DOOM风格FPS游戏

## 项目概览

Godot 4.6 项目，正在构建一款DOOM风格的第一人称射击游戏。当前处于**Roadmap 2 Phase 8 已完成**——铁鞭左手武器（右键挥鞭/眩晕/拉取/抓取/盾牌/处决），枪械叠加眩晕值，武器→敌人→HUD 完整链路。已知问题：敌人头顶调试血条/眩晕条显示为深色（CSGBox3D 在无直接光照下材质偏暗）。下一步 Phase 9：整合、平衡与验证。

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
    whip_data.gd        WhipData Resource（铁鞭参数：伤害/眩晕/击退/拉取/抓取/处决）
    iron_whip.gd        铁鞭（右键挥鞭 → 眩晕满拉取 → 抓取 → 盾牌 → 处决）
  damage/           伤害系统
    damageable.gd      可受伤接口（血量/护甲/减伤/重置/治疗信号）
    shooting_target.gd 射击靶子（测试用，自动创建Damageable）
  enemy/            敌人系统（Phase 5 扩展 + Phase 6 八类敌人）
    enemy_data.gd      EnemyData Resource（20+字段：生命/速度/AI/眩晕/重量/飞行/模型颜色）
    enemy.gd           Enemy 基类（10状态机：IDLE→CHASE→ATTACK三段式→PAIN→STUNNED→DEATH等）
    projectile.gd      投射物基类（Area3D，飞行/碰撞/伤害/火球外观）
    imp.gd             小恶魔（远程火球投射物 + 近战爪击，CSG人形模型）
    demon_soldier.gd   恶魔士兵（hitscan射击 + 举枪前摇+有效性检查，装甲外观）
    ground_enemy.gd        近战恶魔（红色小体型，MELEE）
    advanced_ground_enemy.gd 高阶近战恶魔（暗红中体型，更快更硬）
    elite_ground_enemy.gd   精英恶魔（紫色大体型，高血量高重量）
    ranged_enemy.gd         远程恶魔（蓝色瘦长，PROJECTILE投射物）
    advanced_ranged_enemy.gd 高阶远程恶魔（深蓝，双管枪）
    flying_enemy.gd         飞行恶魔（黄色小体型，悬浮近战）
    advanced_flying_enemy.gd 高阶飞行恶魔（橙色中体型，高速高抗性）
    flying_ranged_enemy.gd   飞行远程恶魔（青色，空中投射物）
    enemy_manager.gd   敌人生成与管理（enemy_killed信号携带score_value）
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
  enemies/           imp.tscn, demon_soldier.tscn + 8 Phase 6 .tscn
  levels/            关卡场景
    desert_arena.tscn 荒漠竞技场（挂 ArenaLevel，arena_radius=45，72边界柱）
    lava_arena.tscn   熔岩地狱（挂 ArenaLevel，arena_radius=45，72边界柱）
  ui/                UI场景（当前均为代码创建，无 .tscn 文件）
assets/         游戏资源
  weapons/          WeaponData .tres（pistol.tres, shotgun.tres）+ iron_whip.tres
  enemies/          EnemyData .tres（imp.tres, demon_soldier.tres + 8 Phase 6 .tres）
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
│   ├── LeftHandHolder (Node3D)        [%LeftHandHolder]
│   │   └── IronWhip (Node3D)          ← iron_whip.gd (右键铁鞭/眩晕/拉取/抓取/处决)
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
| `secondary_fire` | 鼠标右键 | 挥鞭 |
| `reload` | R | 换弹 / 抓取中处决 |
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
- **武器系统**：`WeaponData`(Resource) → `WeaponNode`(基类) → `WeaponManager`(栏位管理)。支持半自动/全自动/泵动式，`reset_ammo()` 和 `reset_all_weapons()` 用于关卡重启。枪械命中敌人时自动调用 `apply_stun(stun_damage)` 叠加眩晕值。
- **铁鞭系统（Phase 8）**：`IronWhip` 挂 `LeftHandHolder` 下（`WhipData` 参数驱动）。右键射线检测（3m 近战范围）→ 命中敌人（伤害+40眩晕+击退），眩晕满自动进入拉取流程 → 到达抓取距离 `start_grab()` → 固定在前方 → 玩家移速按敌人 weight 降低 → R 键处决（敌人 `execute()` + 25 加分）。抓取中敌人作为盾牌：hitscan/melee 来自正面（`to_enemy.dot(player_forward) > 0.35`）由被抓敌人 Damageable 承受伤害，HUD 显示"盾牌抵挡!"。
- **伤害系统**：`Damageable` 接口（血量/护甲/减伤），护甲吸收 50% 伤害（经典 DOOM 规则），`reset()` 恢复到满血满护甲。
- **敌人系统（Phase 5+6）**：`Enemy` 基类 10 状态机（SPAWNING/IDLE/CHASE/ATTACK/PAIN/STUNNED/GRABBED/EXECUTED/DEATH），攻击采用三段式 windup→damage→recovery。眩晕系统（累积→满→STUNNED→可抓取窗口→自动恢复）、击退系统（weight/knockback_resistance 衰减）、抓取接口（can_be_grabbed/start_grab/execute）。头顶 CSGBox3D 调试条（血条+眩晕条）。`EnemyManager` 的 enemy_killed 信号携带 score_value，计分链路接入 RunStats。Phase 6 新增通用攻击系统：基类 `_execute_attack()` 根据 `enemy_data.damage_type` 自动分发 MELEE（近战距离判定）/ HITSCAN（射线命中检测）/ PROJECTILE（生成飞行投射物）。飞行敌人支持：`is_flying=true` 时 `_state_chase()` 自动调整 Y 轴悬浮高度（`hover_height` + `vertical_move_speed`）。八类敌人脚本仅覆写 `_setup_model()` 创建差异化 CSG 占位模型，核心行为由 EnemyData 参数驱动。
- **战斗HUD**：生命条（绿→橙→红+闪烁）、护甲（蓝色）、击杀（黄色）、武器栏位、命中标记、受伤闪红、拾取通知、分数/时间/强度（左上角，从 RunStats 读取）、边界警告（屏幕中下，橙红色大字，1.5秒自动消失）、抓取状态（"抓取中: <敌人名> [R处决]"）、盾牌抵挡通知（蓝色，0.8秒自动消失）
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
| `stun_damage` | 8.0 | 5.0 | 每颗弹丸眩晕值（铁鞭 40.0，见 WhipData） |

## 铁鞭参数（whip_data.gd / WhipData Resource）

| 属性 | 默认值 | 说明 |
|------|--------|------|
| `damage` | 8.0 | 挥鞭基础伤害 |
| `stun_damage` | 40.0 | 眩晕值（远高于枪械） |
| `knockback_force` | 15.0 | 击退力度 |
| `whip_range` | 3.0m | 鞭子最大距离（近战范围） |
| `cooldown` | 0.8s | 挥鞭冷却 |
| `pull_speed` | 12.0m/s | 拉取眩晕敌人速度 |
| `grab_distance` | 1.5m | 拉取到多近自动抓取 |
| `execution_damage` | 999.0 | 处决伤害（一击必杀） |
| `execution_score_bonus` | 25 | 处决额外分数 |

## 敌人参数（enemy_data.gd / EnemyData Resource）

### 旧有敌人（Imp / DemonSoldier）

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

### Phase 6 新增敌人

| 属性 | 近战恶魔 | 高阶近战 | 精英恶魔 | 远程恶魔 | 高阶远程 | 飞行恶魔 | 高阶飞行 | 飞行远程 |
|------|---------|---------|---------|---------|---------|---------|---------|---------|
| `max_health` | 60 | 100 | 250 | 50 | 80 | 40 | 70 | 50 |
| `attack_damage` | 12 | 18 | 30 | 10 | 14 | 10 | 16 | 8 |
| `damage_type` | MELEE(3) | MELEE(3) | MELEE(3) | PROJECTILE(1) | PROJECTILE(1) | MELEE(3) | MELEE(3) | PROJECTILE(1) |
| `score_value` | 10 | 20 | 50 | 15 | 25 | 15 | 30 | 25 |
| `spawn_cost` | 1 | 2 | 4 | 2 | 3 | 2 | 3 | 3 |
| `weight` | 1.0 | 1.5 | 3.0 | 0.8 | 1.2 | 0.5 | 1.0 | 0.7 |
| `move_speed` | 4.0 | 5.5 | 3.0 | 3.0 | 3.5 | 6.0 | 7.5 | 5.0 |
| `is_flying` | N | N | N | N | N | Y | Y | Y |
| `model_color` | 红 | 暗红 | 紫 | 蓝 | 深蓝 | 黄 | 橙 | 青 |

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

## 铁鞭抓取/盾牌/处决流程（Phase 8）

```
右键(挥鞭) → 射线检测(3m)
  → 命中敌人：伤害 8 + 眩晕 40 + 击退 15
  → 命中眩晕满敌人(can_be_grabbed=true) → 拉取流程
    → 每帧 pull_speed 移向玩家前方 grab_distance
    → 到达 < grab_distance*1.2 → start_grab(player)
      → 敌人 collision_layer=0，固定在玩家前方
      → 玩家移速 *= 1/(1+weight*0.35)（clamp 0.25-1.0）
      → HUD 显示"抓取中: <敌人名> [R处决]"

抓取中 R 键 → _execute_grabbed()
  → enemy.execute()（health=0, died信号）
  → 加分 execution_score_bonus(25)
  → HUD 通知"处决 +25"
  → 恢复移速，清除抓取状态

盾牌抵挡（自动）：
  enemy hitscan/melee → _damage_player()
    → 检测 player.grabbed_enemy != null
    → 攻击来自玩家正面(to_enemy⋅player_forward > 0.35)
    → 伤害重定向到 grabbed_enemy.Damageable
    → HUD 显示"盾牌抵挡!"(0.8s)

enemy projectile → _on_body_entered(player)
  → 同样检测 player.grabbed_enemy
  → 重定向伤害到被抓敌人
  → queue_free() + shield_block HUD
```

## 已知问题

- **敌人头顶调试条偏暗**：CSGBox3D 血条/眩晕条在无直接光照方向下材质显示为深色（近乎黑色）。根因是 CSGBox3D 用 StandardMaterial3D 且场景光照仅来自上方 DirectionalLight，条体侧面和底部无环境光补偿。待 Phase 9 集中修复（可能的方案：用 Sprite3D 替代 / 加 emission / 或等正式美术资源时一并替换）。

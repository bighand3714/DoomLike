# DoomLike - Godot 4.6 DOOM风格FPS游戏

## 项目概览

Godot 4.6 项目，DOOM风格第一人称射击游戏。**Roadmap 4 已完成**——输入重映射（滚轮铁链/右键瞄准/Shift冲刺/F处决）、Counter系统（攻击中受击→眩晕大幅上涨+青蓝闪白）、敌人护甲+15状态机+五档距离判定、铁链护甲免疫+倒地机制、兽人近战敌人（持斧+圆盾）、波次刷怪系统、受击方向指示器/小地图/距离环/准星变色。

- **引擎**：Godot 4.6 (Forward Plus, D3D12)
- **物理**：Jolt Physics
- **主场景**：`res://scenes/main.tscn`
- **窗口**：1280×720
- **权限**：`permissions.defaultMode: bypassPermissions`，零确认操作

## 目录结构（Roadmap 4 更新）

```
scripts/
  main.gd           主游戏控制器（关卡管线/状态机/X字准星/Counter提示/UI组件实例化）
  core/
    game_state.gd     GameState 枚举
    run_stats.gd      当前局统计
    save_data.gd      ConfigFile 存档管理
    game_bus.gd       GameBus Autoload（信号总线：counter_triggered/wave_started/play_sfx等10信号）
  player/
    player_controller.gd  第一人称控制（WASD/跳跃/冲刺/Shift冲刺/右键ADS/屏幕震动/距离环）
  ui/
    player_status.gd         战斗HUD（生命/护甲/武器栏/弹药/波次通知/Counter提示）
    hit_direction_indicator.gd  受击方向指示器（屏幕边缘红箭头，1s渐隐）
    minimap.gd                  小地图（150×150圆形，玩家绿点+敌人红点+朝向箭头）
    main_menu.gd / pause_menu.gd / level_select.gd / game_over_screen.gd
  weapon/
    weapon_data.gd     WeaponData Resource
    weapon_node.gd     武器基类（hitscan/melee/弹道线/伤害数字/击退/眩晕）
    weapon_manager.gd  4槽位管理（数字键切换，滚轮不再切武器）
    rifle.gd / shotgun.gd / pistol.gd / fist.gd
    whip_data.gd        WhipData Resource（+whip_length + 18字段）
    iron_whip.gd        铁鞭（滚轮触发，7状态机：IDLE→WHIPPING→PULLING→GRABBING→SHIELDING→THROWING→DASHING）
  damage/
    damageable.gd      可受伤接口（玩家50%护甲吸收，敌人护甲在Enemy中处理）
    shooting_target.gd
  enemy/
    enemy_data.gd       EnemyData Resource（30+字段：armor/height/shield_block_chance/can_defend/detection_interval）
    enemy.gd            Enemy 基类（15状态，Counter系统，DistanceBracket五档距离，AI检测计时器，knock_down/snare/mark）
    orc_enemy.gd        兽人战士（持斧+圆盾，三段近战攻击，举盾防御，5档AI策略）
    standard_enemy.gd   标准敌人（跳跃攻击三段式，Counter信号发射）
    ground_enemy.gd / advanced_ground_enemy.gd / elite_ground_enemy.gd
    ranged_enemy.gd / advanced_ranged_enemy.gd
    flying_enemy.gd / advanced_flying_enemy.gd / flying_ranged_enemy.gd
    imp.gd / demon_soldier.gd / projectile.gd
    spawn_manager.gd    刷怪管理器（连续刷怪+波次模式，强度曲线，预警指示器）
    wave_data.gd        波次配置资源（wave_number/enemy_entries/spawn_interval/rest_time）
    enemy_manager.gd    敌人生成与管理
  pickup/
    pickup.gd / health_pickup.gd / armor_pickup.gd / ammo_pickup.gd / drop_manager.gd
  level/
    level_registry.gd / arena_level.gd / arena_randomizer.gd
    desert_arena.gd / lava_arena.gd / test_arena.gd
    props/  hazards/
  utils/            FPS计数器
scenes/
  main.tscn
  player/  player.tscn  player_model.tscn
  enemies/ imp.tscn, demon_soldier.tscn + 8 .tscn + standard_enemy.tscn + orc_enemy.tscn
  levels/  desert_arena.tscn / lava_arena.tscn / test_arena.tscn
  ui/      UI场景（代码创建）
assets/
  weapons/   pistol.tres, shotgun.tres, rifle.tres, fist.tres, iron_whip.tres
  enemies/   imp.tres, demon_soldier.tres + 8 .tres + standard_enemy.tres + orc_melee.tres
  audio/fonts/textures （空）
```

## 场景树结构

```
Main (Node3D)                              ← main.gd
├── Player (CharacterBody3D)               ← player_controller.gd [%Player]
│   ├── Damageable                         (100HP/100护甲, reset())
│   ├── Camera3D                           [%Camera3D]
│   ├── CollisionShape3D                   (胶囊体: 半径0.4, 高1.8)
│   ├── 距离环×3 (MeshInstance3D)          红0.5m/黄1.0m/绿2.0m
│   ├── LeftHandHolder (Node3D)            [%LeftHandHolder]
│   │   └── IronWhip (Node3D)              ← iron_whip.gd (滚轮触发，F处决)
│   └── WeaponHolder (Node3D)
│       └── WeaponManager (Node3D)         ← weapon_manager.gd (4槽位，数字键切换)
│           ├── Rifle / Shotgun / Pistol / Fist (WeaponNode)
├── Level (Node3D)                         [%Level]
│   └── ArenaLevel
│       ├── WorldEnvironment / GeometryRoot / BoundaryRoot
│       ├── PropsRoot / HazardsRoot / SpawnRoot
│       └── SpawnManager                   ← spawn_manager.gd (连续/波次双模式)
├── UI (CanvasLayer)
│   ├── Crosshair (ColorRect)              [%Crosshair] + X字命中 + 蓝/绿变色
│   ├── DamageFlash / PlayerStatus / FPS
│   ├── HitDirectionIndicator              ← hit_direction_indicator.gd
│   ├── Minimap                            ← minimap.gd
│   └── MainMenu / PauseMenu / LevelSelect / GameOverScreen
└── DropManager (Node)
```

## 输入映射（Roadmap 4 更新）

| 按键 | 动作名 | 功能 |
|------|--------|------|
| `W` `A` `S` `D` | `move_*` | 移动 |
| 鼠标 | `look` | 控制镜头 |
| 鼠标左键 | `primary_fire` | 主武器攻击（开枪/近战） |
| 鼠标右键 | `aim`（原`secondary_fire`） | 自动瞄准ADS（按住降低灵敏度） |
| 滚轮向上 | `whip_throw` | 铁链攻击/甩出 |
| 滚轮向下 | `whip_throw` | 铁链攻击/冲刺处决 |
| Left Shift | `dash_sprint` | 冲刺（按住×1.6移速，配合WASD四方向） |
| `1` `2` `3` `4` | `weapon_1~4` | 武器槽切换 |
| `R` | `reload` | 换弹 |
| `F` | `action_key` | 处决（抓取中）/ 副武器 |
| Space | `jump` | 跳跃 |
| `Esc` | `ui_cancel` | 暂停 |

## Counter 系统（Roadmap 4 新增）

- **规则**：敌人处于ATTACK/ATTACK_PREPARE/ATTACK_ACTIVE/ATTACK_RECOVER状态时受击 → 眩晕2倍上涨 + 青蓝色闪白 + HUD "Counter!" + 打断攻击动作
- **信号**：`GameBus.counter_triggered.emit(enemy, position)`
- **标准敌人**：跳跃攻击全阶段可Counter，空中击退×1.5，Recovery额外眩晕×1.5
- **兽人敌人**：1s前摇提供充足Counter窗口

## 敌人系统（Roadmap 4 更新）

### 15状态机
`SPAWNING, IDLE, CHASE, ATTACK, WALKING, RUNNING, ATTACK_PREPARE, ATTACK_ACTIVE, ATTACK_RECOVER, DEFENDING, PAIN, STUNNED, GRABBED, KNOCKED_DOWN, EXECUTED, DEATH`

### 五档距离判定（DistanceBracket）
`MELEE(<0.5m) / CLOSE(0.5~1m) / MEDIUM(1~2m) / FAR(2~5m) / SUPER_FAR(>5m)`

### 敌人护甲
- 1护甲=吸收1伤害（与玩家50%吸收不同），在`Enemy._on_damaged()`中处理
- 有护甲敌人免疫铁链伤害和眩晕（铁链可削减护甲）

### AI检测计时器
- 每`detection_interval`秒执行一次`_ai_tick()`（虚方法），而非每帧

### 新增敌方可调用方法
- `knock_down()` / `is_knocked_down()` — 倒地/起身
- `apply_snare(duration)` — 定身
- `apply_damage_mark(duration, multiplier)` — 增伤标记

## 兽人战士（Roadmap 4 新增）

| 属性 | 值 | 说明 |
|------|-----|------|
| 血量/眩晕/护甲 | 100/100/100 | 中等肉盾 |
| 攻击伤害/触发距离 | 25/1m | 近战斧劈 |
| 前摇/判定/后摇 | 1s/0.1s/0.5s | Counter窗口充裕 |
| 攻击框 | 0.5m³ | Area3D，右手前方 |
| 防御 | 举盾扣护甲 | 中/近距离40%概率 |
| 模型 | CSG组合 | 圆柱身+球头+斧+圆盾 |

## 铁鞭连招（Roadmap 4 更新）

```
滚轮(铁链) → 命中眩晕敌人 → 抓取
  抓取中：
    ├─ 右键 → 盾牌模式（敌人在正前方抵挡攻击）
    │    ├─ 滚轮向下 → 冲刺处决（前方AOE+击退倒地）
    │    └─ 滚轮向上 → 甩出（敌人飞出+沿途倒地）
    ├─ F键 → 处决（999伤害+加分）
    └─ 甩出/冲刺后敌人进入KNOCKED_DOWN状态
```

## 波次刷怪（Roadmap 5 新增）

- `WaveData` Resource：wave_number / enemy_entries / spawn_interval / rest_time
- SpawnManager 双模式：连续刷怪（原行为）+ 波次模式（wave_mode=true）
- 波间等待场上敌人清零 + rest_time → GameBus.wave_started → HUD "第N波"

## 新增信号（GameBus）

- `counter_triggered(enemy: Enemy, position: Vector3)` — Roadmap 4
- `wave_started(wave_number: int)` — Roadmap 4

## 编码约定

- 注释使用**中文**
- 类名/枚举：`PascalCase`，变量/函数：`snake_case`，私有成员：`_前缀`
- 使用 `@export` 暴露可调参数到编辑器
- 使用 `%UniqueName` 引用场景节点
- 类型注解：`func _ready() -> void`、`var speed: float = 8.0`
- 优先使用显式类型标注（`var x: float = 1.0`），避免 `:=` 导致的类型推断警告

## 已知问题

- **敌人头顶调试条偏暗**：CSGBox3D 血条/眩晕条在无直接光照下材质偏暗
- **Godot MCP validate_script 误报**：大量脚本报 line 0 语法错，但 analyze_script 和实际运行均正常。是 MCP 验证器的 bug，非代码问题
- **drop_manager.gd**：创建在 Main 节点下而非 Level 下，关卡卸载时需手动 queue_free
- **兽人眩晕条初始化**：已加 `_ready()` 显式重置 `_stun=0` 和除零守卫，但编辑器场景序列化可能导致残留值，需关注

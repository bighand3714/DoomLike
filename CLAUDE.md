# DoomLike - Godot 4.6 DOOM风格FPS游戏

## 项目概览

Godot 4.6 项目，DOOM风格第一人称射击游戏。**Roadmap 5 进行中**——局内成长系统（经验/升级/三选一卡片/12种升级）、硬锁定系统（右键ADS自动追踪）、20级难度曲线（12种敌人分阶入池）、手柄支持（InputMap+触摸按钮）、多平台导出（PC/Android/Web）、开发者启动画面、昼夜循环（第二关）、投掷系统重做（镜头方向+体重伤害+3m球体判定）。

- **引擎**：Godot 4.6 (Forward Plus, D3D12)
- **物理**：Jolt Physics
- **主场景**：`res://scenes/main.tscn`
- **窗口**：1280×720
- **权限**：`permissions.defaultMode: bypassPermissions`，零确认操作

## 目录结构（Roadmap 5 更新）

```
scripts/
  main.gd           主游戏控制器（7状态机/升级管线/硬锁/威胁指示器/启动画面）
  core/
    game_state.gd     GameState 枚举（7状态：BOOT/MAIN_MENU/LEVEL_SELECT/PLAYING/PAUSED/GAME_OVER/LEVEL_UP）
    run_stats.gd      当前局统计
    save_data.gd      ConfigFile 存档管理
    game_bus.gd       GameBus Autoload（14信号+共享数据引用）
    version.gd        版本号
  player/
    player_controller.gd  第一人称控制（WASD/跳跃/冲刺/右键硬锁/屏幕震动/距离环/升级修饰符）
  ui/
    player_status.gd         战斗HUD（生命/护甲/武器栏/弹药/波次通知/Counter提示/经验条）
    hit_direction_indicator.gd  威胁指示器（3m内灰箭头+受击红箭头）
    minimap.gd                  小地图（150×150圆形，玩家绿点+敌人红点+朝向箭头，25m红圈范围）
    main_menu.gd / pause_menu.gd / level_select.gd / game_over_screen.gd
    level_up_panel.gd          升级三选一卡片面板（手柄导航支持）
  weapon/
    weapon_data.gd     WeaponData Resource
    weapon_node.gd     武器基类（hitscan/melee/弹道线/伤害数字/击退/眩晕）
    weapon_manager.gd  4槽位管理（数字键切换，滚轮不再切武器）
    rifle.gd / shotgun.gd / pistol.gd / fist.gd
    whip_data.gd        WhipData Resource（whip_range/cooldown/stun_damage等18字段）
    iron_whip.gd        铁鞭（滚轮触发，6状态机：IDLE→WHIPPING→PULLING→GRABBING→SHIELDING→DASHING）
  damage/
    damageable.gd      可受伤接口（玩家50%护甲吸收，敌人护甲在Enemy中处理）
    shooting_target.gd
  enemy/
    enemy_data.gd       EnemyData Resource（30+字段：armor/height/shield_block_chance/can_defend/detection_interval）
    enemy.gd            Enemy 基类（16状态，Counter系统，DistanceBracket五档距离，AI检测计时器，knock_down/snare/mark）
    orc_enemy.gd        兽人战士（持斧+圆盾，三段近战攻击，举盾防御，5档AI策略）
    standard_enemy.gd   标准敌人（跳跃攻击三段式，Counter信号发射）
    ground_enemy.gd / advanced_ground_enemy.gd / elite_ground_enemy.gd
    ranged_enemy.gd / advanced_ranged_enemy.gd
    flying_enemy.gd / advanced_flying_enemy.gd / flying_ranged_enemy.gd
    imp.gd / demon_soldier.gd / projectile.gd
    spawn_manager.gd    刷怪管理器（20级强度曲线连续刷怪，12种敌人分阶入池，预警指示器）
    wave_data.gd        波次配置资源（保留但未使用，系统已切换为强度曲线模式）
    enemy_manager.gd    敌人生成与管理
  pickup/
    pickup.gd / health_pickup.gd / armor_pickup.gd / ammo_pickup.gd / drop_manager.gd
  level/
    level_registry.gd / arena_level.gd / arena_randomizer.gd
    desert_arena.gd / lava_arena.gd / test_arena.gd
    cycle_sun.gd        昼夜循环（第二关：东升西落，白天2分钟/夜晚40秒）
    props/  hazards/
  progression/          局内成长系统
    player_progression.gd  经验/等级/三选一/战力评分
    upgrade_data.gd        UpgradeData Resource（id/名称/描述/图标/数值/操作类型/最大等级）
    upgrade_catalog.gd     加权随机升级池（12种升级，稀有度权重）
  platform/             多平台适配
    platform_detector.gd / ui_scaler.gd / web_export_compat.gd
    touch_input.gd / touch_button_painter.gd
  build/               构建脚本
    build_all.ps1
  utils/            FPS计数器
scenes/
  main.tscn
  player/  player.tscn  player_model.tscn
  enemies/ ground_enemy.tscn, advanced_ground_enemy.tscn, elite_ground_enemy.tscn,
           ranged_enemy.tscn, advanced_ranged_enemy.tscn,
           flying_enemy.tscn, advanced_flying_enemy.tscn, flying_ranged_enemy.tscn,
           standard_enemy.tscn, orc_enemy.tscn, imp.tscn, demon_soldier.tscn
  levels/  desert_arena.tscn / lava_arena.tscn / test_arena.tscn
  ui/      main_menu.tscn / level_select.tscn / game_over_screen.tscn
  props/   dead_tree_prop.tscn / rock_column_prop.tscn
  hazards/ lava_river.tscn
assets/
  weapons/   pistol.tres, shotgun.tres, rifle.tres, fist.tres, iron_whip.tres
  enemies/   ground_enemy.tres, advanced_ground_enemy.tres, elite_ground_enemy.tres,
             ranged_enemy.tres, advanced_ranged_enemy.tres,
             flying_enemy.tres, advanced_flying_enemy.tres, flying_ranged_enemy.tres,
             standard_enemy.tres, imp.tres, demon_soldier.tres, orc_melee.tres
             orc_axe_material.tres, orc_horn_material.tres, orc_material.tres, orc_shield_material.tres
  upgrades/  ammo_loot.tres, drop_abundance.tres, health_loot.tres,
             max_armor.tres, max_health.tres, move_speed.tres,
             reload_speed.tres, rifle_damage.tres, shotgun_damage.tres,
             whip_cooldown.tres, whip_range.tres, whip_stun.tres
  materials/ player_body.tres, player_skin.tres, player_hair.tres 等11个玩家材质
  title/     title.png（开发者启动画面）
  audio/fonts/textures （空）
```

## 场景树结构

```
Main (Node3D)                              ← main.gd
├── Player (CharacterBody3D)               ← player_controller.gd [%Player]
│   ├── Damageable                         (100HP/100护甲, reset())
│   ├── Camera3D                           [%Camera3D]
│   ├── CollisionShape3D                   (胶囊体: 半径0.4, 高1.8)
│   ├── 距离环×3 (MeshInstance3D)          绿3m/黄8m/红25m (TorusMesh贴地)
│   ├── LeftHandHolder (Node3D)            [%LeftHandHolder]
│   │   └── IronWhip (Node3D)              ← iron_whip.gd (滚轮触发，F处决)
│   └── WeaponHolder (Node3D)
│       └── WeaponManager (Node3D)         ← weapon_manager.gd (4槽位，数字键切换)
│           ├── Rifle / Shotgun / Pistol / Fist (WeaponNode)
├── Level (Node3D)                         [%Level]
│   └── ArenaLevel
│       ├── WorldEnvironment / GeometryRoot / BoundaryRoot
│       ├── PropsRoot / HazardsRoot / SpawnRoot
│       ├── CycleSun (第二关)              ← cycle_sun.gd
│       └── SpawnManager                   ← spawn_manager.gd（20级强度曲线连续刷怪）
├── UI (CanvasLayer)
│   ├── Crosshair (ColorRect)              [%Crosshair] + X字命中 + 蓝/绿变色
│   ├── DamageFlash / PlayerStatus / FPS
│   ├── HitDirectionIndicator              ← hit_direction_indicator.gd（近身灰箭头+受击红箭头）
│   ├── Minimap                            ← minimap.gd（25m红圈范围）
│   ├── LevelUpPanel                       ← level_up_panel.gd（三选一卡片）
│   └── MainMenu / PauseMenu / LevelSelect / GameOverScreen
├── PlayerProgression (Node)               ← player_progression.gd
└── DropManager (Node)
```

## 游戏状态流转

```
BOOT → MAIN_MENU → LEVEL_SELECT → PLAYING ⇄ PAUSED
         ↑              ↑              ↓       ↓
         └──────←───────┘         GAME_OVER  LEVEL_UP → PLAYING
                                  (玩家死亡)   (三选一后恢复)
```

## 输入映射（Roadmap 5 更新）

| 按键 | 动作名 | 功能 |
|------|--------|------|
| `W` `A` `S` `D` | `move_*` | 移动 |
| 鼠标 | `look` | 控制镜头 |
| 鼠标左键 | `primary_fire` | 主武器攻击（开枪/近战） |
| 鼠标右键 | `aim`（原`secondary_fire`） | 硬锁定ADS（按住自动追踪最近敌人，50m/20°FOV） |
| 滚轮向上 | `whip_throw` | 铁链攻击（IDLE→WHIPPING）/ SHIELDING时→冲刺处决 |
| 滚轮向下 | `whip_throw` | 同上（SHIELDING时→冲刺处决） |
| Left Shift | `dash_sprint` | 冲刺（按住×1.6移速，配合WASD四方向） |
| `1` `2` `3` `4` | `weapon_1~4` | 武器槽切换 |
| `R` | `reload` | 换弹 |
| `F` | `action_key` | 处决（抓取/盾牌中）/ 副武器 |
| Space | `jump` | 跳跃 |
| `Esc` | `ui_cancel` | 暂停 |
| 手柄B | `ui_cancel` | UI返回（main.gd集中化处理） |

## Counter 系统

- **规则**：敌人处于ATTACK/ATTACK_PREPARE/ATTACK_ACTIVE/ATTACK_RECOVER状态时受击 → 眩晕2倍上涨 + 青蓝色闪白 + HUD "Counter!" + 打断攻击动作
- **信号**：`GameBus.counter_triggered.emit(enemy, position)`
- **标准敌人**：跳跃攻击全阶段可Counter，空中击退×1.5，Recovery额外眩晕×1.5
- **兽人敌人**：1s前摇提供充足Counter窗口

## 敌人系统

### 16状态机
`SPAWNING, IDLE, CHASE, ATTACK, WALKING, RUNNING, ATTACK_PREPARE, ATTACK_ACTIVE, ATTACK_RECOVER, DEFENDING, PAIN, STUNNED, GRABBED, KNOCKED_DOWN, EXECUTED, DEATH`

### 五档距离判定（DistanceBracket）
`MELEE(<1m) / CLOSE(1~3m) / MEDIUM(3~8m) / FAR(8~25m) / SUPER_FAR(>25m)`

### 敌人护甲
- 1护甲=吸收1伤害（与玩家50%吸收不同），在`Enemy._on_damaged()`中处理
- 有护甲敌人免疫铁链伤害和眩晕（铁链可削减护甲，破甲越多眩晕比例越高30%~100%）

### AI检测计时器
- 每`detection_interval`秒执行一次`_ai_tick()`（虚方法），而非每帧

### 敌方可调用方法
- `knock_down()` / `is_knocked_down()` — 倒地/起身
- `apply_snare(duration)` — 定身
- `apply_damage_mark(duration, multiplier)` — 增伤标记
- `deplete_armor(amount)` — 削减护甲，返回实际削减量
- `can_be_grabbed()` — 是否可被抓取
- `apply_stun(amount, force)` — 施加眩晕

## 刷怪系统（强度曲线模式）

**20级强度曲线**（时间驱动，0~536秒覆盖20分钟20级）：

| 强度等级 | 时间 | 刷怪间隔 | 活跃上限 | 波次预算 |
|---------|------|---------|---------|---------|
| 1 | 0s | 4.0s | 8 | 2 |
| 5 | 60s | 2.0s | 12 | 4 |
| 10 | 156s | 1.2s | 20 | 6 |
| 15 | 312s | 0.8s | 35 | 9 |
| 20 | 536s | 0.6s | 50 | 12 |

**12种敌人分阶入池**：ground(1) → standard(2) → ranged/orc(3) → flying(4) → imp(5) → adv_ground(7) → adv_ranged(8) → demon_soldier(9) → adv_flying(10) → flying_ranged(11) → elite_ground(13)

**关卡权重**：沙漠偏向地面/兽人（orc×2.5, ground×3），熔岩偏向飞行/远程（flying×2, ranged×2）

**刷怪预警**：1.2s橙红色光柱（CSGBox3D渐亮）在出生点 → 0.5s缩放动画生成

**移动端**活跃上限封顶15。

## 局内成长系统（Roadmap 5 新增）

### PlayerProgression
- 经验获取：击杀敌人 → `add_xp(xp_value)` → 满经验触发`level_up`信号
- 经验需求递增：`xp_to_next = 20 * level`
- 待升级队列：连续击杀可累积多次升级，逐一弹出

### 12种升级（UpgradeData）
| 升级ID | 效果 | 稀有度 | 最大等级 |
|--------|------|--------|---------|
| max_health | 最大生命+25 | Common | 5 |
| max_armor | 最大护甲+25 | Common | 5 |
| move_speed | 移动速度+8% | Common | 5 |
| whip_range | 铁链范围+1m | Common | 5 |
| whip_stun | 铁链眩晕+30% | Uncommon | 5 |
| whip_cooldown | 铁链冷却-15% | Uncommon | 5 |
| rifle_damage | 步枪伤害+20% | Uncommon | 5 |
| shotgun_damage | 霰弹伤害+20% | Uncommon | 5 |
| reload_speed | 换弹速度+15% | Uncommon | 5 |
| health_loot | 生命掉落+25% | Rare | 3 |
| ammo_loot | 弹药掉落+30% | Rare | 3 |
| drop_abundance | 掉落数量+20% | Rare | 3 |

### 升级修饰符分发
- **Player**：`apply_survival_upgrade()` → max_health/max_armor/move_speed_mult
- **IronWhip**：`apply_whip_upgrade()` → whip_range/cooldown/stun_damage
- **WeaponNode**：`apply_weapon_upgrade()` → damage_mult/reload_mult
- **DropManager**：`apply_drop_upgrade()` → health_chance/ammo_chance/abundance

### 暂停菜单技能显示
- PauseMenu 读取 `GameBus.player_progression.get_owned_upgrades()` 显示已拥有技能及等级

## 硬锁定系统（Roadmap 5 新增）

- 右键按住 → 自动搜索最近敌人（50m范围，20°半FOV锥形）
- 锁定后相机自动平滑追踪（`lock_tracking_speed: 20`）
- 红色Billboard锁定标记（0.6×0.6m）
- 自动解除：铁链忙碌/敌人死亡/距离<2m/手动松右键

## 兽人战士

| 属性 | 值 | 说明 |
|------|-----|------|
| 血量/眩晕/护甲 | 100/100/100 | 中等肉盾 |
| 攻击伤害/触发距离 | 25/1m | 近战斧劈 |
| 前摇/判定/后摇 | 1s/0.1s/0.5s | Counter窗口充裕 |
| 攻击框 | 0.5m³ | Area3D，右手前方 |
| 防御 | 举盾扣护甲 | 中/近距离40%概率 |
| 模型 | CSG组合 | 圆柱身+球头+斧+圆盾 |

## 铁鞭连招（Roadmap 5 更新）

```
IDLE → 滚轮 → WHIPPING（射线命中眩晕敌人→PULLING拉取→GRABBING抓取）
  抓取中（GRABBING）：
    ├─ 右键按住 → SHIELDING（敌人半透明，正前方格挡攻击）
    │    └─ 滚轮 → DASHING（冲刺处决：前方AOE+大伤害+击退倒地）
    ├─ 命中不可抓取敌人 → 击退
    └─ F键 → 处决（999伤害+加分）
```

## GameBus 信号（14个）

| 信号 | 参数 | 用途 |
|------|------|------|
| `pickup_notification` | `text, color` | 拾取提示 |
| `player_hit` | `amount` | 玩家受击 |
| `pause_toggle` | — | 暂停切换 |
| `shield_block` | — | 盾牌格挡 |
| `grab_status_show` | `enemy_name` | 显示抓取状态 |
| `grab_status_hide` | — | 隐藏抓取状态 |
| `enemy_death_position` | `position` | 敌人死亡位置 |
| `play_sfx` | `sfx_name, position` | 音效触发 |
| `counter_triggered` | `enemy, position` | Counter触发 |
| `wave_started` | `wave_number` | 波次开始（保留，未使用） |
| `xp_changed` | `level, xp, xp_to_next` | 经验变化 |
| `level_up` | `new_level, options` | 升级触发 |
| `upgrade_applied` | `upgrade_id, upgrade_level` | 升级应用 |
| `player_power_changed` | `power_score` | 战力评分变化 |

**共享数据引用**：`run_stats`, `save_data`, `last_attacker_position`, `player_progression`

## 昼夜循环（第二关熔岩地狱）

- CycleSun：太阳东升西落，白天2分钟/夜晚40秒循环
- 影响光照强度和颜色

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
- **兽人眩晕条初始化**：已加 `_ready()` 显式重置 `_stun=0` 和除零守卫，但编辑器场景序列化可能导致残留值
- **GameBus.wave_started 未使用**：信号已定义但 SpawnManager 不发射（系统已切换为强度曲线模式）

# DoomLike - Godot 4.6 DOOM风格FPS游戏

## 项目概览

Godot 4.6 项目，DOOM风格第一人称射击游戏。**Roadmap 3 已完成**——4槽位武器系统（步枪/霰弹枪双管/手枪无限/拳头近战），弹道线视效，X字准星命中反馈，铁鞭完整连招（举起→盾牌→甩出→冲刺处决），跳跃攻击标准敌人，掉落补给系统，圈外深度雾。已知问题：敌人头顶调试血条/眩晕条显示为深色（CSGBox3D 在无直接光照下材质偏暗）；Godot MCP validate_script 对项目大量误报 line 0 错（analyze_script 和实际运行均正常）。

- **引擎**：Godot 4.6 (Forward Plus, D3D12)
- **物理**：Jolt Physics
- **主场景**：`res://scenes/main.tscn`
- **窗口**：1280×720
- **权限**：`permissions.defaultMode: bypassPermissions`，零确认操作

## 目录结构（Roadmap 3 更新）

```
scripts/
  main.gd           主游戏控制器（关卡管线/状态机/X字准星/SFX占位/DropManager集成）
  core/
    game_state.gd     GameState 枚举（BOOT→MAIN_MENU→LEVEL_SELECT→PLAYING→PAUSED→GAME_OVER）
    run_stats.gd      当前局统计（分数/击杀/时间）
    save_data.gd      ConfigFile 存档管理（最高分/最长时间）
    game_bus.gd       GameBus Autoload（信号总线 + play_sfx/enemy_death_position + 共享数据引用）
  player/
    player_controller.gd  第一人称控制（WASD/跳跃/冲刺/屏幕震动/抓取减速）
  ui/
    player_status.gd    战斗HUD（生命条/护甲/武器栏/弹药/分数/时间/强度/抓取状态/盾牌通知/边界警告）
    main_menu.gd       主菜单
    pause_menu.gd      暂停菜单
    level_select.gd    选关界面（LevelRegistry 动态读取，含测试关卡）
    game_over_screen.gd 结算界面
  weapon/
    weapon_data.gd     WeaponData Resource（DamageType/FireMode + knockback_force/infinite_ammo/is_melee/melee_range）
    weapon_node.gd     武器基类（hitscan/melee双模式/弹道线/_spawn_damage_number/击退/眩晕/无限弹药）
    weapon_manager.gd  4槽位管理（1步枪/2霰弹枪/3手枪/4拳头 + 滚轮/数字键切换）
    rifle.gd           步枪（全自动8发/秒, 25弹匣, 80m, CSG长枪造型）
    shotgun.gd         双管猎枪（泵动式, 8弹丸, 14伤害, 木质枪身+双并排枪管）
    pistol.gd          手枪（半自动, 无限弹药保底, slot 3）
    fist.gd            拳头（近战2m, 无限, 前冲后座动画）
    whip_data.gd        WhipData Resource（+dash_*/throw_*参数）
    iron_whip.gd        铁鞭（IDLE→WHIPPING→PULLING→GRABBING→SHIELDING→THROWING→DASHING 7状态机）
  damage/
    damageable.gd      可受伤接口（血量/护甲/减伤/重置）
    shooting_target.gd 射击靶子
  enemy/
    enemy_data.gd       EnemyData Resource（20+字段）
    enemy.gd            Enemy 基类（10状态机, "enemy" group）
    projectile.gd       投射物基类
    imp.gd             小恶魔（火球+近战）
    demon_soldier.gd   恶魔士兵（hitscan）
    standard_enemy.gd   标准敌人（跳跃攻击三段式：下蹲→抛物线跳跃→落地）
    ground_enemy.gd / advanced_ground_enemy.gd / elite_ground_enemy.gd
    ranged_enemy.gd / advanced_ranged_enemy.gd
    flying_enemy.gd / advanced_flying_enemy.gd / flying_ranged_enemy.gd
    enemy_manager.gd    敌人生成与管理（enemy_killed + enemy_death_position 发射）
  pickup/
    pickup.gd          Pickup 基类（Area3D + 悬浮旋转）
    health_pickup.gd   血包
    armor_pickup.gd    护甲
    ammo_pickup.gd     弹药（智能跳过无限弹药武器）
    drop_manager.gd    掉落管理器（40%弹药/30%血/20%护甲/10%无, 弹起动画, 30秒消失）
  level/
    level_registry.gd   关卡注册表（荒漠/熔岩/测试 三关）
    arena_level.gd      竞技场基类（雾参数/环境雾WorldEnvironment/深度雾）
    arena_randomizer.gd 随机数工具类
    desert_arena.gd     荒漠竞技场（沙黄雾）
    lava_arena.gd       熔岩地狱（暗红雾）
    test_arena.gd       测试关卡（灰色雾, 手动放敌, 无自动刷怪）
    props/              枯树、岩柱
    hazards/            熔岩河流
  utils/            FPS计数器
scenes/
  main.tscn          主场景
  player/            player.tscn
  enemies/           imp.tscn, demon_soldier.tscn + 8 Phase 6 .tscn + standard_enemy.tscn
  levels/
    desert_arena.tscn  荒漠（radius=45, 72柱, 沙黄雾）
    lava_arena.tscn    熔岩（radius=45, 72柱, 暗红雾）
    test_arena.tscn    测试（radius=45, 72柱, 灰雾, PlayerStart圆心）
  ui/                UI场景（代码创建）
assets/
  weapons/           pistol.tres, shotgun.tres, rifle.tres, fist.tres, iron_whip.tres
  enemies/           imp.tres, demon_soldier.tres + 8 Phase 6 .tres + standard_enemy.tres
  audio/fonts/textures （空）
```

## 场景树结构

```
Main (Node3D)                              ← main.gd
├── Player (CharacterBody3D)               ← player_controller.gd [%Player]
│   ├── Damageable                         (100HP/100护甲, reset())
│   ├── Camera3D                           [%Camera3D]
│   ├── CollisionShape3D                   (胶囊体: 半径0.4, 高1.8)
│   ├── LeftHandHolder (Node3D)            [%LeftHandHolder]
│   │   └── IronWhip (Node3D)              ← iron_whip.gd (7状态机: 挥鞭→拉取→举起→盾牌→甩出→冲刺处决)
│   └── WeaponHolder (Node3D)
│       └── WeaponManager (Node3D)         ← weapon_manager.gd (4槽位)
│           ├── Rifle (WeaponNode)         ← rifle.gd (全自动, slot 1)
│           ├── Shotgun (WeaponNode)       ← shotgun.gd (双管泵动, slot 2)
│           ├── Pistol (WeaponNode)        ← pistol.gd (无限弹药, slot 3)
│           └── Fist (WeaponNode)          ← fist.gd (近战, slot 4)
├── Level (Node3D)                         [%Level]
│   └── DesertArena/LavaArena/TestArena (ArenaLevel)
│       ├── WorldEnvironment               ← 深度雾（_setup_fog）
│       ├── GeometryRoot                   地面
│       ├── BoundaryRoot                   72根边界柱
│       ├── PropsRoot                      道具
│       ├── HazardsRoot                    危险区
│       └── SpawnRoot                      刷怪点
├── UI (CanvasLayer)
│   ├── Crosshair (ColorRect)              [%Crosshair] + X字准星命中反馈
│   ├── DamageFlash (ColorRect)            [%DamageFlash]
│   ├── FPS / PlayerStatus                 战斗HUD
│   ├── MainMenu / PauseMenu / LevelSelect / GameOverScreen
└── DropManager (Node)                     ← drop_manager.gd（掉落补给）
```

## 输入映射（Roadmap 3 更新）

| 按键 | 功能 |
|------|------|
| `1` | 步枪（全自动、主力远程） |
| `2` | 霰弹枪（双管猎枪、中距离8弹丸） |
| `3` | 手枪（无限子弹、保底远程） |
| `4` | 拳头（无限、保底近战2m） |
| 鼠标左键 | 开枪/挥拳 |
| 鼠标右键 | 挥鞭 / 抓取中按住=盾牌模式 |
| `R` | 换弹 / 抓取中=处决 |
| 滚轮向上 | 下一把武器 |
| 滚轮向下 | 上一把武器 / 抓取中=甩出 / 盾牌模式=冲刺处决 |
| `WASD` | 移动 |
| `Space` | 跳跃 |
| `Esc` | 暂停 |

## 四把武器参数（Roadmap 3）

| 属性 | 步枪 | 霰弹枪 | 手枪 | 拳头 |
|------|------|--------|------|------|
| `slot` | 1 | 2 | 3 | 4 |
| `damage` | 10.0 | 14.0×8 | 18.0 | 12.0 |
| `max_range` | 80.0m | 20.0m | 60.0m | 2.0m |
| `fire_mode` | AUTO | PUMP | SEMI | SEMI |
| `fire_rate` | 8.0/s | 1.5/s | 1.8/s | 2.5/s |
| `mag/reserve` | 25/100 | 2/24 | 8/∞ | 1/∞ |
| `stun_damage` | 3.0 | 8.0×8 | 6.0 | 10.0 |
| `knockback` | 2.0 | 6.0 | 4.0 | 8.0 |
| `is_melee` | N | N | N | Y |

## 铁鞭参数（Roadmap 3 扩展）

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `damage` / `stun_damage` | 8.0 / 40.0 | 挥鞭伤害/眩晕 |
| `whip_range` / `cooldown` | 3.0m / 0.8s | 范围/冷却 |
| `pull_speed` / `grab_distance` | 12.0m/s / 1.5m | 拉取速度/抓取距离 |
| `execution_damage` / `execution_score_bonus` | 999.0 / 25 | 处决伤害/加分 |
| `dash_distance` / `dash_speed` | 5.0m / 25.0m/s | 冲刺距离/速度 |
| `dash_damage` / `dash_aoe_damage` | 60.0 / 30.0 | 冲刺伤害/AOE |
| `dash_grabbed_damage` | 150.0 | 对被抓起敌人的大伤害 |
| `throw_damage` / `throw_speed` | 35.0 / 35.0m/s | 甩出伤害/速度 |

## 铁鞭完整连招（Roadmap 3）

```
右键(挥鞭) → 射线3m → 伤害8+眩晕40+击退
  → 眩晕满(can_be_grabbed) → 拉取(pull_speed 12m/s)
    → 到达 grab_distance 1.5m → start_grab
      → 左手举起（scale缩小0.65, 移速降低）
      → 按住右键 → 盾牌模式（敌人居中1.5m, scale恢复）
        → 滚轮向下 → 冲刺处决（dash 5m, 被抓150伤害, AOE 30）
      → 松开右键 → 回到举起
      → 滚轮向下（举起模式）→ 甩出（throw_speed 35m/s, AOE 35）
      → R键 → 处决（999伤害, +25分）
```

## 标准敌人（Roadmap 3 新增）

| 属性 | 值 | 说明 |
|------|-----|------|
| `max_health` | 100 | 中等血量 |
| `attack_damage` | 20 | MELEE 跳跃攻击 |
| `attack_range` | 6.0m | 跳跃触发距离 |
| `attack_windup/duration/recovery` | 0.4/0.3/0.5s | 三段式 |
| **交互性** | | |
| Windup打断 | 受击→PAIN | 0.4s 反应窗口 |
| 空中击退增强 | ×1.5 | 可改变落点 |
| Recovery额外眩晕 | ×1.5 | 惩罚窗口 |

## 掉落补给系统（Roadmap 3 新增）

| 掉落物 | 概率 | 效果 |
|--------|------|------|
| 弹药 | 40% | 补充 10~20 发备弹 |
| 血包 | 30% | 恢复 15~25 HP |
| 护甲 | 20% | 恢复 15~25 护甲 |
| 无掉落 | 10% | |

- 掉落物弹起动画 + 30秒自动消失
- 弹药智能补充：跳过无限弹药武器（手枪/拳头）

## 圈外深度雾（Roadmap 3 新增）

- `ArenaLevel` 提供 `fog_enabled/density/start_distance` 导出参数
- `_setup_fog()` 创建 `WorldEnvironment` + `FOG_MODE_DEPTH`
- 三关雾颜色：荒漠沙黄 / 熔岩暗红 / 测试灰色

## 视觉增强（Roadmap 3 新增）

- **弹道线**：`_spawn_tracer()` 白色半透明细线，0.12s 消失
- **X字准星**：命中敌人显示红色交叉线（45°/-45°），0.12s 消失
- **伤害数字**：`_spawn_damage_number()` Label3D 飘升渐隐，普通白/眩晕蓝
- **屏幕震动**：`apply_screen_shake()` 受伤触发

## 新增信号（GameBus）

- `play_sfx(sfx_name, position)` — SFX 占位接口（当前 print 占位）
- `enemy_death_position(position)` — EnemyManager → DropManager 掉落触发

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

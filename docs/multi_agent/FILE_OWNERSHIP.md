# 文件所有权映射

## Agent 开发域划分

| 开发域 | Agent | 拥有的文件 |
|--------|-------|-----------|
| **Core** | agent-core | `scripts/main.gd`, `scripts/core/*`, `project.godot` |
| **Player+Combat** | agent-player | `scripts/player/*`, `scripts/damage/*` |
| **Weapons+Pickup** | agent-weapons | `scripts/weapon/*`, `scripts/pickup/*`, `assets/weapons/*` |
| **Enemies** | agent-enemies | `scripts/enemy/*`, `assets/enemies/*`, `scenes/enemies/*` |
| **Level** | agent-level | `scripts/level/*`, `scenes/levels/*`, `scenes/props/*`, `scenes/hazards/*` |
| **UI/HUD** | agent-ui | `scripts/ui/*`, `scenes/ui/*` |
| **Art** | agent-art | `scenes/**/*.tscn` (模型/材质), `shaders/`, `assets/` (textures) |
| **Audio** | agent-audio | `assets/audio/` |

## 瓶颈文件 (需协调锁定)

| 文件 | 原因 | 锁定规则 |
|------|------|---------|
| `scripts/enemy/enemy.gd` | 10 个敌人子类继承它 | Agent-Enemies 独占；修改公共签名需所有 agent 确认 |
| `scripts/weapon/weapon_data.gd` | `DamageType`/`FireMode` 枚举被 6+ 模块引用 | Agent-Weapons 管理；枚举追加需通知 Enemy/Level/Damage |
| `project.godot` | 输入映射 + Autoload 配置 | Agent-Core 管理 |
| `scripts/core/game_bus.gd` | 所有信号定义 | Agent-Core 管理；新增信号需审核 |
| `scripts/main.gd` | 状态机 + 关卡加载管线 | Agent-Core 独占 |
| `scripts/player/player_controller.gd` | `grabbed_enemy` 属性被 Enemy+IronWhip 使用 | Agent-Player 独占 |

## 只读规则

- `scripts/damage/damageable.gd` — Player+Combat 拥有；所有其他模块只能调用公共方法
- `scripts/core/game_state.gd` — Core 拥有；所有模块只读
- `scripts/level/level_registry.gd` — Level 拥有；UI/Core 只读
- 所有 `.tres` 资源文件 — Config 拥有；所有模块可读不可写

## .tscn 文件并行编辑规则

.tscn 是 Godot 生成的文本文件，格式脆弱，极易合并冲突：
- **绝对禁止**两个 agent 同时编辑同一个 .tscn 文件
- 优先通过脚本动态创建节点 (如 CSGBox3D) 而非在 .tscn 中手动摆放
- 必须在 .tscn 中修改时，先在 agent 群内声明锁定

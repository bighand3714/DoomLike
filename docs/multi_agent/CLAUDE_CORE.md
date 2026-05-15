# Agent-Core: 游戏核心

## 你拥有的文件

- `scripts/main.gd` — 状态机 + 关卡加载/卸载管线 + 全局信号路由
- `scripts/core/game_state.gd` — `GameState` 枚举
- `scripts/core/run_stats.gd` — `RunStats` (分数/击杀/时间)
- `scripts/core/save_data.gd` — `SaveData` (ConfigFile 存档)
- `scripts/core/game_bus.gd` — `GameBus` Autoload (所有模块间信号)
- `project.godot` — Autoload 配置 + 输入映射

## 你的公共接口

### GameBus 信号 (其他模块 emit, 你 connect)

```
pickup_notification(text, color)  ← ammo/health/armor pickup, iron_whip
player_hit(amount)                ← player_controller
pause_toggle()                    ← player_controller
shield_block()                    ← enemy.gd, projectile.gd
grab_status_show(enemy_name)      ← iron_whip
grab_status_hide()                ← iron_whip
```

### GameBus 共享数据 (你设置，其他模块读取)

```
GameBus.run_stats  — 在 _start_level() 中设置，_unload_current_level() 中置 null
GameBus.save_data  — 在 _ready() 中设置，持久有效
```

### main.gd 公共方法

- `toggle_pause()` — Esc 暂停/恢复
- `player_hit(amount)` — 屏幕闪红
- `show_pickup_notification(text, color)` — 转发到 HUD
- `get_run_stats()` → RunStats
- `get_save_data()` → SaveData
- `_start_level(level_id)` — 关卡加载管线入口

## 你依赖的其他模块接口

只读，不要修改：
- `docs/module_interfaces/WEAPONS.md` — WeaponManager/WeaponNode/WeaponData API
- `docs/module_interfaces/ENEMIES.md` — Enemy/EnemyManager/SpawnManager API
- `docs/module_interfaces/LEVEL.md` — ArenaLevel/LevelRegistry API
- `docs/module_interfaces/UI.md` — 菜单信号 + HUD API
- `docs/module_interfaces/PLAYER.md` — PlayerController/Damageable API

## 禁止事项

- 禁止在 main.gd 中访问其他模块的 `_` 前缀私有变量
- 禁止新增 `get_tree().root.get_node_or_null("Main")` 硬编码引用 (用 GameBus 替代)
- 修改 GameBus 信号签名前通知所有 agent
- project.godot 的输入映射变更需通知所有 agent

# Core 模块 — 游戏核心

## 概述

负责游戏状态机、关卡加载/卸载管线、全局信号路由、RunStats 驱动、存档管理。

## 所属文件

- `scripts/main.gd` — 状态机 + 关卡加载 + 信号中心
- `scripts/core/game_state.gd` — `GameState` 枚举 (BOOT→MAIN_MENU→LEVEL_SELECT→PLAYING→PAUSED→GAME_OVER)
- `scripts/core/run_stats.gd` — `RunStats` (分数/击杀/时间)
- `scripts/core/save_data.gd` — `SaveData` (ConfigFile 存档)
- `scripts/core/game_bus.gd` — `GameBus` Autoload

## 公共方法 (main.gd)

| 方法 | 说明 |
|------|------|
| `toggle_pause()` | Esc 切换暂停/恢复 |
| `player_hit(amount)` | 屏幕闪红效果 |
| `show_pickup_notification(text, color)` | 转发拾取通知到 HUD |
| `get_run_stats()` | 返回当前 RunStats |
| `get_save_data()` | 返回 SaveData |
| `_start_level(level_id)` | 启动关卡 |
| `_unload_current_level()` | 卸载关卡 |

## GameBus 信号连接

main.gd 在 `_ready()` 中连接所有 GameBus 信号：
- `pickup_notification` → `show_pickup_notification()`
- `player_hit` → `player_hit()`
- `pause_toggle` → `toggle_pause()`
- `shield_block` → `_on_shield_block()` → HUD
- `grab_status_show` → `_on_grab_status_show()` → HUD
- `grab_status_hide` → `_on_grab_status_hide()` → HUD

## 关卡加载链路

```
_level_selected(id) → _start_level(id)
  → _unload_current_level()
  → _load_arena_level(id) → PackedScene.instantiate
  → _reset_player_for_level()
  → _set_game_state(PLAYING)
```

## 依赖的其他模块

- UI (main_menu, pause_menu, level_select, game_over_screen)
- Level (ArenaLevel, LevelRegistry)
- Enemy (SpawnManager)
- Weapon (IronWhip, WhipData)

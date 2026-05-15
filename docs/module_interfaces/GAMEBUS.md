# GameBus — 模块间通信信号总线

## 概述

GameBus 是项目唯一的 Autoload 单例，只携带信号和共享数据引用，不包含游戏逻辑。

**使用模式：** `GameBus.signal_name.emit()` → main.gd 连接信号 → 转发到目标模块

## 公共信号

| 信号 | 参数 | 发射者 | 接收者 |
|------|------|--------|--------|
| `pickup_notification` | `text: String, color: Color` | ammo_pickup, health_pickup, armor_pickup, iron_whip | main.gd → HUD |
| `player_hit` | `amount: float` | player_controller | main.gd → 屏幕闪红 |
| `pause_toggle` | — | player_controller | main.gd → toggle_pause() |
| `shield_block` | — | enemy.gd, projectile.gd | main.gd → HUD "盾牌抵挡!" |
| `grab_status_show` | `enemy_name: String` | iron_whip | main.gd → HUD 抓取状态 |
| `grab_status_hide` | — | iron_whip | main.gd → HUD 隐藏抓取状态 |

## 共享数据引用

| 属性 | 类型 | 设置者 | 生命周期 |
|------|------|--------|---------|
| `run_stats` | `RunStats` | main.gd `_start_level()` | 关卡开始→卸载 |
| `save_data` | `SaveData` | main.gd `_ready()` | 应用全局 |

## 依赖

- `RunStats` (res://scripts/core/run_stats.gd)
- `SaveData` (res://scripts/core/save_data.gd)

## 所属文件

- `scripts/core/game_bus.gd`

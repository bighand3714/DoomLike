# UI 模块 — 用户界面

## 概述

菜单系统 (主菜单/暂停/选关/结算) + 战斗 HUD。

## 所属文件

- `scripts/ui/main_menu.gd` — 主菜单 (开始/退出)
- `scripts/ui/pause_menu.gd` — 暂停菜单 (继续/返回)
- `scripts/ui/level_select.gd` — 选关界面
- `scripts/ui/game_over_screen.gd` — 结算界面
- `scripts/ui/player_status.gd` — 战斗 HUD (生命/护甲/弹药/分数/时间/强度/边界警告)

## 公共方法 (PlayerStatus HUD)

| 方法 | 说明 |
|------|------|
| `reset_kill_count()` | 重置击杀计数 |
| `update_intensity(new_intensity)` | 更新难度等级 |
| `show_boundary_warning()` | 显示边界警告 |
| `show_notification(text, color)` | 拾取通知 |
| `show_shield_block()` | 盾牌抵挡通知 |
| `show_grab_status(enemy_name)` | 抓取状态显示 |
| `hide_grab_status()` | 隐藏抓取状态 |

### 信号 (菜单)

| 信号 | 发射者 |
|------|--------|
| `start_requested()` | MainMenu |
| `quit_requested()` | MainMenu |
| `resumed()` | PauseMenu |
| `back_to_menu()` | PauseMenu |
| `level_selected(level_id)` | LevelSelect |
| `back_requested()` | LevelSelect |
| `restart_requested()` | GameOverScreen |
| `level_select_requested()` | GameOverScreen |
| `main_menu_requested()` | GameOverScreen |

## 依赖的其他模块

- Core (GameBus.run_stats/save_data)
- Level (LevelRegistry)
- Weapon (WeaponManager 信号)
- Enemy (EnemyManager 信号)

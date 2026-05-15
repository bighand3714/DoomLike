# Agent-UI: 用户界面

## 你拥有的文件

- `scripts/ui/main_menu.gd` — 主菜单
- `scripts/ui/pause_menu.gd` — 暂停菜单
- `scripts/ui/level_select.gd` — 选关界面
- `scripts/ui/game_over_screen.gd` — 结算界面
- `scripts/ui/player_status.gd` — 战斗 HUD
- `scripts/utils/fps_counter.gd` — FPS 显示
- `scenes/ui/main_menu.tscn`, `level_select.tscn`, `game_over_screen.tscn`

## 你的公共接口

### 菜单信号 (由 main.gd 连接)
- `start_requested()`, `quit_requested()` — MainMenu
- `resumed()`, `back_to_menu()` — PauseMenu
- `level_selected(level_id)`, `back_requested()` — LevelSelect
- `restart_requested()`, `level_select_requested()`, `main_menu_requested()` — GameOverScreen

### HUD 公共方法 (由 main.gd 调用)
- `reset_kill_count()`, `update_intensity(n)`
- `show_boundary_warning()`, `show_notification(text, color)`
- `show_shield_block()`, `show_grab_status(name)`, `hide_grab_status()`

## 你依赖的其他模块

- **Core**: `GameBus.run_stats` — 读取分数/时间/强度
- **Core**: `GameBus.save_data` — 读取历史记录
- **Level**: `LevelRegistry` — 关卡特数据
- **Weapon**: `WeaponManager.get_weapon_count/get_weapon_at/get_current_index`, `WeaponNode.get_current_mag/get_current_reserve`

## 禁止事项

- 禁止直接访问 `_weapon_manager._weapons` — 用 `get_weapon_count()` / `get_weapon_at()` / `get_current_index()`
- 禁止直接访问 `_current_weapon._current_mag` — 用 `get_current_mag()` / `get_current_reserve()`
- 禁止通过 `get_tree().root.get_node_or_null("Main")` 获取数据 — 用 `GameBus.run_stats` / `GameBus.save_data`
- .tscn 文件禁止并行编辑

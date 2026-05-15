# Agent-Level: 关卡系统

## 你拥有的文件

- `scripts/level/arena_level.gd` — `ArenaLevel` 基类
- `scripts/level/arena_randomizer.gd` — `ArenaRandomizer`
- `scripts/level/level_registry.gd` — `LevelRegistry`
- `scripts/level/desert_arena.gd` — `DesertArena extends ArenaLevel`
- `scripts/level/lava_arena.gd` — `LavaArena extends ArenaLevel`
- `scripts/level/props/dead_tree_prop.gd` — 枯树
- `scripts/level/props/rock_column_prop.gd` — 岩柱
- `scripts/level/hazards/lava_river.gd` — 熔岩
- `scenes/levels/desert_arena.tscn`, `lava_arena.tscn`
- `scenes/props/dead_tree_prop.tscn`, `rock_column_prop.tscn`
- `scenes/hazards/lava_river.tscn`

## 你的公共接口

### ArenaLevel
- `get_arena_center()`, `get_arena_radius()`, `get_spawn_outer_radius()`
- `is_inside_arena(pos)`
- `set_player(node)`, `get_player_spawn_transform()`
- `get_random_prop_position(min_dist, safe_r)` → Dictionary
- `get_randomizer()` → ArenaRandomizer
- `register_occupied_point(pos)`, `clear_randomized_content()`

### 信号
- `boundary_warning_requested()` — 玩家越界
- `level_ready(arena)` — 构建完成

### LevelRegistry (静态)
- `get_level_ids()`, `get_display_name(id)`, `get_scene_path(id)`, `get_description(id)`

## 你依赖的其他模块

- **Damage**: `Damageable.take_damage()` — LavaRiver 伤害用
- **Weapon**: `WeaponData.DamageType` 枚举 — LavaRiver 使用 EXPLOSION 类型

## 禁止事项

- 禁止修改 `ArenaLevel` 的 `_randomizer` 直接访问 — 已经有 `get_randomizer()` 公共方法
- `.tscn` 文件禁止并行编辑
- LevelRegistry 的 level_id 字符串 ("desert", "lava") 如新增关卡需通知 Core/UI

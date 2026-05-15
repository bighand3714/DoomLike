# Level 模块 — 关卡系统

## 概述

圆形竞技场生成 + 道具/危险区随机放置 + 边界限制 + 关卡注册表。

## 所属文件

- `scripts/level/arena_level.gd` — `ArenaLevel` 基类 (地面/边界柱/越界检测)
- `scripts/level/arena_randomizer.gd` — `ArenaRandomizer` (圆内/环内取点)
- `scripts/level/level_registry.gd` — `LevelRegistry` (关卡元数据)
- `scripts/level/desert_arena.gd` — `DesertArena` (荒漠: 枯树)
- `scripts/level/lava_arena.gd` — `LavaArena` (熔岩: 岩柱+河流)
- `scripts/level/props/dead_tree_prop.gd` — 枯树道具
- `scripts/level/props/rock_column_prop.gd` — 岩柱道具
- `scripts/level/hazards/lava_river.gd` — 熔岩河流危险区

## 公共 API (ArenaLevel)

| 方法 | 说明 |
|------|------|
| `get_arena_center()` | 返回竞技场中心 |
| `get_arena_radius()` | 返回可玩区域半径 |
| `get_spawn_outer_radius()` | 返回刷怪外环半径 |
| `is_inside_arena(pos)` | 检查位置是否在界内 |
| `set_player(node)` | 注入玩家引用 |
| `get_player_spawn_transform()` | 返回出生点 Transform |
| `get_random_prop_position(min_dist, safe_r)` | 获取随机道具位置 |
| `get_randomizer()` | 返回 ArenaRandomizer |
| `register_occupied_point(pos)` | 注册已占用位置 |
| `clear_randomized_content()` | 清空道具/危险区 |

### 信号

| 信号 | 说明 |
|------|------|
| `boundary_warning_requested()` | 玩家越界 → HUD |
| `level_ready(arena)` | 竞技场构建完成 |

## LevelRegistry 静态方法

- `get_level_ids()` → `Array[String]` (`desert`, `lava`)
- `get_display_name(id)` → 中文名称
- `get_scene_path(id)` → `.tscn` 路径
- `get_description(id)` → 描述文本

## 依赖的其他模块

- Damage (Damageable used by lava_river)
- Weapon (WeaponData.DamageType enum)

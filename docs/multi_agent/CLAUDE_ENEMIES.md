# Agent-Enemies: 敌人系统

## 你拥有的文件

- `scripts/enemy/enemy.gd` — `Enemy` 基类 (状态机/眩晕/击退/抓取)
- `scripts/enemy/enemy_data.gd` — `EnemyData` Resource
- `scripts/enemy/enemy_manager.gd` — `EnemyManager` (追踪/信号)
- `scripts/enemy/spawn_manager.gd` — `SpawnManager` (波次/难度)
- `scripts/enemy/projectile.gd` — `Projectile` (Area3D 飞行弹)
- `scripts/enemy/imp.gd`, `demon_soldier.gd`
- `scripts/enemy/ground_enemy.gd`, `advanced_ground_enemy.gd`, `elite_ground_enemy.gd`
- `scripts/enemy/ranged_enemy.gd`, `advanced_ranged_enemy.gd`
- `scripts/enemy/flying_enemy.gd`, `advanced_flying_enemy.gd`, `flying_ranged_enemy.gd`
- `assets/enemies/*.tres` — 10 个 EnemyData 资源
- `scenes/enemies/*.tscn` — 10 个敌人场景

## 你的公共接口

### Enemy 基类
- `apply_stun(amount)`, `apply_knockback(dir, force)`
- `can_be_grabbed()` → bool
- `start_grab(owner)` → bool
- `update_grabbed_position(transform, delta)`
- `release_grab()`, `execute()`
- `trigger_on_damaged(amount, type)` — 外部触发受击反馈

### EnemyManager
- `enemy_killed(enemy_name, score_value)` 信号
- `all_cleared()` 信号

### SpawnManager
- `setup(arena, enemy_manager, run_stats, profile)`
- `start()`, `stop()`
- `intensity_changed(new_intensity)` 信号

## 你依赖的其他模块

- **Damage**: `Damageable.take_damage()`
- **Weapon**: `WeaponData.DamageType` 枚举 (只读)
- **Level**: `ArenaLevel.get_randomizer()`, `ArenaLevel.get_arena_center()`, `ArenaLevel.get_spawn_outer_radius()`
- **Player**: `_player.get_grabbed_enemy()`, `_player.global_transform`, `_player.global_position`
- **GameBus**: `shield_block` 信号

## 禁止事项

- `Enemy` 基类是最大瓶颈 — 10 个子类继承它，**禁止修改现有公共方法签名**
- 禁止通过 `arena.get("_randomizer")` 访问私有变量 — 用 `arena.get_randomizer()`
- 禁止新增 `get_tree().root.get_node_or_null("Main")` — 用 GameBus
- SpawnManager 硬编码的敌人 scene/tres 路径修改需同步更新 `assets/enemies/` 文件

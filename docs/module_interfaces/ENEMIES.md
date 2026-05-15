# Enemies 模块 — 敌人系统

## 概述

敌人基类状态机 + 10 种敌人类型 + 生成管理 + 投射物。

## 所属文件

- `scripts/enemy/enemy.gd` — `Enemy` 基类 (10 状态机/眩晕/击退/抓取)
- `scripts/enemy/enemy_data.gd` — `EnemyData` Resource
- `scripts/enemy/enemy_manager.gd` — `EnemyManager` (追踪/击杀信号)
- `scripts/enemy/spawn_manager.gd` — `SpawnManager` (波次/难度曲线)
- `scripts/enemy/projectile.gd` — `Projectile` 基类 (Area3D)
- `scripts/enemy/imp.gd`, `demon_soldier.gd` — 旧有敌人
- `scripts/enemy/ground_enemy.gd`, `advanced_ground_enemy.gd`, `elite_ground_enemy.gd` — 地面近战
- `scripts/enemy/ranged_enemy.gd`, `advanced_ranged_enemy.gd` — 地面远程
- `scripts/enemy/flying_enemy.gd`, `advanced_flying_enemy.gd`, `flying_ranged_enemy.gd` — 空中

## 公共 API (Enemy 基类)

| 方法 | 说明 |
|------|------|
| `apply_stun(amount)` | 施加眩晕值 |
| `apply_knockback(direction, force)` | 击退 |
| `can_be_grabbed()` | 眩晕满且未死亡 → true |
| `start_grab(owner)` | 开始被抓取 |
| `update_grabbed_position(transform, delta)` | 更新被抓位置 |
| `release_grab()` | 释放抓取 |
| `execute()` | 处决 (即死) |
| `trigger_on_damaged(amount, type)` | 外部触发受击反馈 |

### 信号

| 信号 | 发射者 | 说明 |
|------|--------|------|
| `enemy_died(enemy)` | Enemy | 单个敌人死亡 |
| `enemy_killed(name, score)` | EnemyManager | 计分链路 |
| `all_cleared()` | EnemyManager | 波次全灭 |
| `intensity_changed(new_intensity)` | SpawnManager | 难度变化 |

## EnemyData 关键字段

`max_health`, `attack_damage`, `damage_type`, `move_speed`, `attack_range`, `sight_range`, `max_stun`, `stun_resistance`, `weight`, `knockback_resistance`, `is_flying`, `score_value`, `spawn_cost`, `model_color`

## 瓶颈注意事项

`Enemy` 基类是最大瓶颈 — 所有 10 个敌人子类继承它。  
修改公共方法签名前必须通知所有 agent。

## 依赖的其他模块

- Damage (Damageable)
- Weapon (WeaponData.DamageType enum)
- Level (ArenaLevel, ArenaRandomizer)
- GameBus (信号通信)

# Agent-Weapons: 武器与拾取

## 你拥有的文件

- `scripts/weapon/weapon_data.gd` — `WeaponData` Resource + `DamageType`/`FireMode` 枚举
- `scripts/weapon/weapon_node.gd` — `WeaponNode` 基类
- `scripts/weapon/weapon_manager.gd` — `WeaponManager`
- `scripts/weapon/pistol.gd`, `scripts/weapon/shotgun.gd`
- `scripts/weapon/whip_data.gd` — `WhipData` Resource
- `scripts/weapon/iron_whip.gd` — 铁鞭 (右键/眩晕/拉取/抓取/处决)
- `scripts/pickup/pickup.gd`, `health_pickup.gd`, `armor_pickup.gd`, `ammo_pickup.gd`
- `assets/weapons/*.tres` — WeaponData + WhipData 资源

## 你的公共接口

### WeaponNode 方法
- `setup(data, camera)`, `reset_ammo()`
- `add_reserve_ammo(amount)` — Pickup 用
- `get_current_mag()`, `get_current_reserve()` — HUD 用

### WeaponManager 方法
- `get_current_weapon()`, `get_weapon_count()`, `get_weapon_at(index)`, `get_current_index()`
- `reset_all_weapons()`

### WeaponData 枚举 (被 6+ 模块引用)
- `DamageType`: HITSCAN, PROJECTILE, EXPLOSION, MELEE
- `FireMode`: SEMI, AUTO, PUMP

### IronWhip 方法
- `setup(data, camera, player)`, `release_grab()`, `is_grabbing()`, `get_grabbed_enemy()`

## 你依赖的其他模块

- **Enemy** (iron_whip.gd 预加载): `Enemy.apply_stun()`, `Enemy.can_be_grabbed()`, `Enemy.start_grab()`, `Enemy.execute()`, `Enemy.apply_knockback()`, `Enemy.trigger_on_damaged()`, `Enemy.update_grabbed_position()`, `Enemy.release_grab()`, `Enemy.enemy_data`
- **Damage**: `Damageable.take_damage()`
- **Player**: `_player.grabbed_enemy`, `_player.set_speed_multiplier()`
- **GameBus**: `pickup_notification`, `grab_status_show`, `grab_status_hide`, `GameBus.run_stats`

## 禁止事项

- 禁止直接访问 `enemy._on_damaged()` — 用 `enemy.trigger_on_damaged()` 代替
- 禁止访问其他模块 `_` 前缀私有变量
- 修改 `DamageType`/`FireMode` 枚举前通知所有 agent (追加值放末尾)
- 禁止通过 `get_tree().root.get_node_or_null("Main")` 找 Main (用 GameBus)

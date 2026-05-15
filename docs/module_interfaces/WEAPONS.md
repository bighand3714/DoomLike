# Weapons 模块 — 武器系统

## 概述

枪械射击 (左键) + 铁鞭近战/控制 (右键) + WhipData 参数驱动。

## 所属文件

- `scripts/weapon/weapon_data.gd` — `WeaponData` Resource + `DamageType`/`FireMode` 枚举
- `scripts/weapon/weapon_node.gd` — `WeaponNode` 基类 (射线/弹药/换弹/散布)
- `scripts/weapon/weapon_manager.gd` — `WeaponManager` 栏位管理
- `scripts/weapon/pistol.gd` — `Pistol` (半自动)
- `scripts/weapon/shotgun.gd` — `Shotgun` (泵动式)
- `scripts/weapon/whip_data.gd` — `WhipData` Resource
- `scripts/weapon/iron_whip.gd` — `IronWhip` (右键/眩晕/拉取/抓取/处决)
- `scripts/pickup/` — Pickup 基类 + AmmoPickup + HealthPickup + ArmorPickup

## 公共 API

### WeaponNode

| 方法 | 说明 |
|------|------|
| `setup(data, camera)` | 初始化武器 |
| `reset_ammo()` | 重置弹药到满 |
| `get_current_weapon()` | 返回当前武器节点 |
| `add_reserve_ammo(amount)` | 补充备弹 (Pickup 用) |
| `get_current_mag()` | 返回当前弹匣数 (HUD 用) |
| `get_current_reserve()` | 返回当前备弹数 (HUD 用) |

### WeaponManager

| 方法 | 说明 |
|------|------|
| `get_current_weapon()` | 返回当前武器 |
| `get_weapon_count()` | 返回武器栏位数 |
| `get_weapon_at(index)` | 返回指定栏位武器 |
| `get_current_index()` | 返回当前栏位索引 |
| `reset_all_weapons()` | 重置所有武器弹药 |

### IronWhip

| 方法 | 说明 |
|------|------|
| `setup(data, camera, player)` | 初始化铁鞭 |
| `release_grab()` | 释放抓取 |
| `is_grabbing()` | 是否正在抓取 |
| `get_grabbed_enemy()` | 返回被抓敌人 |

### 信号

| 信号 | 发射者 |
|------|--------|
| `fired()` | WeaponNode |
| `hit_something(point, normal, target)` | WeaponNode |
| `ammo_changed(mag, reserve)` | WeaponNode |
| `reload_started(time)` | WeaponNode |
| `reload_finished()` | WeaponNode |
| `weapon_changed(name, index)` | WeaponManager |

## 共享枚举 (其他模块依赖)

`WeaponData.DamageType`: `HITSCAN`, `PROJECTILE`, `EXPLOSION`, `MELEE`  
`WeaponData.FireMode`: `SEMI`, `AUTO`, `PUMP`

> 修改此枚举需通知 Enemy/Level/Damage/Pickup 模块。

## 依赖的其他模块

- Enemy (iron_whip 调用 enemy.apply_stun/start_grab/execute)
- GameBus (信号通信)

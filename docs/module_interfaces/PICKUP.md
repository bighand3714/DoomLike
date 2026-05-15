# Pickup 模块 — 拾取系统

## 概述

场景中的可拾取道具 (血包/护甲/弹药)，Area3D + 悬浮旋转动画。

## 所属文件

- `scripts/pickup/pickup.gd` — `Pickup` 基类
- `scripts/pickup/health_pickup.gd` — `HealthPickup` (红色, 恢复生命)
- `scripts/pickup/armor_pickup.gd` — `ArmorPickup` (蓝色, 装备护甲)
- `scripts/pickup/ammo_pickup.gd` — `AmmoPickup` (金色, 补充备弹)

## 公共 API (Pickup 基类)

| 属性 | 说明 |
|------|------|
| `pickup_range` | 拾取触发距离 |
| `float_height` | 悬浮高度 |
| `float_speed` | 悬浮速度 |
| `rotation_speed` | 旋转速度 |

## 依赖的其他模块

- Damage (Damageable: health_pickup, armor_pickup)
- Weapon (WeaponManager, WeaponNode: ammo_pickup)
- GameBus (pickup_notification)

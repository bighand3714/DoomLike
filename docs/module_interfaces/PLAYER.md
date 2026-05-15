# Player + Combat 模块 — 玩家与伤害系统

## 概述

FPS 移动/视角 + 伤害/护甲系统。

## 所属文件

- `scripts/player/player_controller.gd` — `PlayerController` (WASD/跳跃/鼠标视角)
- `scripts/damage/damageable.gd` — `Damageable` (血量/护甲/减伤)
- `scripts/damage/shooting_target.gd` — 测试靶子

## 公共 API (PlayerController)

| 方法 | 说明 |
|------|------|
| `set_speed_multiplier(mult)` | 移速倍率 (铁鞭抓取用) |
| `get_grabbed_enemy()` | 返回被抓敌人 (盾牌判定用) |

| 属性 | 说明 |
|------|------|
| `grabbed_enemy` | 当前被抓敌人引用 |

## Damageable API

| 方法 | 说明 |
|------|------|
| `take_damage(amount, type)` | 受到伤害 (护甲吸收 50%) |
| `add_health(amount)` | 恢复生命 |
| `add_armor(amount)` | 增加护甲 |
| `reset()` | 恢复到满血满护甲 |

| 信号 | 说明 |
|------|------|
| `died()` | 死亡 |
| `damaged(amount, type)` | 受伤 |
| `armor_changed(current, max)` | 护甲变化 |

## 依赖的其他模块

- GameBus (player_hit, pause_toggle 信号)
- Weapon (WeaponData.DamageType enum)

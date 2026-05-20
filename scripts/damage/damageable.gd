# ==============================================================================
# Damageable — 可受伤接口（含护甲系统）
# ==============================================================================
# 挂在任何"能被子弹打中"的节点下面，管理生命值和护甲值。
# ==============================================================================

class_name Damageable extends Node


# ==============================================================================
# 信号
# ==============================================================================

signal died()
signal damaged(amount: float, damage_type: WeaponData.DamageType)

## 护甲值改变时发射
signal armor_changed(current: float, max_val: float)


# ==============================================================================
# 属性
# ==============================================================================

@export var max_health: float = 100.0
var health: float

## 护甲——DOOM 经典机制，受伤时护甲先吸收一半伤害再扣血
var armor: float = 0.0
@export var max_armor: float = 100.0


# ==============================================================================
# _ready()
# ==============================================================================

func _ready() -> void:
	health = max_health


# ==============================================================================
# take_damage() — 受到伤害（含护甲减伤）
# ==============================================================================
# DOOM 经典规则：护甲吸收 50% 伤害。
#   例：受到 20 伤，有护甲 → 护甲 -10, 血量 -10
#   护甲不足时（如只剩 5）→ 护甲归零，血量扣 20 - 5 = 15
func take_damage(amount: float, damage_type: WeaponData.DamageType = WeaponData.DamageType.HITSCAN) -> void:
	if is_dead():
		return

	var health_dmg := amount

	if armor > 0.0:
		if armor >= amount:
			armor -= amount
			health_dmg = 0.0
		else:
			health_dmg = amount - armor
			armor = 0.0
		armor_changed.emit(armor, max_armor)

	health -= health_dmg
	damaged.emit(amount, damage_type)

	if health <= 0.0:
		health = 0.0
		died.emit()


# ==============================================================================
# add_health(amount) — 加血（血包用）
# ==============================================================================
func add_health(amount: float) -> void:
	health = min(health + amount, max_health)


# ==============================================================================
# add_armor(amount) — 加护甲（护甲拾取用）
# ==============================================================================
func add_armor(amount: float) -> void:
	armor = min(armor + amount, max_armor)
	armor_changed.emit(armor, max_armor)


# ==============================================================================
# reset() — 重置生命值和护甲到满值（关卡重启/重新开始时调用）
# ==============================================================================
# 为什么需要这个方法：
#   Phase 1.7 当前使用 reload_current_scene() 重置整个场景，Damageable 作为
#   Player 的子节点会被自动销毁重建，_ready() 自动把血量设回 max_health。
#   所以现在这个方法暂时不会被直接调用——它是在为 Phase 2 做准备。
#
#   Phase 2 会改用"卸载旧关卡 → 加载新关卡"的增量切换，不再 reload 整个场景。
#   届时 Player 及其 Damageable 会跨越多个关卡保留，需要手动调用 reset()
#   把血量/护甲恢复到满值，否则上一局的残血会带到下一关。
#
# 调用时机（Phase 2+）：
#   - 选关后进入新关卡时
#   - 结算界面点击"重新开始"时
#   - 从主菜单重新进入游戏时
#
# 行为：
#   - health = max_health（血量回满）
#   - armor = max_armor（护甲回满，即使之前没有护甲也会设为满值）
#   - 发射 armor_changed 信号，让 HUD 更新护甲显示
#   - 不会断开任何信号连接（died、damaged 等仍保持连接）
#   - 即使之前已经死亡（health <= 0），调用后也能恢复
func reset() -> void:
	health = max_health
	armor = 50.0
	armor_changed.emit(armor, max_armor)


# ==============================================================================
# is_dead()
# ==============================================================================

func is_dead() -> bool:
	return health <= 0.0

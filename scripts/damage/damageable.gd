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
	var armor_dmg := 0.0

	# 护甲减伤：吸收 50%
	if armor > 0.0:
		armor_dmg = amount * 0.5
		if armor_dmg > armor:
			armor_dmg = armor  # 护甲不够，全部耗尽
		armor -= armor_dmg
		health_dmg = amount - armor_dmg
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
# is_dead()
# ==============================================================================

func is_dead() -> bool:
	return health <= 0.0

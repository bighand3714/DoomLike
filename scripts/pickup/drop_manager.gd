# ==============================================================================
# DropManager — 掉落管理器（敌人死亡时概率掉落补给）
# ==============================================================================
class_name DropManager extends Node

## 弹药掉落概率
@export var ammo_drop_rate: float = 0.4
## 血包掉落概率
@export var health_drop_rate: float = 0.3
## 护甲掉落概率
@export var armor_drop_rate: float = 0.2

## 弹药补充量范围
@export var ammo_min: int = 10
@export var ammo_max: int = 20
## 生命恢复范围
@export var health_min: float = 15.0
@export var health_max: float = 25.0
## 护甲恢复范围
@export var armor_min: float = 15.0
@export var armor_max: float = 25.0
## 掉落物存活时间（秒）
@export var pickup_lifetime: float = 30.0

var _rng: RandomNumberGenerator
# 升级运行时修饰符（PlayerProgression.apply_drop_upgrade 修改）
var _ammo_mult: float = 1.0
var _health_mult: float = 1.0
var _drop_chance_bonus: float = 0.0


func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	GameBus.enemy_death_position.connect(_on_enemy_death)


func _on_enemy_death(position: Vector3) -> void:
	# 飞行敌人死亡位置在空中，掉落物落到地面
	position.y = 0.0
	var roll := _rng.randf()
	var cumulative := 0.0

	# 弹药 40%
	cumulative += clampf(ammo_drop_rate + _drop_chance_bonus, 0.0, 1.0)
	if roll <= cumulative:
		_spawn_ammo(position)
		return

	# 血包 30%
	cumulative += clampf(health_drop_rate + _drop_chance_bonus, 0.0, 1.0)
	if roll <= cumulative:
		_spawn_health(position)
		return

	# 护甲 20%
	cumulative += clampf(armor_drop_rate + _drop_chance_bonus, 0.0, 1.0)
	if roll <= cumulative:
		_spawn_armor(position)
		return

	# 10% 无掉落


func _spawn_ammo(pos: Vector3) -> void:
	var ammo := AmmoPickup.new()
	ammo.ammo_mult = _ammo_mult
	ammo.respawn_time = 0.0
	_setup_pickup(ammo, pos, Color.GOLD, Color.GOLD * 0.5)


func _spawn_health(pos: Vector3) -> void:
	var health := HealthPickup.new()
	health.heal_amount = _rng.randf_range(health_min, health_max) * _health_mult
	_setup_pickup(health, pos, Color.RED, Color.RED * 0.6)


func _spawn_armor(pos: Vector3) -> void:
	var armor := ArmorPickup.new()
	armor.armor_amount = _rng.randf_range(armor_min, armor_max)
	_setup_pickup(armor, pos, Color.CORNFLOWER_BLUE, Color.CORNFLOWER_BLUE * 0.5)


func _setup_pickup(pickup: Area3D, pos: Vector3, _color: Color, _emit: Color) -> void:
	get_tree().root.add_child(pickup)
	var rest_y: float = pos.y + 0.4
	pickup.global_position = Vector3(pos.x, rest_y, pos.z)
	pickup.set_hover_base_y(rest_y)

	# 30 秒后自动消失
	var timer := get_tree().create_timer(pickup_lifetime)
	timer.timeout.connect(pickup.queue_free)

# 升级系统——运行时修饰符更新（PlayerProgression 分发）
func apply_drop_upgrade(stat_key: String, value: float, operation: int) -> void:
	match stat_key:
		"ammo_amount_mult":
			match operation:
				0: _ammo_mult += value
				1: _ammo_mult *= value
				2: _ammo_mult = value
		"health_amount_mult":
			match operation:
				0: _health_mult += value
				1: _health_mult *= value
				2: _health_mult = value
		"drop_chance_bonus":
			match operation:
				0: _drop_chance_bonus += value
				1: _drop_chance_bonus *= value

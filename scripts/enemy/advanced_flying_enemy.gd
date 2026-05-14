# ==============================================================================
# AdvancedFlyingEnemy — 空中近战敌人（高级）
# ==============================================================================
# 速度更快、重量更高、眩晕抗性更高。攻击前短暂停顿。
# 外观：橙色较大体型 + 更大翅膀标志
# ==============================================================================

extends "res://scripts/enemy/enemy.gd"
class_name AdvancedFlyingEnemy


func _ready() -> void:
	if enemy_data == null:
		enemy_data = load("res://assets/enemies/advanced_flying_enemy.tres")
	super()


func _setup_model() -> void:
	for child in get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			if child.name != "Damageable":
				child.queue_free()

	var c: Color = enemy_data.model_color if enemy_data != null else Color(1.0, 0.45, 0.05)

	# 身体
	_add_box(Vector3(0, 0.55, 0), Vector3(0.7, 0.7, 0.5), c)
	# 头部
	_add_box(Vector3(0, 1.05, 0), Vector3(0.38, 0.3, 0.3), c.darkened(0.1))
	# 眼睛（红色发光）
	_add_box(Vector3(-0.1, 1.1, -0.17), Vector3(0.08, 0.06, 0.02), Color.RED, true)
	_add_box(Vector3(0.1, 1.1, -0.17), Vector3(0.08, 0.06, 0.02), Color.RED, true)
	# 大翅膀
	_add_box(Vector3(-0.55, 0.55, 0), Vector3(0.1, 0.45, 0.7), c.darkened(0.18))
	_add_box(Vector3(0.55, 0.55, 0), Vector3(0.1, 0.45, 0.7), c.darkened(0.18))
	# 尾部
	_add_box(Vector3(0, 0.25, 0.3), Vector3(0.12, 0.12, 0.3), c.darkened(0.22))
	# 角
	_add_box(Vector3(-0.12, 1.25, 0), Vector3(0.06, 0.15, 0.06), Color(0.15, 0.15, 0.15))
	_add_box(Vector3(0.12, 1.25, 0), Vector3(0.06, 0.15, 0.06), Color(0.15, 0.15, 0.15))

	_add_collision(0.45, 1.3, 0.65)


func _add_box(pos: Vector3, size: Vector3, color: Color, emissive: bool = false) -> void:
	var box := CSGBox3D.new()
	box.position = pos
	box.size = size
	box.use_collision = false
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.0
	box.material_override = mat
	add_child(box)


func _add_collision(radius: float, height: float, y_offset: float) -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = height
	col.shape = cap
	col.position = Vector3(0, y_offset, 0)
	add_child(col)

# ==============================================================================
# AdvancedRangedEnemy — 地面远程敌人（高级）
# ==============================================================================
# 更快投射物、更短冷却。横向移动概率更高。
# 外观：深蓝/靛色中型人形 + 护肩 + 更大的枪管
# ==============================================================================

extends "res://scripts/enemy/enemy.gd"
class_name AdvancedRangedEnemy


func _ready() -> void:
	if enemy_data == null:
		enemy_data = load("res://assets/enemies/advanced_ranged_enemy.tres")
	super()


func _setup_model() -> void:
	for child in get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			if child.name != "Damageable":
				child.queue_free()

	var c: Color = enemy_data.model_color if enemy_data != null else Color(0.15, 0.2, 0.6)

	# 身体
	_add_box(Vector3(0, 1.1, 0), Vector3(0.7, 0.8, 0.4), c)
	# 头部
	_add_box(Vector3(0, 1.7, 0), Vector3(0.36, 0.32, 0.32), c.darkened(0.1))
	# 眼罩
	_add_box(Vector3(0, 1.73, -0.17), Vector3(0.2, 0.07, 0.02), Color.CYAN, true)
	# 护肩
	_add_box(Vector3(-0.45, 1.35, 0), Vector3(0.2, 0.2, 0.25), c.darkened(0.05))
	_add_box(Vector3(0.45, 1.35, 0), Vector3(0.2, 0.2, 0.25), c.darkened(0.05))
	# 手臂
	_add_box(Vector3(-0.45, 1.1, 0), Vector3(0.2, 0.7, 0.2), c.darkened(0.06))
	_add_box(Vector3(0.45, 1.1, 0), Vector3(0.2, 0.7, 0.2), c.darkened(0.06))
	# 枪管（双管并排）
	_add_box(Vector3(0.5, 1.08, -0.3), Vector3(0.08, 0.08, 0.55), Color(0.1, 0.1, 0.14))
	_add_box(Vector3(0.5, 1.18, -0.3), Vector3(0.08, 0.08, 0.55), Color(0.1, 0.1, 0.14))
	# 腿
	_add_box(Vector3(-0.2, 0.4, 0), Vector3(0.24, 0.6, 0.24), c.darkened(0.16))
	_add_box(Vector3(0.2, 0.4, 0), Vector3(0.24, 0.6, 0.24), c.darkened(0.16))

	_add_collision(0.4, 1.85, 1.0)


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
		mat.emission_energy_multiplier = 1.5
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

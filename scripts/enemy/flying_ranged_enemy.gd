# ==============================================================================
# FlyingRangedEnemy — 空中远程敌人
# ==============================================================================
# 保持空中距离并发射投射物。优先保持高度，避免贴地。
# 外观：青色瘦长体 + 翅膀 + 枪管
# ==============================================================================

extends "res://scripts/enemy/enemy.gd"
class_name FlyingRangedEnemy


func _ready() -> void:
	if enemy_data == null:
		enemy_data = load("res://assets/enemies/flying_ranged_enemy.tres")
	super()


func _setup_model() -> void:
	for child in get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			if child.name != "Damageable":
				child.queue_free()

	var c: Color = enemy_data.model_color if enemy_data != null else Color(0.15, 0.7, 0.7)

	# 身体
	_add_box(Vector3(0, 0.5, 0), Vector3(0.5, 0.5, 0.35), c)
	# 头部
	_add_box(Vector3(0, 0.85, 0), Vector3(0.28, 0.22, 0.22), c.darkened(0.1))
	# 单眼
	_add_box(Vector3(0, 0.88, -0.12), Vector3(0.08, 0.05, 0.02), Color.CYAN, true)
	# 翅膀
	_add_box(Vector3(-0.4, 0.5, 0), Vector3(0.06, 0.3, 0.5), c.darkened(0.18))
	_add_box(Vector3(0.4, 0.5, 0), Vector3(0.06, 0.3, 0.5), c.darkened(0.18))
	# 枪管（下方伸出）
	_add_box(Vector3(0, 0.25, -0.25), Vector3(0.08, 0.08, 0.4), Color(0.1, 0.1, 0.13))
	# 尾部
	_add_box(Vector3(0, 0.35, 0.2), Vector3(0.08, 0.08, 0.18), c.darkened(0.2))

	_add_collision(0.32, 0.9, 0.5)


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

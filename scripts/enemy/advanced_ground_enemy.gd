# ==============================================================================
# AdvancedGroundEnemy — 地面近战敌人（高级）
# ==============================================================================
# 更快、更高血量。使用 Enemy 基类通用近战攻击。
# 外观：暗红色中型人形 + 头顶角饰
# ==============================================================================

extends "res://scripts/enemy/enemy.gd"
class_name AdvancedGroundEnemy


func _ready() -> void:
	if enemy_data == null:
		enemy_data = load("res://assets/enemies/advanced_ground_enemy.tres")
	super()


func _setup_model() -> void:
	for child in get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			if child.name != "Damageable":
				child.queue_free()

	var c: Color = enemy_data.model_color if enemy_data != null else Color(0.75, 0.15, 0.1)

	# 身体（比普通更宽）
	_add_box(Vector3(0, 1.15, 0), Vector3(0.85, 0.85, 0.45), c)
	# 头部
	_add_box(Vector3(0, 1.8, 0), Vector3(0.4, 0.35, 0.35), c.darkened(0.12))
	# 角饰（左右两块）
	_add_box(Vector3(-0.15, 2.05, 0), Vector3(0.08, 0.2, 0.08), Color(0.2, 0.2, 0.2))
	_add_box(Vector3(0.15, 2.05, 0), Vector3(0.08, 0.2, 0.08), Color(0.2, 0.2, 0.2))
	# 眼睛
	_add_box(Vector3(-0.1, 1.85, -0.19), Vector3(0.09, 0.07, 0.02), Color.YELLOW, true)
	_add_box(Vector3(0.1, 1.85, -0.19), Vector3(0.09, 0.07, 0.02), Color.YELLOW, true)
	# 手臂（更粗）
	_add_box(Vector3(-0.55, 1.15, 0), Vector3(0.22, 0.75, 0.22), c.darkened(0.08))
	_add_box(Vector3(0.55, 1.15, 0), Vector3(0.22, 0.75, 0.22), c.darkened(0.08))
	# 腿
	_add_box(Vector3(-0.22, 0.4, 0), Vector3(0.28, 0.6, 0.28), c.darkened(0.18))
	_add_box(Vector3(0.22, 0.4, 0), Vector3(0.28, 0.6, 0.28), c.darkened(0.18))

	_add_collision(0.5, 2.0, 1.1)


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

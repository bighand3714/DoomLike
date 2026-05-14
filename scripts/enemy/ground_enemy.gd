# ==============================================================================
# GroundEnemy — 地面近战敌人（普通）
# ==============================================================================
# 低血量、低重量、低分数。使用 Enemy 基类通用近战攻击。
# 外观：红色矮小人形
# ==============================================================================

extends "res://scripts/enemy/enemy.gd"
class_name GroundEnemy


func _ready() -> void:
	if enemy_data == null:
		enemy_data = load("res://assets/enemies/ground_enemy.tres")
	super()


func _setup_model() -> void:
	for child in get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			if child.name != "Damageable":
				child.queue_free()

	var c: Color = enemy_data.model_color if enemy_data != null else Color(1.0, 0.25, 0.2)

	# 身体
	_add_box(Vector3(0, 1.0, 0), Vector3(0.65, 0.7, 0.35), c)
	# 头部
	_add_box(Vector3(0, 1.55, 0), Vector3(0.35, 0.3, 0.3), c.darkened(0.15))
	# 眼睛
	_add_box(Vector3(-0.08, 1.6, -0.16), Vector3(0.08, 0.06, 0.02), Color.YELLOW, true)
	_add_box(Vector3(0.08, 1.6, -0.16), Vector3(0.08, 0.06, 0.02), Color.YELLOW, true)
	# 手臂
	_add_box(Vector3(-0.45, 1.0, 0), Vector3(0.18, 0.6, 0.18), c.darkened(0.1))
	_add_box(Vector3(0.45, 1.0, 0), Vector3(0.18, 0.6, 0.18), c.darkened(0.1))
	# 腿
	_add_box(Vector3(-0.18, 0.35, 0), Vector3(0.22, 0.5, 0.22), c.darkened(0.2))
	_add_box(Vector3(0.18, 0.35, 0), Vector3(0.22, 0.5, 0.22), c.darkened(0.2))

	_add_collision(0.4, 1.7, 0.95)


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

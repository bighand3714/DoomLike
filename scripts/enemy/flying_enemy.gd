# ==============================================================================
# FlyingEnemy — 空中近战敌人（普通）
# ==============================================================================
# 保持悬浮高度后靠近玩家进行近战攻击。血量较低、速度较快。
# 外观：黄色小体型 + 左右翼标
# ==============================================================================

extends "res://scripts/enemy/enemy.gd"
class_name FlyingEnemy


func _ready() -> void:
	if enemy_data == null:
		enemy_data = load("res://assets/enemies/flying_enemy.tres")
	super()


func _setup_model() -> void:
	for child in get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			if child.name != "Damageable":
				child.queue_free()

	var c: Color = enemy_data.model_color if enemy_data != null else Color(0.9, 0.75, 0.1)

	# 身体（紧凑球形）
	_add_box(Vector3(0, 0.45, 0), Vector3(0.55, 0.55, 0.4), c)
	# 头部（融入身体上方）
	_add_box(Vector3(0, 0.85, 0), Vector3(0.3, 0.25, 0.25), c.darkened(0.1))
	# 眼睛
	_add_box(Vector3(-0.08, 0.88, -0.14), Vector3(0.07, 0.05, 0.02), Color.WHITE, true)
	_add_box(Vector3(0.08, 0.88, -0.14), Vector3(0.07, 0.05, 0.02), Color.WHITE, true)
	# 翅膀标志（左右薄片）
	_add_box(Vector3(-0.45, 0.45, 0), Vector3(0.08, 0.35, 0.55), c.darkened(0.2))
	_add_box(Vector3(0.45, 0.45, 0), Vector3(0.08, 0.35, 0.55), c.darkened(0.2))
	# 尾部尖刺
	_add_box(Vector3(0, 0.25, 0.25), Vector3(0.1, 0.1, 0.2), c.darkened(0.25))

	_add_collision(0.35, 1.0, 0.5)


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

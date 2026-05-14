# ==============================================================================
# EliteGroundEnemy — 地面近战敌人（精英）
# ==============================================================================
# 大型模型、高血量、高重量、高分数。攻击前摇更明显但伤害更高。
# 外观：紫色大型重甲人形
# ==============================================================================

extends "res://scripts/enemy/enemy.gd"
class_name EliteGroundEnemy


func _ready() -> void:
	if enemy_data == null:
		enemy_data = load("res://assets/enemies/elite_ground_enemy.tres")
	super()


func _setup_model() -> void:
	for child in get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			if child.name != "Damageable":
				child.queue_free()

	var c: Color = enemy_data.model_color if enemy_data != null else Color(0.55, 0.2, 0.65)

	# 身体（宽大装甲）
	_add_box(Vector3(0, 1.4, 0), Vector3(1.2, 1.1, 0.65), c)
	# 胸甲（较亮方块）
	_add_box(Vector3(0, 1.5, -0.33), Vector3(0.8, 0.5, 0.06), c.lightened(0.25))
	# 肩甲
	_add_box(Vector3(-0.75, 1.65, 0), Vector3(0.35, 0.35, 0.35), c.darkened(0.1))
	_add_box(Vector3(0.75, 1.65, 0), Vector3(0.35, 0.35, 0.35), c.darkened(0.1))
	# 头部
	_add_box(Vector3(0, 2.1, 0), Vector3(0.5, 0.45, 0.45), c.darkened(0.12))
	# 眼睛（红色发光）
	_add_box(Vector3(-0.12, 2.15, -0.24), Vector3(0.1, 0.08, 0.02), Color.RED, true)
	_add_box(Vector3(0.12, 2.15, -0.24), Vector3(0.1, 0.08, 0.02), Color.RED, true)
	# 手臂（粗壮）
	_add_box(Vector3(-0.75, 1.4, 0), Vector3(0.28, 0.9, 0.28), c.darkened(0.06))
	_add_box(Vector3(0.75, 1.4, 0), Vector3(0.28, 0.9, 0.28), c.darkened(0.06))
	# 腿
	_add_box(Vector3(-0.3, 0.5, 0), Vector3(0.35, 0.75, 0.35), c.darkened(0.16))
	_add_box(Vector3(0.3, 0.5, 0), Vector3(0.35, 0.75, 0.35), c.darkened(0.16))

	_add_collision(0.65, 2.6, 1.4)


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

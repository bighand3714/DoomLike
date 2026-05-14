# ==============================================================================
# RangedEnemy — 地面远程敌人（普通）
# ==============================================================================
# 到达 preferred_range 后停止推进，使用慢速投射物攻击。
# 玩家太近时缓慢后退。
# 外观：蓝色瘦长人形 + 枪管
# ==============================================================================

extends "res://scripts/enemy/enemy.gd"
class_name RangedEnemy


func _ready() -> void:
	if enemy_data == null:
		enemy_data = load("res://assets/enemies/ranged_enemy.tres")
	super()


func _setup_model() -> void:
	for child in get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			if child.name != "Damageable":
				child.queue_free()

	var c: Color = enemy_data.model_color if enemy_data != null else Color(0.2, 0.35, 0.8)

	# 身体（较瘦）
	_add_box(Vector3(0, 1.05, 0), Vector3(0.6, 0.75, 0.35), c)
	# 头部
	_add_box(Vector3(0, 1.6, 0), Vector3(0.32, 0.28, 0.28), c.darkened(0.12))
	# 单眼（瞄准镜风格）
	_add_box(Vector3(0, 1.63, -0.15), Vector3(0.1, 0.06, 0.02), Color.RED, true)
	# 手臂
	_add_box(Vector3(-0.4, 1.05, 0), Vector3(0.16, 0.6, 0.16), c.darkened(0.08))
	_add_box(Vector3(0.4, 1.05, 0), Vector3(0.16, 0.6, 0.16), c.darkened(0.08))
	# 枪管（前方突出）
	_add_box(Vector3(0.5, 1.05, -0.25), Vector3(0.1, 0.1, 0.45), Color(0.12, 0.12, 0.15))
	# 腿
	_add_box(Vector3(-0.16, 0.4, 0), Vector3(0.2, 0.55, 0.2), c.darkened(0.18))
	_add_box(Vector3(0.16, 0.4, 0), Vector3(0.2, 0.55, 0.2), c.darkened(0.18))

	_add_collision(0.35, 1.75, 0.95)


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

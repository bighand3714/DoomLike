# ==============================================================================
# Imp — 小恶魔
# ==============================================================================
# 继承 Enemy 基类。行为特征：
#   - 远程攻击（> 2m）：投掷火球投射物（15 伤害，飞行速度 10m/s）
#   - 近战攻击（≤ 2m）：爪击（10 伤害，MELEE 类型）
#   - 攻击冷却 1.0 秒
#
# 外观：用 CSGBox3D 拼成简陋人形（身体 + 头 + 四肢）
# ==============================================================================

extends "res://scripts/enemy/enemy.gd"
class_name Imp

# 预加载投射物类
const ProjectileClass = preload("res://scripts/enemy/projectile.gd")


# ==============================================================================
# 内部变量
# ==============================================================================

var _fireball_scene: PackedScene = null


# ==============================================================================
# _setup_model() — 创建 Imp 外观
# ==============================================================================
func _setup_model() -> void:
	# 移除基类创建的默认模型（如果有的话，会覆盖）
	for child in get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			if child.name != "Damageable":
				child.queue_free()

	# --- 身体（躯干）---
	var body := _make_csg_box(Vector3(0, 1.1, 0), Vector3(0.7, 0.8, 0.4), Color(0.65, 0.3, 0.2))
	body.name = "Body"

	# --- 头部 ---
	var head := _make_csg_box(Vector3(0, 1.75, 0), Vector3(0.4, 0.35, 0.35), Color(0.7, 0.25, 0.15))
	head.name = "Head"

	# --- 眼睛（两个小白色方块）---
	var left_eye := _make_csg_box(Vector3(-0.1, 1.8, -0.18), Vector3(0.1, 0.08, 0.02), Color.YELLOW)
	left_eye.name = "LeftEye"
	var right_eye := _make_csg_box(Vector3(0.1, 1.8, -0.18), Vector3(0.1, 0.08, 0.02), Color.YELLOW)
	right_eye.name = "RightEye"

	# --- 手臂（左右）---
	var left_arm := _make_csg_box(Vector3(-0.5, 1.1, 0), Vector3(0.2, 0.7, 0.2), Color(0.6, 0.25, 0.15))
	left_arm.name = "LeftArm"
	var right_arm := _make_csg_box(Vector3(0.5, 1.1, 0), Vector3(0.2, 0.7, 0.2), Color(0.6, 0.25, 0.15))
	right_arm.name = "RightArm"

	# --- 腿（左右）---
	var left_leg := _make_csg_box(Vector3(-0.2, 0.4, 0), Vector3(0.25, 0.6, 0.25), Color(0.5, 0.2, 0.12))
	left_leg.name = "LeftLeg"
	var right_leg := _make_csg_box(Vector3(0.2, 0.4, 0), Vector3(0.25, 0.6, 0.25), Color(0.5, 0.2, 0.12))
	right_leg.name = "RightLeg"

	# --- 碰撞体 ---
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 2.0
	collision.shape = capsule
	collision.position = Vector3(0, 1.1, 0)
	add_child(collision)


# ==============================================================================
# _make_csg_box() — 创建 CSG 盒子（Imp 专用快捷函数）
# ==============================================================================
func _make_csg_box(pos: Vector3, size: Vector3, color: Color) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.position = pos
	box.size = size
	box.use_collision = false  # 外观碎片不参与碰撞（已经有 CapsuleShape3D）
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	box.material_override = mat
	add_child(box)
	return box


# ==============================================================================
# _execute_attack() — 执行攻击
# ==============================================================================
# Imp 的攻击方式：
#   - 距离 > 2m：发射火球（PROJECTILE）
#   - 距离 ≤ 2m：近战爪击（MELEE）
func _execute_attack() -> void:
	if _player == null:
		return

	var dist := global_position.distance_to(_player.global_position)

	if dist <= 2.0:
		# 近战爪击——直接伤血
		_melee_attack()
	else:
		# 远程火球
		_fireball_attack()


# ==============================================================================
# _melee_attack() — 近战爪击
# ==============================================================================
func _melee_attack() -> void:
	# 对玩家造成近战伤害
	var dmg := _player.get_node_or_null("Damageable")
	if dmg != null and dmg is Damageable:
		dmg.take_damage(enemy_data.attack_damage, WeaponData.DamageType.MELEE)
	elif _player.has_method("take_damage"):
		_player.take_damage(enemy_data.attack_damage, WeaponData.DamageType.MELEE)


# ==============================================================================
# _fireball_attack() — 远程火球
# ==============================================================================
func _fireball_attack() -> void:
	# 创建火球投射物
	var fireball: Area3D = ProjectileClass.new()
	fireball.speed = 10.0
	fireball.damage = enemy_data.attack_damage
	fireball.damage_type = WeaponData.DamageType.PROJECTILE
	fireball.lifetime = 5.0

	# 必须先加入场景树才能设置 global_position
	get_tree().root.add_child(fireball)
	fireball._setup_visual()  # 立即创建碰撞体和外观（不等 _ready）

	# 发射位置：Imp 头部前方
	var spawn_pos := global_position + Vector3(0, 1.65, 0)
	fireball.global_position = spawn_pos

	# 飞行方向：朝向玩家
	var direction := (_player.global_position + Vector3(0, 1.0, 0) - spawn_pos).normalized()
	fireball.setup(direction, self)


# ==============================================================================
# _on_death_visual() — Imp 专属死亡特效
# ==============================================================================
# 缩小 + 下沉 + 变灰
func _on_death_visual() -> void:
	# 收集所有子节点（用于缩放）
	var nodes_to_shrink: Array[Node3D] = []
	for child in get_children():
		if child is CSGBox3D:
			nodes_to_shrink.append(child)

	# 变灰所有 CSG 盒子
	for child in get_children():
		if child is CSGBox3D:
			var box: CSGBox3D = child
			var death_mat := StandardMaterial3D.new()
			death_mat.albedo_color = Color(0.25, 0.25, 0.25)
			box.material_override = death_mat

	# 用 Tween 缩小并下沉
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3(0.7, 0.5, 0.7), enemy_data.death_duration)
	tween.tween_property(self, "position:y", position.y - 0.3, enemy_data.death_duration)

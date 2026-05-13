# ==============================================================================
# DemonSoldier — 恶魔士兵
# ==============================================================================
# 继承 Enemy 基类。行为特征：
#   - 远程 hitscan 攻击（瞬时命中，类似手枪但有前摇）
#   - 攻击间隔 1.5 秒，有 0.15 秒举枪前摇
#   - 移动比 Imp 慢，但更耐打
#   - 没有近战攻击（纯远程）
#
# 外观：用 CSGBox3D 拼成比 Imp 更大更方正的装甲士兵
# ==============================================================================

extends "res://scripts/enemy/enemy.gd"
class_name DemonSoldier

# 编辑器直接放置时自动加载默认配置
func _ready() -> void:
	if enemy_data == null:
		enemy_data = load("res://assets/enemies/demon_soldier.tres")
	super()


# ==============================================================================
# 内部状态
# ==============================================================================

## 射击前摇计时器——举枪需要时间，玩家能看到准备动作
var _aim_timer: float = 0.0

## 是否正在瞄准（举枪中）
var _is_aiming: bool = false


# ==============================================================================
# _setup_model() — 创建士兵外观
# ==============================================================================
func _setup_model() -> void:
	# 清理基类默认模型
	for child in get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			if child.name != "Damageable":
				child.queue_free()

	# --- 身体（宽大装甲躯干）---
	var body := _make_csg_box(Vector3(0, 1.2, 0), Vector3(0.9, 0.9, 0.5), Color(0.35, 0.35, 0.4))
	body.name = "Body"

	# --- 肩甲 ---
	var left_shoulder := _make_csg_box(Vector3(-0.6, 1.45, 0), Vector3(0.3, 0.3, 0.35), Color(0.4, 0.4, 0.45))
	left_shoulder.name = "LeftShoulder"
	var right_shoulder := _make_csg_box(Vector3(0.6, 1.45, 0), Vector3(0.3, 0.3, 0.35), Color(0.4, 0.4, 0.45))
	right_shoulder.name = "RightShoulder"

	# --- 头部（头盔）---
	var head := _make_csg_box(Vector3(0, 1.95, 0), Vector3(0.45, 0.4, 0.4), Color(0.3, 0.3, 0.35))
	head.name = "Head"

	# --- 头盔护目镜（红色发光）---
	var visor := _make_csg_box(Vector3(0, 1.97, -0.21), Vector3(0.3, 0.12, 0.02), Color.RED)
	visor.name = "Visor"

	# --- 手臂（装甲）---
	var left_arm := _make_csg_box(Vector3(-0.6, 1.1, 0), Vector3(0.25, 0.8, 0.25), Color(0.33, 0.33, 0.38))
	left_arm.name = "LeftArm"
	var right_arm := _make_csg_box(Vector3(0.6, 1.1, 0), Vector3(0.25, 0.8, 0.25), Color(0.33, 0.33, 0.38))
	right_arm.name = "RightArm"

	# --- 枪（右臂前方的小方块）---
	var gun := _make_csg_box(Vector3(0.85, 1.1, -0.2), Vector3(0.12, 0.12, 0.5), Color(0.15, 0.15, 0.18))
	gun.name = "Gun"

	# --- 腿（装甲护腿）---
	var left_leg := _make_csg_box(Vector3(-0.25, 0.4, 0), Vector3(0.3, 0.65, 0.3), Color(0.33, 0.33, 0.38))
	left_leg.name = "LeftLeg"
	var right_leg := _make_csg_box(Vector3(0.25, 0.4, 0), Vector3(0.3, 0.65, 0.3), Color(0.33, 0.33, 0.38))
	right_leg.name = "RightLeg"

	# --- 碰撞体（比 Imp 稍大）---
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 2.1
	collision.shape = capsule
	collision.position = Vector3(0, 1.2, 0)
	add_child(collision)


# ==============================================================================
# _make_csg_box() — 创建 CSG 盒子
# ==============================================================================
func _make_csg_box(pos: Vector3, size: Vector3, color: Color) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.position = pos
	box.size = size
	box.use_collision = false
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	# 金属感：低粗糙度
	mat.roughness = 0.5
	mat.metallic = 0.3
	box.material_override = mat
	add_child(box)
	return box


# ==============================================================================
# _execute_attack() — hitscan 射击攻击
# ==============================================================================
# 士兵的攻击有"举枪前摇"（0.15 秒），然后发射不可躲避的瞬间射线。
# 玩家感受到的节奏：士兵停顿 → 举枪 → 枪响 → 玩家受伤。
func _execute_attack() -> void:
	# 短暂停顿（射击前摇——举枪）
	velocity = Vector3.ZERO
	_is_aiming = true

	# 用 Timer 延迟 0.15 秒后执行实际射击
	var timer := get_tree().create_timer(0.15)
	timer.timeout.connect(_do_shoot)


# ==============================================================================
# _do_shoot() — 实际发射 hitscan 射线
# ==============================================================================
func _do_shoot() -> void:
	_is_aiming = false

	if _player == null:
		return

	# 从敌人"眼睛"位置向玩家发射瞬时射线
	var origin := global_position + Vector3(0, 1.85, 0)
	var direction := (_player.global_position + Vector3(0, 1.0, 0) - origin).normalized()
	var end := origin + direction * 50.0  # 士兵射程 50m

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = 1
	query.exclude = [self]

	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return

	var target: Node = result.collider

	# 命中玩家？
	if target == _player or target.get_parent() == _player:
		var dmg := _player.get_node_or_null("Damageable")
		if dmg != null and dmg is Damageable:
			dmg.take_damage(enemy_data.attack_damage, WeaponData.DamageType.HITSCAN)
		elif _player.has_method("take_damage"):
			_player.take_damage(enemy_data.attack_damage, WeaponData.DamageType.HITSCAN)


# ==============================================================================
# _on_death_visual() — 士兵专属死亡特效
# ==============================================================================
func _on_death_visual() -> void:
	for child in get_children():
		if child is CSGBox3D:
			var box: CSGBox3D = child
			var death_mat := StandardMaterial3D.new()
			death_mat.albedo_color = Color(0.2, 0.2, 0.22)
			box.material_override = death_mat

	# 缓慢缩小
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.5, 0.5, 0.5), enemy_data.death_duration)
	tween.parallel().tween_property(self, "position:y", position.y - 0.4, enemy_data.death_duration)

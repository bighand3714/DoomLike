# ==============================================================================
# Projectile — 投射物基类
# ==============================================================================
# 火球、火箭弹、等离子弹等"飞行子弹"的共同基类。
# 使用 Area3D 而不是 RigidBody3D，因为投射物不需要物理推搡——
# 只需要"当我和什么东西重叠了"的检测。
#
# 子类可以覆写 _setup_visual() 来自定义外观。
# ==============================================================================

class_name Projectile extends Area3D


# ==============================================================================
# 导出属性
# ==============================================================================

## 飞行速度（m/s）— 火球约 10，火箭约 20
@export var speed: float = 10.0

## 命中时造成的伤害值
@export var damage: float = 15.0

## 伤害类型 — 默认 PROJECTILE（飞行弹）
@export var damage_type: WeaponData.DamageType = WeaponData.DamageType.PROJECTILE

## 最大存活时间（秒）— 防止飞出地图后永久占用内存
@export var lifetime: float = 5.0


# ==============================================================================
# 内部状态
# ==============================================================================

## 飞行方向（世界空间，归一化）
var _direction: Vector3 = Vector3.FORWARD

## 谁发射了这个投射物（用于"不对发射者造成伤害"的判断）
var _owner_node: Node3D = null


# ==============================================================================
# _enter_tree() — 进入场景树时连接信号（立即执行，不等 _ready）
# ==============================================================================
func _enter_tree() -> void:
	# 连接碰撞信号——当有物理体进入此 Area3D 时触发
	# _enter_tree 在 add_child 后立即调用，比 _ready 早，确保不会漏掉碰撞
	body_entered.connect(_on_body_entered)


# ==============================================================================
# setup(direction, owner) — 外部调用，设置飞行方向和发射者
# ==============================================================================
func setup(direction: Vector3, owner_node: Node3D) -> void:
	_direction = direction.normalized()
	_owner_node = owner_node

	# 让投射物朝向飞行方向（用 look_at_from_position 兼容"不在场景树中"的情况）
	look_at_from_position(global_position, global_position + _direction, Vector3.UP)


# ==============================================================================
# _physics_process(delta) — 每物理帧移动投射物
# ==============================================================================
func _physics_process(delta: float) -> void:
	# 沿方向飞行
	global_position += _direction * speed * delta

	# 生命周期倒计时
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


# ==============================================================================
# _on_body_entered(body) — 撞到物理体时触发
# ==============================================================================
func _on_body_entered(body: Node3D) -> void:
	# 不要打到自己（发射者）
	if body == _owner_node:
		return

	# 也不要打到发射者的父节点（比如敌人发射火球，火球不应碰到敌人自己）
	if _owner_node != null and (body == _owner_node.get_parent() or body == _owner_node):
		return

	# 盾牌阻挡检测：目标为玩家且玩家抓取了敌人 → 伤害转移给被抓敌人
	if body.is_in_group("player"):
		var grabbed: Node = null
		if body.has_method("get_grabbed_enemy"):
			grabbed = body.get_grabbed_enemy()
		if grabbed != null and is_instance_valid(grabbed):
			var shield_dmg = grabbed.get_node_or_null("Damageable") as Damageable
			if shield_dmg != null:
				shield_dmg.take_damage(damage, damage_type)
				var main := get_tree().root.get_node_or_null("Main")
				if main != null:
					var ps := main.get_node_or_null("UI/PlayerStatus")
					if ps != null and ps.has_method("show_shield_block"):
						ps.show_shield_block()
				_on_impact(body)
				queue_free()
				return

	# 尝试对目标造成伤害
	if body.has_method("take_damage"):
		body.take_damage(damage, damage_type)
	else:
		# 递归查找子节点中的 Damageable
		_try_damage_child(body)

	# 命中特效（子类可覆写）
	_on_impact(body)

	# 投射物销毁
	queue_free()


# ==============================================================================
# _try_damage_child(node) — 递归查找 Damageable 子节点
# ==============================================================================
# 和 WeaponNode._try_damage_child 逻辑相同——
# 有些节点的 Damageable 作为子节点挂在下面
func _try_damage_child(node: Node) -> void:
	for child in node.get_children():
		if child is Damageable:
			child.take_damage(damage, damage_type)
			return

	# 没找到？看看父节点
	var parent := node.get_parent()
	if parent:
		_try_damage_child(parent)


# ==============================================================================
# _setup_visual() — 创建外观模型（子类覆写）
# ==============================================================================
# 基类默认创建一个发光小球体作为占位
func _setup_visual() -> void:
	# 碰撞体——用 CollisionShape3D 包裹球体
	var collision := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.2
	collision.shape = sphere_shape
	add_child(collision)

	# 视觉模型——发橙色光的球体
	var mesh := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.15
	sphere_mesh.height = 0.3
	mesh.mesh = sphere_mesh

	# 橙色发光材质（火球效果）
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.0, 1.0)
	mat.emission_energy_multiplier = 2.0
	mesh.material_override = mat

	add_child(mesh)


# ==============================================================================
# _on_impact(body) — 命中时特效（子类覆写）
# ==============================================================================
# 基类默认什么都不做。子类可以覆写来添加火花粒子、爆炸音效等。
func _on_impact(_body: Node3D) -> void:
	pass

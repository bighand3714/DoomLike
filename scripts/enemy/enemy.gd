# ==============================================================================
# Enemy — 敌人基类
# ==============================================================================
# 所有敌人（Imp、Demon Soldier、未来 Boss……）的共同"大脑"。
# 使用 CharacterBody3D 因为敌人需要在物理世界中移动和碰撞。
#
# 状态机：
#   IDLE → CHASE → ATTACK → CHASE → ...
#   任意状态 → PAIN → CHASE
#   任意状态 → DEATH → queue_free
#
# 子类需要覆写的方法：
#   _setup_model()       — 创建外观模型
#   _execute_attack()    — 执行攻击（火球 / hitscan / 近战）
#   _on_death_visual()   — 死亡特效
# ==============================================================================

class_name Enemy extends CharacterBody3D

# 预加载依赖的类
const EnemyDataClass = preload("res://scripts/enemy/enemy_data.gd")


# ==============================================================================
# 状态枚举
# ==============================================================================

enum EnemyState {
	IDLE,     # 待机——未发现玩家，原地站立
	PATROL,   # 巡逻——沿路径点移动（Phase 3 简化为原地踱步）
	CHASE,    # 追击——朝玩家移动
	ATTACK,   # 攻击——在攻击距离内，执行攻击动作
	PAIN,     # 受击硬直——短暂僵住
	DEATH,    # 死亡——播放死亡动画，等待消失
}


# ==============================================================================
# 信号
# ==============================================================================

## 敌人死亡时发射——EnemyManager 用它追踪击杀数
signal enemy_died(enemy: Enemy)


# ==============================================================================
# 导出属性
# ==============================================================================

## 敌人配置数据——在编辑器中拖入 .tres 文件即可
@export var enemy_data: Resource


# ==============================================================================
# 内部状态变量
# ==============================================================================

var _state: EnemyState = EnemyState.IDLE
var _player: CharacterBody3D = null
var _damageable: Damageable
var _state_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _sight_ray: RayCast3D
var _original_materials: Dictionary = {}  # 用于受伤闪白后恢复


# ==============================================================================
# _ready() — 初始化敌人
# ==============================================================================
func _ready() -> void:
	# 找到玩家引用——通过场景唯一名称
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		# fallback：通过 %Player 查找
		_player = get_node_or_null("/root/Main/Player") as CharacterBody3D

	# 创建/获取 Damageable 子节点
	_damageable = _get_or_create_damageable()
	_damageable.damaged.connect(_on_damaged)
	_damageable.died.connect(_on_died)

	# 创建视线检测射线
	_sight_ray = RayCast3D.new()
	_sight_ray.target_position = Vector3(0, 0, -10.0)  # 前方 10m，后续动态更新
	_sight_ray.collision_mask = 1
	_sight_ray.enabled = false  # 手动控制检测时机
	add_child(_sight_ray)

	# 让子类创建外观模型
	_setup_model()


# ==============================================================================
# _get_or_create_damageable() — 获取已有的 Damageable 或创建新的
# ==============================================================================
func _get_or_create_damageable() -> Damageable:
	for child in get_children():
		if child is Damageable:
			if enemy_data != null:
				child.max_health = enemy_data.max_health
			return child

	var d := Damageable.new()
	d.name = "Damageable"
	if enemy_data != null:
		d.max_health = enemy_data.max_health
	add_child(d)
	return d


# ==============================================================================
# _setup_model() — 创建外观模型（子类覆写）
# ==============================================================================
# 基类默认创建一个 1×1×1 的红色立方体占位。
# 子类应该覆写此方法创建自己的模型。
func _setup_model() -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 1.8, 0.6)
	mesh.mesh = box
	mesh.position = Vector3(0, 0.9, 0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.2)
	mesh.material_override = mat

	add_child(mesh)

	# 碰撞体
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collision.shape = capsule
	collision.position = Vector3(0, 0.9, 0)
	add_child(collision)


# ==============================================================================
# _physics_process(delta) — 每物理帧调用
# ==============================================================================
func _physics_process(delta: float) -> void:
	if enemy_data == null or _player == null:
		return

	# 更新攻击冷却
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	# 根据当前状态分发
	match _state:
		EnemyState.IDLE:
			_state_idle(delta)
		EnemyState.PATROL:
			_state_patrol(delta)
		EnemyState.CHASE:
			_state_chase(delta)
		EnemyState.ATTACK:
			_state_attack(delta)
		EnemyState.PAIN:
			_state_pain(delta)
		EnemyState.DEATH:
			_state_death(delta)


# ==============================================================================
# _transition_to(new_state) — 状态切换
# ==============================================================================
# 离开旧状态时做清理（比如重置计时器），进入新状态时做初始化。
func _transition_to(new_state: EnemyState) -> void:
	if _state == EnemyState.DEATH:
		return  # 死亡不可逆

	_state = new_state
	_state_timer = 0.0


# ==============================================================================
# 状态：IDLE — 待机
# ==============================================================================
# 每帧检查"是否看到玩家"。看到就切换到 CHASE。
func _state_idle(_delta: float) -> void:
	if _can_see_player():
		_transition_to(EnemyState.CHASE)


# ==============================================================================
# 状态：PATROL — 巡逻（Phase 3 简化为原地踱步）
# ==============================================================================
# 当前只是不断检查是否看到玩家。后续 Phase 5 可加入路径点巡逻。
func _state_patrol(_delta: float) -> void:
	if _can_see_player():
		_transition_to(EnemyState.CHASE)


# ==============================================================================
# 状态：CHASE — 追击
# ==============================================================================
# 朝玩家方向移动。当进入攻击距离时切换到 ATTACK。
func _state_chase(delta: float) -> void:
	# 朝向玩家（只在 XZ 平面转向，DOOM 2.5D 传统）
	var to_player := _player.global_position - global_position
	to_player.y = 0.0

	var dist := to_player.length()

	# 玩家跑出视野范围 × 1.5 —— 给一点余量，不频繁切换
	if dist > enemy_data.sight_range * 1.5:
		_transition_to(EnemyState.IDLE)
		return

	# 进入攻击距离 → 切换到 ATTACK
	if dist <= enemy_data.attack_range:
		_transition_to(EnemyState.ATTACK)
		return

	# 朝玩家移动
	var direction := to_player.normalized()
	velocity = direction * enemy_data.move_speed

	# 转向玩家
	look_at(global_position + direction, Vector3.UP)

	move_and_slide()


# ==============================================================================
# 状态：ATTACK — 攻击
# ==============================================================================
# 执行攻击动作，之后根据距离决定继续追击还是留在攻击状态。
func _state_attack(_delta: float) -> void:
	# 面朝玩家
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() > 0.01:
		look_at(global_position + to_player.normalized(), Vector3.UP)

	# 检查攻击冷却
	if _attack_cooldown_timer > 0.0:
		return

	# 执行攻击（子类覆写）
	_execute_attack()

	# 设置冷却
	_attack_cooldown_timer = enemy_data.attack_cooldown

	# 如果玩家跑出攻击距离，切回追击
	var dist := to_player.length()
	if dist > enemy_data.attack_range * 1.2:
		_transition_to(EnemyState.CHASE)


# ==============================================================================
# _execute_attack() — 执行攻击动作（子类覆写）
# ==============================================================================
func _execute_attack() -> void:
	pass  # 子类实现：火球 / hitscan / 近战


# ==============================================================================
# 状态：PAIN — 受击硬直
# ==============================================================================
func _state_pain(delta: float) -> void:
	_state_timer += delta
	if _state_timer >= enemy_data.pain_duration:
		# 硬直结束，恢复追击
		_transition_to(EnemyState.CHASE)


# ==============================================================================
# 状态：DEATH — 死亡
# ==============================================================================
func _state_death(delta: float) -> void:
	_state_timer += delta
	if _state_timer >= enemy_data.death_duration:
		queue_free()


# ==============================================================================
# _can_see_player() — 检查"是否能看到玩家"
# ==============================================================================
# 分两步检查：
#   1. 粗略距离检查（省性能）
#   2. 精确射线检查（确认中间没有墙壁遮挡）
func _can_see_player() -> bool:
	if _player == null:
		return false

	var to_player := _player.global_position - global_position
	var dist := to_player.length()

	# 距离太远 → 看不见
	if dist > enemy_data.sight_range:
		return false

	# 射线检测：敌人眼睛位置 → 玩家位置
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 1.5, 0),  # 敌人"眼睛"高度
		_player.global_position + Vector3(0, 1.0, 0)  # 玩家身体中心
	)
	query.collision_mask = 1
	query.exclude = [self]  # 不要撞到自己

	var result := space_state.intersect_ray(query)

	# 如果射线没碰到任何东西 → 看不见（空场景？不应该发生）
	if result.is_empty():
		return false

	# 检查射线撞到的是不是玩家
	var collider: Node = result.collider
	if collider == _player:
		return true

	# 也检查玩家的子节点（Camera3D 等）
	var parent: Node = collider.get_parent()
	while parent != null:
		if parent == _player:
			return true
		parent = parent.get_parent()

	return false


# ==============================================================================
# _on_damaged(amount, type) — 受到伤害回调
# ==============================================================================
func _on_damaged(_amount: float, _type: WeaponData.DamageType) -> void:
	if _state == EnemyState.DEATH:
		return

	# 闪白效果
	_flash_pain()

	# 切换到 PAIN 状态
	_transition_to(EnemyState.PAIN)


# ==============================================================================
# _flash_pain() — 受击闪白（子类可覆写）
# ==============================================================================
func _flash_pain() -> void:
	# 收集所有 MeshInstance3D 子节点，保存原始材质，换成白色
	for child in get_children():
		if child is MeshInstance3D:
			var mesh: MeshInstance3D = child
			if not _original_materials.has(mesh):
				_original_materials[mesh] = mesh.material_override
			var flash_mat := StandardMaterial3D.new()
			flash_mat.albedo_color = Color.WHITE
			flash_mat.emission_enabled = true
			flash_mat.emission = Color.WHITE
			flash_mat.emission_energy_multiplier = 0.5
			mesh.material_override = flash_mat

			# 用 Timer 在 pain_duration 秒后恢复
			var timer := get_tree().create_timer(enemy_data.pain_duration)
			timer.timeout.connect(_restore_material.bind(mesh))


# ==============================================================================
# _restore_material(mesh) — 恢复原始材质
# ==============================================================================
func _restore_material(mesh: MeshInstance3D) -> void:
	if _original_materials.has(mesh):
		mesh.material_override = _original_materials[mesh]


# ==============================================================================
# _on_died() — 死亡回调
# ==============================================================================
func _on_died() -> void:
	if _state == EnemyState.DEATH:
		return

	_transition_to(EnemyState.DEATH)

	# 禁用碰撞——尸体不挡路
	collision_layer = 0
	collision_mask = 0

	# 死亡视觉（子类覆写）
	_on_death_visual()

	# 通知外部（EnemyManager 等）
	enemy_died.emit(self)


# ==============================================================================
# _on_death_visual() — 死亡视觉（子类覆写）
# ==============================================================================
func _on_death_visual() -> void:
	# 默认：把所有 Mesh 变灰
	for child in get_children():
		if child is MeshInstance3D:
			var mesh: MeshInstance3D = child
			var death_mat := StandardMaterial3D.new()
			death_mat.albedo_color = Color(0.3, 0.3, 0.3)
			mesh.material_override = death_mat

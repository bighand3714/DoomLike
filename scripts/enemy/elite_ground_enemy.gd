# ==============================================================================
# EliteGroundEnemy — 地面近战敌人（精英）
# ==============================================================================
# 大型模型、高血量、高重量。攻击前摇更明显但伤害更高。
# 近战三段式攻击(PREPARE→ACTIVE→RECOVER)，PREPARE时红灯闪烁。
# 距离档位路由：SUPER_FAR→跑步 / FAR/MEDIUM→行走 / CLOSE/MELEE→攻击。
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


# ==============================================================================
# AI — 距离档位路由
# ==============================================================================
func _ai_tick() -> void:
	if _player == null or enemy_data == null:
		return
	if _is_in_attack_state():
		return
	if _state in [EnemyState.SPAWNING, EnemyState.STUNNED, EnemyState.GRABBED, EnemyState.PAIN, EnemyState.KNOCKED_DOWN, EnemyState.EXECUTED, EnemyState.DEATH]:
		return

	var bracket: int = get_player_distance_bracket()
	match bracket:
		DistanceBracket.SUPER_FAR:
			if _state != EnemyState.RUNNING:
				_transition_to(EnemyState.RUNNING)
		DistanceBracket.FAR, DistanceBracket.MEDIUM:
			if _state != EnemyState.WALKING:
				_transition_to(EnemyState.WALKING)
		DistanceBracket.CLOSE:
			if randf() < 0.55 and _attack_cooldown_timer <= 0.0:
				_transition_to(EnemyState.ATTACK_PREPARE)
			elif _state != EnemyState.WALKING:
				_transition_to(EnemyState.WALKING)
		DistanceBracket.MELEE:
			if randf() < 0.75 and _attack_cooldown_timer <= 0.0:
				_transition_to(EnemyState.ATTACK_PREPARE)


# ==============================================================================
# 状态视觉钩子
# ==============================================================================
func _state_entered(new_state: EnemyState) -> void:
	match new_state:
		EnemyState.ATTACK_PREPARE:
			_set_all_boxes_emission(Color.RED, 1.5)
		EnemyState.ATTACK_ACTIVE:
			pass


func _state_exit(old_state: EnemyState) -> void:
	match old_state:
		EnemyState.ATTACK_PREPARE:
			_set_all_boxes_emission(Color.BLACK, 0.0)


# ==============================================================================
# 受伤 — Counter 支持
# ==============================================================================
func _on_damaged(amount: float, type: WeaponData.DamageType) -> void:
	if _state == EnemyState.DEATH:
		return

	if _damage_mark_timer > 0.0:
		amount *= _damage_mark_multiplier
		_damage_mark_multiplier = 1.0
		_damage_mark_timer = 0.0

	if _current_armor > 0.0:
		var absorbed: float = deplete_armor(amount)
		amount -= absorbed
		if absorbed > 0.0 and _damageable != null:
			_damageable.health = minf(_damageable.health + absorbed, _damageable.max_health)
		if amount <= 0.0:
			_flash_pain(Color(0.6, 0.6, 0.7))
			return

	if _state == EnemyState.ATTACK_ACTIVE:
		GameBus.counter_triggered.emit(self, global_position)
		_current_armor = 0.0
		_stun = enemy_data.max_stun
		if not _is_stun_full:
			_is_stun_full = true
			_stun_full_timer = enemy_data.stun_full_duration
			stun_filled.emit(self)
		_flash_pain(Color(0.3, 0.7, 1.0))
		_transition_to(EnemyState.STUNNED)
		return

	if _state != EnemyState.STUNNED and _state != EnemyState.GRABBED:
		_transition_to(EnemyState.PAIN)

	_flash_pain(Color.WHITE)


# ==============================================================================
# 工具
# ==============================================================================
func _set_all_boxes_emission(color: Color, energy: float) -> void:
	for child in get_children():
		if child is CSGShape3D:
			var mat: StandardMaterial3D = child.material_override
			if mat != null:
				mat.emission_enabled = energy > 0.0
				mat.emission = color
				mat.emission_energy_multiplier = energy


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

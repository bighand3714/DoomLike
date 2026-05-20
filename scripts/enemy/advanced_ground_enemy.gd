# ==============================================================================
# AdvancedGroundEnemy — 地面近战敌人（高级）
# ==============================================================================
# 更快、更高血量。近战三段式攻击(PREPARE→ACTIVE→RECOVER)。
# 距离档位路由：SUPER_FAR→跑步 / FAR/MEDIUM→行走 / CLOSE/MELEE→攻击。
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
			if randf() < 0.6 and _attack_cooldown_timer <= 0.0:
				_transition_to(EnemyState.ATTACK_PREPARE)
			elif _state != EnemyState.WALKING:
				_transition_to(EnemyState.WALKING)
		DistanceBracket.MELEE:
			if randf() < 0.8 and _attack_cooldown_timer <= 0.0:
				_transition_to(EnemyState.ATTACK_PREPARE)


# ==============================================================================
# 状态视觉钩子
# ==============================================================================
func _state_entered(new_state: EnemyState) -> void:
	match new_state:
		EnemyState.ATTACK_PREPARE:
			_set_all_boxes_emission(Color.ORANGE_RED, 1.2)
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

# ==============================================================================
# AdvancedFlyingEnemy — 空中近战敌人（高级）
# ==============================================================================
# 速度更快、体重更高。保持悬浮高度后靠近玩家近战。
# 距离档位路由：FAR→飞向玩家 / MEDIUM→盘旋绕圈 / CLOSE/MELEE→俯冲攻击。
# 三段式攻击：PREPARE(翅膀发光)→ACTIVE(俯冲伤害)→RECOVER(拉回高度)。
# 外观：橙色较大体型 + 更大翅膀标志
# ==============================================================================

extends "res://scripts/enemy/enemy.gd"
class_name AdvancedFlyingEnemy


func _ready() -> void:
	if enemy_data == null:
		enemy_data = load("res://assets/enemies/advanced_flying_enemy.tres")
	super()


func _setup_model() -> void:
	for child in get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			if child.name != "Damageable":
				child.queue_free()

	var c: Color = enemy_data.model_color if enemy_data != null else Color(1.0, 0.45, 0.05)

	# 身体
	_add_box(Vector3(0, 0.55, 0), Vector3(0.7, 0.7, 0.5), c)
	# 头部
	_add_box(Vector3(0, 1.05, 0), Vector3(0.38, 0.3, 0.3), c.darkened(0.1))
	# 眼睛（红色发光）
	_add_box(Vector3(-0.1, 1.1, -0.17), Vector3(0.08, 0.06, 0.02), Color.RED, true)
	_add_box(Vector3(0.1, 1.1, -0.17), Vector3(0.08, 0.06, 0.02), Color.RED, true)
	# 大翅膀
	_add_box(Vector3(-0.55, 0.55, 0), Vector3(0.1, 0.45, 0.7), c.darkened(0.18))
	_add_box(Vector3(0.55, 0.55, 0), Vector3(0.1, 0.45, 0.7), c.darkened(0.18))
	# 尾部
	_add_box(Vector3(0, 0.25, 0.3), Vector3(0.12, 0.12, 0.3), c.darkened(0.22))
	# 角
	_add_box(Vector3(-0.12, 1.25, 0), Vector3(0.06, 0.15, 0.06), Color(0.15, 0.15, 0.15))
	_add_box(Vector3(0.12, 1.25, 0), Vector3(0.06, 0.15, 0.06), Color(0.15, 0.15, 0.15))

	_add_collision(0.45, 1.3, 0.65)


# ==============================================================================
# AI — 距离档位路由（飞行近战版）
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
		DistanceBracket.SUPER_FAR, DistanceBracket.FAR:
			_fly_towards_player(enemy_data.move_speed)
		DistanceBracket.MEDIUM:
			_fly_strafe_around_player(enemy_data.move_speed * 0.5)
			if _attack_cooldown_timer <= 0.0 and randf() < 0.3:
				_transition_to(EnemyState.ATTACK_PREPARE)
		DistanceBracket.CLOSE, DistanceBracket.MELEE:
			if _attack_cooldown_timer <= 0.0:
				_transition_to(EnemyState.ATTACK_PREPARE)
			else:
				_fly_towards_player(enemy_data.move_speed * 0.4)


func _fly_towards_player(speed: float) -> void:
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dir := to_player.normalized() if to_player.length_squared() > 0.01 else Vector3.FORWARD
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	var target_y: float = _player.global_position.y + enemy_data.hover_height
	velocity.y = clampf((target_y - global_position.y) * 3.0, -enemy_data.vertical_move_speed, enemy_data.vertical_move_speed)
	_face_player_flat()


func _fly_strafe_around_player(speed: float) -> void:
	var dir := _get_player_flat_direction()
	velocity.x = -dir.z * speed
	velocity.z = dir.x * speed
	var target_y: float = _player.global_position.y + enemy_data.hover_height
	velocity.y = clampf((target_y - global_position.y) * 3.0, -enemy_data.vertical_move_speed, enemy_data.vertical_move_speed)
	_face_player_flat()


# ==============================================================================
# 状态覆写 — 攻击俯冲
# ==============================================================================
func _state_attack_prepare(delta: float) -> void:
	_fly_towards_player(enemy_data.move_speed * 1.3)
	super._state_attack_prepare(delta)

func _state_attack_recover(delta: float) -> void:
	velocity.x *= 0.3
	velocity.z *= 0.3
	var target_y: float = _player.global_position.y + enemy_data.hover_height
	velocity.y = clampf((target_y - global_position.y) * 2.0, -enemy_data.vertical_move_speed, enemy_data.vertical_move_speed)
	super._state_attack_recover(delta)


# ==============================================================================
# 状态视觉钩子
# ==============================================================================
func _state_entered(new_state: EnemyState) -> void:
	match new_state:
		EnemyState.ATTACK_PREPARE:
			_set_wing_emission(Color.RED, 1.5)
		EnemyState.ATTACK_ACTIVE:
			pass


func _state_exit(old_state: EnemyState) -> void:
	match old_state:
		EnemyState.ATTACK_PREPARE:
			_set_wing_emission(Color.BLACK, 0.0)


# ==============================================================================
# 受伤 — Counter 支持
# ==============================================================================
func _on_damaged(amount: float, _type: WeaponData.DamageType) -> void:
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
func _set_wing_emission(color: Color, energy: float) -> void:
	for child in get_children():
		if child is CSGShape3D:
			if child.position.x < -0.3 or child.position.x > 0.3:
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

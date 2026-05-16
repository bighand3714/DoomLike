# ==============================================================================
# StandardEnemy — 标准敌人（跳跃攻击）
# ==============================================================================
class_name StandardEnemy extends Enemy

var _jump_velocity: Vector3 = Vector3.ZERO
var _jump_target: Vector3 = Vector3.ZERO
var _jump_origin: Vector3 = Vector3.ZERO
var _original_scale: Vector3 = Vector3.ONE


func _setup_model() -> void:
	var mat := StandardMaterial3D.new()
	if enemy_data != null:
		mat.albedo_color = enemy_data.model_color
	else:
		mat.albedo_color = Color(1.0, 0.2, 0.1)

	# 身体：红色长方体
	var body := CSGBox3D.new()
	body.name = "Body"
	body.size = Vector3(1.0, 1.8, 0.6)
	body.position = Vector3(0, 0.9, 0)
	body.material_override = mat
	add_child(body)

	# 头部小方块
	var head := CSGBox3D.new()
	head.name = "Head"
	head.size = Vector3(0.5, 0.4, 0.5)
	head.position = Vector3(0, 1.95, 0)
	head.material_override = mat
	add_child(head)

	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collision.shape = capsule
	collision.position = Vector3(0, 0.9, 0)
	add_child(collision)

	_original_scale = scale


# 覆写攻击：跳跃攻击三段式
func _state_attack(delta: float) -> void:
	_face_player_flat()

	match _attack_phase:
		0:  # Windup：下蹲 + 变亮
			_state_timer += delta
			if _state_timer == delta:  # 第一帧
				# 下蹲
				scale = Vector3(_original_scale.x, _original_scale.y * 0.6, _original_scale.z)
				# 变亮
				_set_windup_glow(true)
			if _state_timer >= enemy_data.attack_windup:
				_attack_phase = 1
				_state_timer = 0.0
				# 锁定跳跃目标
				_jump_origin = global_position
				_jump_target = _player.global_position
				_jump_target.y = global_position.y  # 水平跳跃，Apex 由 vertical 速度控制
				# 计算跳跃速度
				var jump_dist := _jump_target.distance_to(_jump_origin)
				var jump_time := enemy_data.attack_duration
				if jump_time > 0.0:
					_jump_velocity = (_jump_target - _jump_origin) / jump_time
					_jump_velocity.y = 12.0  # 垂直初速，抛物线 apex ~3-4m
				scale = _original_scale

		1:  # Jump：抛物线跳跃
			_state_timer += delta
			_jump_velocity.y -= 20.0 * delta  # 重力
			velocity = _jump_velocity
			move_and_slide()

			# 检测与玩家距离
			if global_position.distance_to(_player.global_position) < 1.5:
				_damage_player(enemy_data.attack_damage, WeaponData.DamageType.MELEE)

			if _state_timer >= enemy_data.attack_duration:
				_attack_phase = 2
				_state_timer = 0.0
				velocity = Vector3.ZERO
				_set_windup_glow(false)

		2:  # Recovery：落地硬直
			_state_timer += delta
			if _state_timer >= enemy_data.attack_recovery:
				_attack_cooldown_timer = enemy_data.attack_cooldown
				_transition_to(EnemyState.CHASE)


# Windup 变亮
func _set_windup_glow(glow: bool) -> void:
	for child in get_children():
		if child is CSGBox3D:
			var geo: CSGBox3D = child
			if glow:
				var flash_mat := StandardMaterial3D.new()
				flash_mat.albedo_color = enemy_data.model_color.lightened(0.3)
				flash_mat.emission_enabled = true
				flash_mat.emission = enemy_data.model_color
				flash_mat.emission_energy_multiplier = 0.6
				geo.material_override = flash_mat
			else:
				geo.material_override = null


# 覆写受伤：Windup 阶段受击打断跳跃，Recovery 阶段额外眩晕
func _on_damaged(amount: float, type: WeaponData.DamageType) -> void:
	if _state == EnemyState.DEATH:
		return

	if _state == EnemyState.ATTACK:
		# Windup 阶段可打断
		if _attack_phase == 0:
			_set_windup_glow(false)
			scale = _original_scale
			velocity = Vector3.ZERO
		# Recovery 阶段额外眩晕
		elif _attack_phase == 2:
			apply_stun(amount * 1.5)
		# 跳跃空中击退增强
		elif _attack_phase == 1:
			_knockback_velocity *= 1.5

	if type == WeaponData.DamageType.MELEE:
		_flash_pain(Color(0.5, 0.5, 0.5))
	else:
		_flash_pain(Color.WHITE)

	if _state != EnemyState.STUNNED and _state != EnemyState.GRABBED:
		_transition_to(EnemyState.PAIN)

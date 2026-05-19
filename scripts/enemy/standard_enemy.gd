# ==============================================================================
# StandardEnemy — 标准敌人（跳跃攻击）
# ==============================================================================
class_name StandardEnemy extends Enemy

var _jump_velocity: Vector3 = Vector3.ZERO
var _has_hit_player: bool = false  # 防止跳跃攻击多帧重复伤害




# 覆写攻击：跳跃攻击三段式
func _state_attack(delta: float) -> void:
	_face_player_flat()

	match _attack_phase:
		0:  # Windup
			_state_timer += delta
			if _state_timer == delta:
				_set_windup_glow(true)
			if _state_timer >= enemy_data.attack_windup:
				_attack_phase = 1
				_state_timer = 0.0
				# 跳跃：快速冲向玩家前方（不跳到身后），低高度
				_has_hit_player = false  # 每跳只伤害一次
				var to_player: Vector3 = _player.global_position - global_position
				to_player.y = 0.0
				# 目标落点：玩家前方 2m 处
				var target_pos: Vector3 = _player.global_position - to_player.normalized() * 2.0
				var to_target: Vector3 = target_pos - global_position
				to_target.y = 0.0
				var jump_time: float = 0.35
				_jump_velocity = to_target / jump_time
				_jump_velocity.y = 7.0
				_set_windup_glow(false)

		1:  # Jump + 下落直到落地
			_jump_velocity.y -= 20.0 * delta
			velocity = _jump_velocity
			move_and_slide()
			_state_timer += delta
			if not _has_hit_player and global_position.distance_to(_player.global_position) < 1.5:
				_has_hit_player = true
				_damage_player(enemy_data.attack_damage, WeaponData.DamageType.MELEE)
			if is_on_floor() and _state_timer > 0.3:
				_attack_phase = 2
				_state_timer = 0.0

		2:  # Recovery 落地硬直
			velocity = Vector3.ZERO
			_state_timer += delta
			if _state_timer >= enemy_data.attack_recovery:
				_attack_cooldown_timer = enemy_data.attack_cooldown
				_transition_to(EnemyState.CHASE)

var _glow_originals: Dictionary = {}

# Windup 变亮
func _set_windup_glow(glow: bool) -> void:
	for child in get_children():
		if child is CSGShape3D:
			var geo: CSGShape3D = child
			if glow:
				_glow_originals[geo.get_instance_id()] = geo.material_override
				var flash_mat := StandardMaterial3D.new()
				flash_mat.albedo_color = enemy_data.model_color.lightened(0.3)
				flash_mat.emission_enabled = true
				flash_mat.emission = enemy_data.model_color
				flash_mat.emission_energy_multiplier = 0.6
				geo.material_override = flash_mat
			else:
				geo.material_override = _glow_originals.get(geo.get_instance_id(), null)


# 覆写受伤：Windup 阶段受击打断跳跃，Recovery 阶段额外眩晕
func _on_damaged(amount: float, type: WeaponData.DamageType) -> void:
	if _state == EnemyState.DEATH:
		return

	# 增伤标记加成（继承自基类）
	if _damage_mark_timer > 0.0:
		amount *= _damage_mark_multiplier
		_damage_mark_multiplier = 1.0
		_damage_mark_timer = 0.0

	if _state == EnemyState.ATTACK:
		# Counter 触发！
		GameBus.counter_triggered.emit(self, global_position)
		# Windup 阶段可打断
		if _attack_phase == 0:
			_set_windup_glow(false)
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

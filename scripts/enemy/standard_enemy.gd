# ==============================================================================
# StandardEnemy — 标准敌人（跳跃攻击）
# ==============================================================================
# 跳跃攻击三段式：PREPARE(蓄力发光)→ACTIVE(起跳空中)→RECOVER(落地硬直)。
# 空中阶段为 Counter 窗口。
# 距离档位路由：FAR→行走接近 / CLOSE→跳跃攻击 / MELEE→短跳后撤。
# ==============================================================================
class_name StandardEnemy extends Enemy

var _jump_velocity: Vector3 = Vector3.ZERO
var _has_hit_player: bool = false
var _glow_originals: Dictionary = {}


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
		DistanceBracket.SUPER_FAR, DistanceBracket.FAR, DistanceBracket.MEDIUM:
			if _state != EnemyState.WALKING:
				_transition_to(EnemyState.WALKING)
		DistanceBracket.CLOSE:
			if _attack_cooldown_timer <= 0.0:
				_transition_to(EnemyState.ATTACK_PREPARE)
			elif _state != EnemyState.WALKING:
				_transition_to(EnemyState.WALKING)
		DistanceBracket.MELEE:
			if _attack_cooldown_timer <= 0.0:
				_transition_to(EnemyState.ATTACK_PREPARE)
			else:
				_move_away_from_player(0.0, enemy_data.move_speed * 0.5)


# ==============================================================================
# 三段式跳跃攻击
# ==============================================================================
func _state_attack_prepare(delta: float) -> void:
	# Windup：发光蓄力
	_face_player_flat()
	velocity = Vector3.ZERO
	if _state_timer == 0.0:
		_set_windup_glow(true)
	_state_timer += delta
	if _state_timer >= enemy_data.attack_windup:
		# 起跳
		_has_hit_player = false
		_set_windup_glow(false)
		var to_player: Vector3 = _player.global_position - global_position
		to_player.y = 0.0
		var target_pos: Vector3 = _player.global_position - to_player.normalized() * 2.0
		var to_target: Vector3 = target_pos - global_position
		to_target.y = 0.0
		var jump_time: float = 0.35
		_jump_velocity = to_target / jump_time
		_jump_velocity.y = 7.0
		_transition_to(EnemyState.ATTACK_ACTIVE)


func _state_attack_active(delta: float) -> void:
	# 空中跳跃
	_jump_velocity.y -= 20.0 * delta
	velocity = _jump_velocity
	move_and_slide()
	_state_timer += delta
	if not _has_hit_player and global_position.distance_to(_player.global_position) < 1.5:
		_has_hit_player = true
		_damage_player(enemy_data.attack_damage, WeaponData.DamageType.MELEE)
	if is_on_floor() and _state_timer > 0.3:
		_transition_to(EnemyState.ATTACK_RECOVER)


func _state_attack_recover(delta: float) -> void:
	# 落地硬直
	velocity = Vector3.ZERO
	_state_timer += delta
	if _state_timer >= enemy_data.attack_recovery:
		_attack_cooldown_timer = enemy_data.attack_cooldown
		_transition_to(EnemyState.IDLE)


# ==============================================================================
# 状态视觉钩子
# ==============================================================================
func _state_exit(old_state: EnemyState) -> void:
	match old_state:
		EnemyState.ATTACK_PREPARE:
			_set_windup_glow(false)


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


# ==============================================================================
# 受伤 — Counter 支持（空中阶段 = Counter 窗口）
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

	# PREPARE 阶段受击：打断蓄力
	if _state == EnemyState.ATTACK_PREPARE:
		_set_windup_glow(false)
		velocity = Vector3.ZERO
		_flash_pain(Color(0.7, 0.7, 0.3))
		_transition_to(EnemyState.PAIN)
		return

	# ACTIVE(空中跳跃) = Counter 窗口
	if _state == EnemyState.ATTACK_ACTIVE:
		GameBus.counter_triggered.emit(self, global_position)
		_stun = enemy_data.max_stun
		if not _is_stun_full:
			_is_stun_full = true
			_stun_full_timer = enemy_data.stun_full_duration
			stun_filled.emit(self)
		_flash_pain(Color(0.3, 0.7, 1.0))
		_knockback_velocity *= 1.5
		_transition_to(EnemyState.STUNNED)
		return

	if _state != EnemyState.STUNNED and _state != EnemyState.GRABBED:
		_transition_to(EnemyState.PAIN)

	_flash_pain(Color.WHITE)

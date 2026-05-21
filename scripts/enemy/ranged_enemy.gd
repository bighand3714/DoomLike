# ==============================================================================
# RangedEnemy — 地面远程敌人（普通）
# ==============================================================================
# 使用慢速投射物攻击。到达中距离后停止，太近时后退。
# 距离档位路由：FAR→接近 / MEDIUM→站定射击 / CLOSE/MELEE→后退射击。
# 三段式攻击：PREPARE(枪口发光瞄准)→ACTIVE(发射弹丸)→RECOVER(收枪)。
# 外观：蓝色瘦长人形 + 枪管
# ==============================================================================

extends "res://scripts/enemy/enemy.gd"
class_name RangedEnemy


func _ready() -> void:
	if enemy_data == null:
		enemy_data = load("res://assets/enemies/ranged_enemy.tres")
	super()


func _setup_model() -> void:
	for child in get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			if child.name != "Damageable":
				child.queue_free()

	var c: Color = enemy_data.model_color if enemy_data != null else Color(0.2, 0.35, 0.8)

	# 身体（较瘦）
	_add_box(Vector3(0, 1.05, 0), Vector3(0.6, 0.75, 0.35), c)
	# 头部
	_add_box(Vector3(0, 1.6, 0), Vector3(0.32, 0.28, 0.28), c.darkened(0.12))
	# 单眼（瞄准镜风格）
	_add_box(Vector3(0, 1.63, -0.15), Vector3(0.1, 0.06, 0.02), Color.RED, true)
	# 手臂
	_add_box(Vector3(-0.4, 1.05, 0), Vector3(0.16, 0.6, 0.16), c.darkened(0.08))
	_add_box(Vector3(0.4, 1.05, 0), Vector3(0.16, 0.6, 0.16), c.darkened(0.08))
	# 枪管（前方突出）
	_add_box(Vector3(0.5, 1.05, -0.25), Vector3(0.1, 0.1, 0.45), Color(0.12, 0.12, 0.15))
	# 腿
	_add_box(Vector3(-0.16, 0.4, 0), Vector3(0.2, 0.55, 0.2), c.darkened(0.18))
	_add_box(Vector3(0.16, 0.4, 0), Vector3(0.2, 0.55, 0.2), c.darkened(0.18))

	_add_collision(0.35, 1.75, 0.95)


# ==============================================================================
# AI — 距离档位路由（远程版）
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
			if _state != EnemyState.WALKING:
				_transition_to(EnemyState.WALKING)
		DistanceBracket.MEDIUM:
			# 理想射程：站定射击
			velocity = Vector3.ZERO
			_face_player_flat()
			if randf() < 0.5 and _attack_cooldown_timer <= 0.0:
				_transition_to(EnemyState.ATTACK_PREPARE)
		DistanceBracket.CLOSE:
			# 太近：后退 + 射击
			if randf() < 0.5 and _attack_cooldown_timer <= 0.0 and _state != EnemyState.ATTACK_PREPARE:
				_transition_to(EnemyState.ATTACK_PREPARE)
			elif _state == EnemyState.ATTACK_PREPARE:
				_move_away_from_player(0.0, enemy_data.move_speed * 0.5)
			else:
				_move_away_from_player(0.0, enemy_data.move_speed * 0.5)
		DistanceBracket.MELEE:
			# 贴身：快速后撤
			if randf() < 0.5 and _attack_cooldown_timer <= 0.0 and _state != EnemyState.ATTACK_PREPARE:
				_transition_to(EnemyState.ATTACK_PREPARE)
			elif _state == EnemyState.ATTACK_PREPARE:
				_move_away_from_player(0.0, enemy_data.move_speed * 0.8)
			else:
				_move_away_from_player(0.0, enemy_data.move_speed * 0.8)


# ==============================================================================
# 状态覆写 — 攻击时停步
# ==============================================================================
func _state_attack_prepare(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	super._state_attack_prepare(delta)


# ==============================================================================
# 状态视觉钩子
# ==============================================================================
func _state_entered(new_state: EnemyState) -> void:
	match new_state:
		EnemyState.ATTACK_PREPARE:
			_set_gun_barrels_emission(Color.ORANGE_RED, 1.2)
		EnemyState.ATTACK_ACTIVE:
			pass


func _state_exit(old_state: EnemyState) -> void:
	match old_state:
		EnemyState.ATTACK_PREPARE:
			_set_gun_barrels_emission(Color.BLACK, 0.0)


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
func _set_gun_barrels_emission(color: Color, energy: float) -> void:
	for child in get_children():
		if child is CSGShape3D and "name" in child:
			if "barrel" in child.name.to_lower() or "gun" in child.name.to_lower():
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

# ==============================================================================
# DemonSoldier — 恶魔士兵
# ==============================================================================
# 远程 hitscan 攻击（瞬时命中），有 0.15s 举枪前摇。
# 距离档位路由：FAR→接近 / MEDIUM→站定射击 / CLOSE/MELEE→后退射击。
# 三段式攻击：PREPARE(举枪瞄准)→ACTIVE(开火hitscan)→RECOVER(收枪)。
# 外观：灰色装甲 CSG 人形 + 红色护目镜 + 枪
# ==============================================================================

extends "res://scripts/enemy/enemy.gd"
class_name DemonSoldier


func _ready() -> void:
	if enemy_data == null:
		enemy_data = load("res://assets/enemies/demon_soldier.tres")
	super()


func _setup_model() -> void:
	for child in get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			if child.name != "Damageable":
				child.queue_free()

	var body := _make_csg_box(Vector3(0, 1.2, 0), Vector3(0.9, 0.9, 0.5), Color(0.35, 0.35, 0.4))
	body.name = "Body"
	var left_shoulder := _make_csg_box(Vector3(-0.6, 1.45, 0), Vector3(0.3, 0.3, 0.35), Color(0.4, 0.4, 0.45))
	left_shoulder.name = "LeftShoulder"
	var right_shoulder := _make_csg_box(Vector3(0.6, 1.45, 0), Vector3(0.3, 0.3, 0.35), Color(0.4, 0.4, 0.45))
	right_shoulder.name = "RightShoulder"
	var head := _make_csg_box(Vector3(0, 1.95, 0), Vector3(0.45, 0.4, 0.4), Color(0.3, 0.3, 0.35))
	head.name = "Head"
	var visor := _make_csg_box(Vector3(0, 1.97, -0.21), Vector3(0.3, 0.12, 0.02), Color.RED)
	visor.name = "Visor"
	var left_arm := _make_csg_box(Vector3(-0.6, 1.1, 0), Vector3(0.25, 0.8, 0.25), Color(0.33, 0.33, 0.38))
	left_arm.name = "LeftArm"
	var right_arm := _make_csg_box(Vector3(0.6, 1.1, 0), Vector3(0.25, 0.8, 0.25), Color(0.33, 0.33, 0.38))
	right_arm.name = "RightArm"
	var gun := _make_csg_box(Vector3(0.85, 1.1, -0.2), Vector3(0.12, 0.12, 0.5), Color(0.15, 0.15, 0.18))
	gun.name = "Gun"
	var left_leg := _make_csg_box(Vector3(-0.25, 0.4, 0), Vector3(0.3, 0.65, 0.3), Color(0.33, 0.33, 0.38))
	left_leg.name = "LeftLeg"
	var right_leg := _make_csg_box(Vector3(0.25, 0.4, 0), Vector3(0.3, 0.65, 0.3), Color(0.33, 0.33, 0.38))
	right_leg.name = "RightLeg"

	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 2.1
	collision.shape = capsule
	collision.position = Vector3(0, 1.2, 0)
	add_child(collision)


# ==============================================================================
# AI — 距离档位路由（远程 hitscan 版）
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
			velocity = Vector3.ZERO
			_face_player_flat()
			if randf() < enemy_data.attack_probability and _attack_cooldown_timer <= 0.0:
				_transition_to(EnemyState.ATTACK_PREPARE)
		DistanceBracket.CLOSE:
			if randf() < enemy_data.attack_probability and _attack_cooldown_timer <= 0.0 and _state != EnemyState.ATTACK_PREPARE:
				_transition_to(EnemyState.ATTACK_PREPARE)
			elif _state == EnemyState.ATTACK_PREPARE:
				_move_away_from_player(0.0, enemy_data.move_speed * 0.5)
			else:
				_move_away_from_player(0.0, enemy_data.move_speed * 0.5)
		DistanceBracket.MELEE:
			if randf() < enemy_data.attack_probability and _attack_cooldown_timer <= 0.0 and _state != EnemyState.ATTACK_PREPARE:
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
			_set_visor_glow(true)
		EnemyState.ATTACK_ACTIVE:
			pass


func _state_exit(old_state: EnemyState) -> void:
	match old_state:
		EnemyState.ATTACK_PREPARE:
			_set_visor_glow(false)


# ==============================================================================
# 攻击执行 — hitscan 射击
# ==============================================================================
func _execute_attack() -> void:
	if _player == null:
		return

	var origin := global_position + Vector3(0, 1.85, 0)
	var direction := (_player.global_position + Vector3(0, 1.0, 0) - origin).normalized()
	var end := origin + direction * 50.0

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = 1
	query.exclude = [self]

	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return

	var target: Node = result.collider
	if _is_player_target(target):
		_damage_player(enemy_data.attack_damage, WeaponData.DamageType.HITSCAN)


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
func _set_visor_glow(glow: bool) -> void:
	for child in get_children():
		if child is CSGBox3D and "name" in child and child.name.to_lower() == "visor":
			var mat: StandardMaterial3D = child.material_override
			if mat != null:
				mat.emission_enabled = glow
				if glow:
					mat.emission = Color.RED
					mat.emission_energy_multiplier = 2.0


func _make_csg_box(pos: Vector3, size: Vector3, color: Color) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.position = pos
	box.size = size
	box.use_collision = false
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.5
	mat.metallic = 0.3
	box.material_override = mat
	add_child(box)
	return box


func _on_death_visual() -> void:
	for child in get_children():
		if child is CSGBox3D:
			var box: CSGBox3D = child
			var death_mat := StandardMaterial3D.new()
			death_mat.albedo_color = Color(0.2, 0.2, 0.22)
			box.material_override = death_mat

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.5, 0.5, 0.5), enemy_data.death_duration)
	tween.parallel().tween_property(self, "position:y", position.y - 0.4, enemy_data.death_duration)

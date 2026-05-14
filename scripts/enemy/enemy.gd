# ==============================================================================
# Enemy — 敌人基类（Phase 5 扩展）
# ==============================================================================
class_name Enemy extends CharacterBody3D

const EnemyDataClass = preload("res://scripts/enemy/enemy_data.gd")
const ProjectileClass = preload("res://scripts/enemy/projectile.gd")


enum EnemyState {
	SPAWNING, IDLE, CHASE, ATTACK, PAIN, STUNNED, GRABBED, EXECUTED, DEATH
}


signal enemy_died(enemy: Enemy)
signal stun_changed(current: float, max_value: float)
signal stun_filled(enemy: Enemy)


@export var enemy_data: Resource


var _state: EnemyState = EnemyState.IDLE
var _previous_state: EnemyState = EnemyState.IDLE
var _player: CharacterBody3D = null
var _damageable: Damageable
var _state_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _attack_phase: int = 0
var _sight_ray: RayCast3D
var _original_materials: Dictionary = {}

var _stun: float = 0.0
var _is_stun_full: bool = false
var _stun_full_timer: float = 0.0

var _knockback_velocity: Vector3 = Vector3.ZERO
var _grab_owner: Node3D = null

# 调试条（CSGBox3D，头顶）
var _debug_stun_bar: CSGBox3D = null
var _debug_stun_bg: CSGBox3D = null
var _debug_hp_bar: CSGBox3D = null
var _debug_hp_bg: CSGBox3D = null
const DEBUG_BAR_FULL := 0.5  # 满条宽度
const DEBUG_BAR_Y := 2.2     # 头顶高度


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		_player = get_node_or_null("/root/Main/Player") as CharacterBody3D

	_damageable = _get_or_create_damageable()
	_damageable.damaged.connect(_on_damaged)
	_damageable.died.connect(_on_died)

	_sight_ray = RayCast3D.new()
	_sight_ray.target_position = Vector3(0, 0, -10.0)
	_sight_ray.collision_mask = 1
	_sight_ray.enabled = false
	add_child(_sight_ray)

	var _has_model := false
	for child in get_children():
		if child is CSGBox3D or child is CSGPolygon3D or child is MeshInstance3D:
			_has_model = true
			break
	if not _has_model:
		_setup_model()

	_create_debug_bars()


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


func _setup_model() -> void:
	var mat := StandardMaterial3D.new()
	if enemy_data != null:
		mat.albedo_color = enemy_data.model_color
	else:
		mat.albedo_color = Color(1.0, 0.2, 0.2)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 1.8, 0.6)
	mesh.mesh = box
	mesh.position = Vector3(0, 0.9, 0)
	mesh.material_override = mat
	add_child(mesh)

	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collision.shape = capsule
	collision.position = Vector3(0, 0.9, 0)
	add_child(collision)


func _physics_process(delta: float) -> void:
	if enemy_data == null or _player == null:
		return

	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	if _stun > 0.0 and _state != EnemyState.STUNNED and _state != EnemyState.GRABBED:
		_stun -= enemy_data.stun_recovery_rate * delta
		if _stun < 0.0:
			_stun = 0.0

	if _knockback_velocity.length_squared() > 0.001:
		_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, 10.0 * delta)

	match _state:
		EnemyState.IDLE:
			_state_idle(delta)
		EnemyState.CHASE:
			_state_chase(delta)
		EnemyState.ATTACK:
			_state_attack(delta)
		EnemyState.PAIN:
			_state_pain(delta)
		EnemyState.STUNNED:
			_state_stunned(delta)
		EnemyState.GRABBED:
			_state_grabbed(delta)
		EnemyState.DEATH:
			_state_death(delta)

	if _state != EnemyState.DEATH and _state != EnemyState.GRABBED:
		velocity += _knockback_velocity

	_update_debug_bars()


func _transition_to(new_state: EnemyState) -> void:
	if _state == EnemyState.DEATH:
		return
	_previous_state = _state
	_state_exit(_state)
	_state = new_state
	_state_timer = 0.0
	_attack_phase = 0
	_state_entered(new_state)


func _state_entered(_new_state: EnemyState) -> void:
	pass

func _state_exit(_old_state: EnemyState) -> void:
	pass


func _state_idle(_delta: float) -> void:
	if _can_see_player():
		_transition_to(EnemyState.CHASE)


func _state_chase(delta: float) -> void:
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	if dist > enemy_data.sight_range * 1.5:
		_transition_to(EnemyState.IDLE)
		return

	if dist <= enemy_data.attack_range:
		_transition_to(EnemyState.ATTACK)
		return

	if enemy_data.preferred_range > 0.0 and dist < enemy_data.min_range:
		_move_away_from_player(delta, enemy_data.move_speed)
	else:
		_move_towards_player(delta, enemy_data.move_speed)

	# 飞行敌人：调整 Y 轴高度保持在玩家上方 hover_height
	if enemy_data.is_flying:
		var target_y: float = _player.global_position.y + enemy_data.hover_height
		var y_diff: float = target_y - global_position.y
		velocity.y = clampf(y_diff * 3.0, -enemy_data.vertical_move_speed, enemy_data.vertical_move_speed)
	else:
		velocity.y = 0.0

	_face_player_flat()
	move_and_slide()


# 攻击三段式：windup(前摇)→damage(伤害判定)→recovery(后摇)
# 前摇阶段敌人举枪/抬手但不开火，让玩家有反应时间。
# windup 结束后进入 damage 窗口才真正造成伤害。
# recovery 结束后才能再次攻击或切回追击。
func _state_attack(delta: float) -> void:
	_face_player_flat()

	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	match _attack_phase:
		0:  # windup——抬手/举枪，不开火
			_state_timer += delta
			if _state_timer >= enemy_data.attack_windup:
				_attack_phase = 1
				_state_timer = 0.0
		1:  # damage——判定窗口，实际造成伤害
			if _state_timer == 0.0:
				_execute_attack()
				_attack_cooldown_timer = enemy_data.attack_cooldown
			_state_timer += delta
			if _state_timer >= enemy_data.attack_duration:
				_attack_phase = 2
				_state_timer = 0.0
		2:  # recovery——收招，不能行动
			_state_timer += delta
			if _state_timer >= enemy_data.attack_recovery:
				_transition_to(EnemyState.CHASE)

	if dist > enemy_data.attack_range * 1.5:
		_transition_to(EnemyState.CHASE)


func _execute_attack() -> void:
	if _player == null:
		return

	var dist := _get_player_distance_xz()

	match enemy_data.damage_type:
		WeaponData.DamageType.MELEE:
			if dist <= enemy_data.attack_range * 1.3:
				_damage_player(enemy_data.attack_damage, WeaponData.DamageType.MELEE)

		WeaponData.DamageType.HITSCAN:
			_do_hitscan_attack()

		WeaponData.DamageType.PROJECTILE:
			_spawn_projectile_attack()


func _damage_player(amount: float, dtype: WeaponData.DamageType) -> void:
	var dmg := _player.get_node_or_null("Damageable")
	if dmg != null and dmg is Damageable:
		dmg.take_damage(amount, dtype)
	elif _player.has_method("take_damage"):
		_player.take_damage(amount, dtype)


func _do_hitscan_attack() -> void:
	var origin := global_position + Vector3(0, 1.5, 0)
	var dir := (_player.global_position + Vector3(0, 1.0, 0) - origin).normalized()
	var end: Vector3 = origin + dir * enemy_data.attack_range * 2.0

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = 1
	query.exclude = [self]

	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return

	if _is_player_target(result.collider):
		_damage_player(enemy_data.attack_damage, WeaponData.DamageType.HITSCAN)


func _spawn_projectile_attack() -> void:
	var proj: Area3D = ProjectileClass.new()
	proj.speed = 10.0
	proj.damage = enemy_data.attack_damage
	proj.damage_type = WeaponData.DamageType.PROJECTILE
	proj.lifetime = 5.0

	get_tree().root.add_child(proj)
	proj._setup_visual()

	var spawn_pos := global_position + Vector3(0, 1.5, 0)
	proj.global_position = spawn_pos

	var direction := (_player.global_position + Vector3(0, 1.0, 0) - spawn_pos).normalized()
	proj.setup(direction, self)


func _is_player_target(collider: Node) -> bool:
	if collider == _player:
		return true
	var p := collider.get_parent()
	while p != null:
		if p == _player:
			return true
		p = p.get_parent()
	return false


func _state_pain(delta: float) -> void:
	_state_timer += delta
	if _state_timer >= enemy_data.pain_duration:
		_transition_to(EnemyState.CHASE)

func _state_stunned(delta: float) -> void:
	_stun_full_timer -= delta
	if _stun_full_timer <= 0.0:
		_is_stun_full = false
		_stun = enemy_data.max_stun * 0.8
		_transition_to(EnemyState.CHASE)

func _state_grabbed(_delta: float) -> void:
	if _grab_owner == null or not is_instance_valid(_grab_owner):
		release_grab()

func _state_death(delta: float) -> void:
	_state_timer += delta
	if _state_timer >= enemy_data.death_duration:
		queue_free()


func _can_see_player() -> bool:
	if _player == null:
		return false
	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	if dist > enemy_data.sight_range:
		return false
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 1.5, 0),
		_player.global_position + Vector3(0, 1.0, 0)
	)
	query.collision_mask = 1
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return false
	var collider: Node = result.collider
	if collider == _player:
		return true
	var parent: Node = collider.get_parent()
	while parent != null:
		if parent == _player:
			return true
		parent = parent.get_parent()
	return false


func apply_stun(amount: float) -> void:
	if _state == EnemyState.DEATH or _state == EnemyState.EXECUTED:
		return
	var effective: float = amount * (1.0 - enemy_data.stun_resistance)
	_stun = clampf(_stun + effective, 0.0, enemy_data.max_stun)
	stun_changed.emit(_stun, enemy_data.max_stun)
	if _stun >= enemy_data.max_stun and not _is_stun_full:
		_is_stun_full = true
		_stun_full_timer = enemy_data.stun_full_duration
		stun_filled.emit(self)
		_transition_to(EnemyState.STUNNED)

func is_stunned_or_grabbable() -> bool:
	return _state == EnemyState.STUNNED or _is_stun_full


func apply_knockback(direction: Vector3, force: float) -> void:
	if _state == EnemyState.DEATH or _state == EnemyState.GRABBED or _state == EnemyState.EXECUTED:
		return
	var effective_force: float = force / max(enemy_data.weight, 0.1)
	effective_force *= (1.0 - enemy_data.knockback_resistance)
	_knockback_velocity += direction.normalized() * effective_force


func can_be_grabbed() -> bool:
	return _is_stun_full and _state != EnemyState.DEATH and _state != EnemyState.EXECUTED

func start_grab(grabber: Node3D) -> bool:
	if not can_be_grabbed():
		return false
	_grab_owner = grabber
	collision_layer = 0
	_transition_to(EnemyState.GRABBED)
	return true

func update_grabbed_position(target_transform: Transform3D, _delta: float) -> void:
	global_position = target_transform.origin
	rotation = target_transform.basis.get_euler()

func release_grab() -> void:
	_grab_owner = null
	collision_layer = 1
	_is_stun_full = false
	_stun = enemy_data.max_stun * 0.5
	_transition_to(EnemyState.CHASE)

func execute() -> void:
	_transition_to(EnemyState.EXECUTED)
	_damageable.health = 0.0
	_damageable.died.emit()


func _get_player_flat_direction() -> Vector3:
	var dir := _player.global_position - global_position
	dir.y = 0.0
	return dir.normalized() if dir.length_squared() > 0.01 else Vector3.FORWARD

func _get_player_distance_xz() -> float:
	var d := _player.global_position - global_position
	d.y = 0.0
	return d.length()

func _move_towards_player(_delta: float, speed: float) -> void:
	var dir := _get_player_flat_direction()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

func _move_away_from_player(_delta: float, speed: float) -> void:
	var dir := -_get_player_flat_direction()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

func _strafe_around_player(_delta: float, speed: float) -> void:
	var dir := _get_player_flat_direction()
	velocity.x = -dir.z * speed
	velocity.z = dir.x * speed

func _face_player_flat() -> void:
	var dir := _get_player_flat_direction()
	look_at(global_position + dir, Vector3.UP)


# ==============================================================================
# 受伤反馈——兼容 CSGBox3D/CSGPolygon3D 和 MeshInstance3D
# ==============================================================================
func _on_damaged(_amount: float, _type: WeaponData.DamageType) -> void:
	if _state == EnemyState.DEATH:
		return
	_flash_pain()
	if _state != EnemyState.STUNNED and _state != EnemyState.GRABBED:
		_transition_to(EnemyState.PAIN)

func _flash_pain() -> void:
	for child in get_children():
		var geo: Node3D = null
		if child is MeshInstance3D:
			geo = child
		elif child is CSGBox3D or child is CSGPolygon3D:
			geo = child
		if geo == null:
			continue

		# 保存原始材质（用 material_override 兜底）
		var key := geo.get_instance_id()
		if not _original_materials.has(key):
			_original_materials[key] = geo.material_override

		var flash_mat := StandardMaterial3D.new()
		flash_mat.albedo_color = Color.WHITE
		flash_mat.emission_enabled = true
		flash_mat.emission = Color.WHITE
		flash_mat.emission_energy_multiplier = 0.5
		geo.material_override = flash_mat

		var timer := get_tree().create_timer(enemy_data.pain_duration)
		timer.timeout.connect(_restore_material.bind(geo, key))

func _restore_material(geo: Node3D, key: int) -> void:
	if _original_materials.has(key):
		geo.material_override = _original_materials[key]

func _on_died() -> void:
	if _state == EnemyState.DEATH:
		return
	if _grab_owner != null:
		_grab_owner = null
	_transition_to(EnemyState.DEATH)
	collision_layer = 0
	collision_mask = 0
	_on_death_visual()
	enemy_died.emit(self)

func _on_death_visual() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.3, 0.1, 0.3), 0.3)
	for child in get_children():
		if child is MeshInstance3D or child is CSGBox3D or child is CSGPolygon3D:
			var geo: Node3D = child
			var death_mat := StandardMaterial3D.new()
			death_mat.albedo_color = Color(0.3, 0.3, 0.3)
			geo.material_override = death_mat


# ==============================================================================
# 调试条——左右缩进（不从中心缩），像真正的血条
# ==============================================================================
func _create_debug_bars() -> void:
	var bar_thick := 0.06
	var bar_z := 0.05

	# 眩晕条——背景 + 前景（黄），固定在左侧
	_debug_stun_bg = _make_bar("StunBarBG", Color(0.1, 0.1, 0.1), DEBUG_BAR_Y, bar_thick, bar_z)
	_debug_stun_bar = _make_bar("StunBar", Color(1.0, 0.9, 0.1), DEBUG_BAR_Y, bar_thick, bar_z + 0.03)
	var stun_mat := _debug_stun_bar.material as StandardMaterial3D
	if stun_mat != null:
		stun_mat.emission_enabled = true
		stun_mat.emission = Color(1.0, 0.9, 0.1)
		stun_mat.emission_energy_multiplier = 0.5

	# 血条——背景 + 前景（绿），在眩晕条下方
	_debug_hp_bg = _make_bar("HPBarBG", Color(0.1, 0.1, 0.1), DEBUG_BAR_Y - 0.1, bar_thick, bar_z)
	_debug_hp_bar = _make_bar("HPBar", Color(0.2, 0.9, 0.2), DEBUG_BAR_Y - 0.1, bar_thick, bar_z + 0.03)

func _make_bar(bar_name: String, color: Color, y: float, thick: float, z: float) -> CSGBox3D:
	var bar := CSGBox3D.new()
	bar.name = bar_name
	bar.size = Vector3(DEBUG_BAR_FULL, thick, 0.05)
	bar.position = Vector3(0.0, y, z)
	bar.use_collision = false
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bar.material = mat
	add_child(bar)
	return bar

func _update_debug_bars() -> void:
	if _debug_stun_bar != null and enemy_data != null:
		var ratio: float = _stun / enemy_data.max_stun
		var w: float = DEBUG_BAR_FULL * ratio
		_debug_stun_bar.size.x = w
		_debug_stun_bar.position.x = -(DEBUG_BAR_FULL - w) / 2.0  # 左对齐缩进

	if _debug_hp_bar != null and _damageable != null:
		var ratio: float = _damageable.health / _damageable.max_health
		var w: float = DEBUG_BAR_FULL * ratio
		_debug_hp_bar.size.x = w
		_debug_hp_bar.position.x = -(DEBUG_BAR_FULL - w) / 2.0  # 左对齐缩进

		var hp_mat := _debug_hp_bar.material as StandardMaterial3D
		if hp_mat != null:
			if ratio > 0.5:
				hp_mat.albedo_color = Color(0.2, 0.9, 0.2)
			elif ratio > 0.25:
				hp_mat.albedo_color = Color(1.0, 0.65, 0.1)
			else:
				hp_mat.albedo_color = Color(1.0, 0.15, 0.15)

# ==============================================================================
# Enemy — 敌人基类（Phase 5 扩展 + Phase 7 优化）
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

var _debug_stun_bar: MeshInstance3D = null
var _debug_hp_bar: MeshInstance3D = null
const DEBUG_BAR_FULL := 0.5
const DEBUG_BAR_Y := 2.2


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		_player = get_node_or_null("/root/Main/Player") as CharacterBody3D

	add_to_group("enemy")

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


# ==============================================================================
# IDLE → 距离检测（不再要求射线穿透，边界柱不会挡住发现玩家）
# ==============================================================================
func _state_idle(_delta: float) -> void:
	if _player == null:
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist <= enemy_data.sight_range:
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

	if enemy_data.is_flying:
		var target_y: float = _player.global_position.y + enemy_data.hover_height
		var y_diff: float = target_y - global_position.y
		velocity.y = clampf(y_diff * 3.0, -enemy_data.vertical_move_speed, enemy_data.vertical_move_speed)
	else:
		velocity.y = 0.0

	_face_player_flat()
	move_and_slide()


func _state_attack(delta: float) -> void:
	_face_player_flat()

	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	match _attack_phase:
		0:
			_state_timer += delta
			if _state_timer >= enemy_data.attack_windup:
				_attack_phase = 1
				_state_timer = 0.0
		1:
			if _state_timer == 0.0:
				_execute_attack()
				_attack_cooldown_timer = enemy_data.attack_cooldown
			_state_timer += delta
			if _state_timer >= enemy_data.attack_duration:
				_attack_phase = 2
				_state_timer = 0.0
		2:
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
	# 盾牌阻挡检测
	var grabbed: Node = null
	if _player.has_method("get_grabbed_enemy"):
		grabbed = _player.get_grabbed_enemy()
	if grabbed != null and is_instance_valid(grabbed):
		var to_enemy: Vector3 = _player.global_position.direction_to(global_position)
		var player_forward: Vector3 = -_player.global_transform.basis.z
		if to_enemy.dot(player_forward) > 0.35:
			var shield_dmg = grabbed.get_node_or_null("Damageable") as Damageable
			if shield_dmg != null:
				shield_dmg.take_damage(amount, dtype)
				GameBus.shield_block.emit()
				return

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


# ==============================================================================
# 死亡 —— 快速缩小 + 0.5 秒后消失
# ==============================================================================
func _state_death(delta: float) -> void:
	_state_timer += delta
	if _state_timer >= 0.5:
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


# ==============================================================================
# 眩晕 / 击退 / 抓取 / 处决
# ==============================================================================
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


# ==============================================================================
# 移动辅助
# ==============================================================================
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
# 受伤反馈
# ==============================================================================

## 公共方法：外部触发受击反馈（iron_whip 处决视觉效果用）
func trigger_on_damaged(_amount: float, _type: WeaponData.DamageType) -> void:
	_on_damaged(_amount, _type)


func _on_damaged(_amount: float, _type: WeaponData.DamageType) -> void:
	if _state == EnemyState.DEATH:
		return
	# 不同伤害类型不同颜色：近战(铁鞭)灰色，其他白色
	if _type == WeaponData.DamageType.MELEE:
		_flash_pain(Color(0.5, 0.5, 0.5))
	else:
		_flash_pain(Color.WHITE)
	if _state != EnemyState.STUNNED and _state != EnemyState.GRABBED:
		_transition_to(EnemyState.PAIN)


func _flash_pain(flash_color: Color = Color.WHITE) -> void:
	for child in get_children():
		var geo: Node3D = null
		if child is MeshInstance3D:
			geo = child
		elif child is CSGBox3D or child is CSGPolygon3D:
			geo = child
		if geo == null:
			continue

		var key := geo.get_instance_id()
		if not _original_materials.has(key):
			_original_materials[key] = geo.material_override

		var flash_mat := StandardMaterial3D.new()
		flash_mat.albedo_color = flash_color
		flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flash_mat.emission_enabled = true
		flash_mat.emission = flash_color
		flash_mat.emission_energy_multiplier = 0.8
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
	var shrink_time: float = minf(enemy_data.death_duration * 0.4, 0.5)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.3, 0.3, 0.3), shrink_time)
	for child in get_children():
		if child is MeshInstance3D or child is CSGBox3D or child is CSGPolygon3D:
			var geo: Node3D = child
			var death_mat := StandardMaterial3D.new()
			death_mat.albedo_color = Color(0.3, 0.3, 0.3)
			geo.material_override = death_mat


# ==============================================================================
# 调试条
# ==============================================================================
func _create_debug_bars() -> void:
	var bar_thick := 0.06
	# z 为负值：敌人正面是 -Z，负 Z 让血条在敌人前方可见
	var bar_z: float = -0.06

	# HP 血条（绿色，无黑底）
	_debug_hp_bar = _make_bar("HPBar", Color(0.2, 0.9, 0.2), DEBUG_BAR_Y - 0.1, bar_thick, bar_z)

	# 眩晕条（黄色，无黑底）
	_debug_stun_bar = _make_bar("StunBar", Color(1.0, 0.9, 0.1), DEBUG_BAR_Y, bar_thick, bar_z)
	var stun_mat := _debug_stun_bar.material_override as StandardMaterial3D
	if stun_mat != null:
		stun_mat.emission_enabled = true
		stun_mat.emission = Color(1.0, 0.9, 0.1)
		stun_mat.emission_energy_multiplier = 0.5


func _make_bar(bar_name: String, color: Color, y: float, thick: float, z: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = bar_name
	var box := BoxMesh.new()
	box.size = Vector3(DEBUG_BAR_FULL, thick, 0.05)
	mesh.mesh = box
	mesh.position = Vector3(0.0, y, z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	add_child(mesh)
	return mesh


func _update_debug_bars() -> void:
	if _debug_stun_bar != null and enemy_data != null:
		var ratio: float = _stun / enemy_data.max_stun
		var w: float = DEBUG_BAR_FULL * ratio
		var stun_box: BoxMesh = _debug_stun_bar.mesh
		stun_box.size.x = w
		_debug_stun_bar.position.x = -(DEBUG_BAR_FULL - w) / 2.0

	if _debug_hp_bar != null and _damageable != null:
		var ratio: float = _damageable.health / _damageable.max_health
		var w: float = DEBUG_BAR_FULL * ratio
		var hp_box: BoxMesh = _debug_hp_bar.mesh
		hp_box.size.x = w
		_debug_hp_bar.position.x = -(DEBUG_BAR_FULL - w) / 2.0

		var hp_mat := _debug_hp_bar.material_override as StandardMaterial3D
		if hp_mat != null:
			if ratio > 0.5:
				hp_mat.albedo_color = Color(0.2, 0.9, 0.2)
			elif ratio > 0.25:
				hp_mat.albedo_color = Color(1.0, 0.65, 0.1)
			else:
				hp_mat.albedo_color = Color(1.0, 0.15, 0.15)

# ==============================================================================
# Enemy — 敌人基类（Phase 5 扩展 + Phase 7 优化 + Roadmap 4 Counter/距离档位）
# ==============================================================================
class_name Enemy extends CharacterBody3D

const EnemyDataClass = preload("res://scripts/enemy/enemy_data.gd")
const ProjectileClass = preload("res://scripts/enemy/projectile.gd")


enum EnemyState {
	SPAWNING, IDLE, CHASE, ATTACK,
	WALKING, RUNNING,
	ATTACK_PREPARE, ATTACK_ACTIVE, ATTACK_RECOVER,
	DEFENDING,
	PAIN, STUNNED, GRABBED,
	KNOCKED_DOWN, EXECUTED, DEATH
}

## 距离档位枚举——全系统统一的五档距离判定
enum DistanceBracket {
	MELEE,        # < 1m     贴身
	CLOSE,        # 1~3m    近距离
	MEDIUM,       # 3~8m    中距离
	FAR,          # 8~25m   远距离
	SUPER_FAR     # > 25m   超远距离
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

var _cached_camera: Camera3D = null

## AI 检测计时器——每 detection_interval 秒执行一次决策
var _detection_timer: float = 0.0

## 增伤标记——下次受击消耗，倍率 + 剩余时间
var _damage_mark_multiplier: float = 1.0
var _damage_mark_timer: float = 0.0

## 定身剩余时间
var _snare_timer: float = 0.0

## 眩晕衰减延迟——受击后 1s 内不衰减，1s 后慢慢回落
var _stun_decay_delay: float = 0.0
var _stun_flash_toggle: bool = false  # 眩晕闪烁交替开关

## 每实例护甲值（从 enemy_data.armor 初始化，避免共享 Resource 变异）
var _current_armor: float = 0.0


var _debug_stun_bar: MeshInstance3D = null
var _debug_armor_bar: MeshInstance3D = null
var _debug_hp_bar: MeshInstance3D = null
const DEBUG_BAR_FULL := 0.5
const DEBUG_BAR_Y := 2.2


# ==============================================================================
# 距离档位工具方法
# ==============================================================================

## 根据目标位置返回距离档位（阈值从 EnemyData 读取）
func _get_distance_bracket(to_target: Vector3) -> int:
	var dist_xz: float = Vector2(to_target.x, to_target.z).length()
	if enemy_data != null:
		if dist_xz < enemy_data.bracket_melee_max:
			return DistanceBracket.MELEE
		elif dist_xz < enemy_data.bracket_close_max:
			return DistanceBracket.CLOSE
		elif dist_xz < enemy_data.bracket_medium_max:
			return DistanceBracket.MEDIUM
		elif dist_xz < enemy_data.bracket_far_max:
			return DistanceBracket.FAR
	else:
		if dist_xz < 1.0:
			return DistanceBracket.MELEE
		elif dist_xz < 3.0:
			return DistanceBracket.CLOSE
		elif dist_xz < 8.0:
			return DistanceBracket.MEDIUM
		elif dist_xz < 25.0:
			return DistanceBracket.FAR
	return DistanceBracket.SUPER_FAR

## 获取当前敌人与玩家的距离档位
func get_player_distance_bracket() -> int:
	if _player == null:
		return DistanceBracket.SUPER_FAR
	return _get_distance_bracket(_player.global_position - global_position)

## 判断当前是否处于攻击阶段（PREPARE / ACTIVE / RECOVER 全部视为 Counter 窗口）
func _is_in_attack_state() -> bool:
	return _state == EnemyState.ATTACK_PREPARE or _state == EnemyState.ATTACK_ACTIVE or _state == EnemyState.ATTACK_RECOVER or _state == EnemyState.ATTACK


func _is_off_screen() -> bool:
	if _cached_camera == null:
		return false
	return _cached_camera.is_position_behind(global_position + Vector3(0, 1.0, 0))


func _get_off_screen_factor() -> float:
	return 3.0 if _is_off_screen() else 1.0


func get_current_armor() -> float:
	return _current_armor


## 消耗护甲值，返回吸收的伤害量（每实例数据，不会影响其他同类型敌人）
func deplete_armor(amount: float) -> float:
	if _current_armor <= 0.0:
		return 0.0
	var absorbed: float = minf(amount, _current_armor)
	_current_armor -= absorbed
	return absorbed


# ==============================================================================
# _ready() — 初始化
# ==============================================================================
func _ready() -> void:
	_stun = 0.0
	_is_stun_full = false
	_stun_full_timer = 0.0
	_stun_decay_delay = 0.0
	if enemy_data != null:
		_current_armor = enemy_data.armor

	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		_player = get_node_or_null("/root/Main/Player") as CharacterBody3D

	_cached_camera = _player.get_node_or_null("Camera3D") as Camera3D

	add_to_group("enemy")

	# 向 EnemyManager 自注册（支持编辑器中手动放置敌人）
	_register_to_manager()

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
		if child is CSGShape3D or child is MeshInstance3D:
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


# ==============================================================================
# _physics_process(delta) — 主循环
# ==============================================================================
func _physics_process(delta: float) -> void:
	if enemy_data == null or _player == null:
		return

	var off_factor: float = _get_off_screen_factor()
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta / off_factor

	# 定身计时器
	if _snare_timer > 0.0:
		_snare_timer -= delta

	# 增伤标记计时器
	if _damage_mark_timer > 0.0:
		_damage_mark_timer -= delta
		if _damage_mark_timer <= 0.0:
			_damage_mark_multiplier = 1.0

	# 眩晕衰减延迟：受击后保持 1s 不变，1s 后慢慢回落
	if _stun_decay_delay > 0.0:
		_stun_decay_delay -= delta
	if _stun > 0.0 and _state != EnemyState.STUNNED and _state != EnemyState.GRABBED:
		if _stun_decay_delay <= 0.0:
			_stun -= enemy_data.stun_recovery_rate * delta
			if _stun < 0.0:
				_stun = 0.0

	if _knockback_velocity.length_squared() > 0.001:
		_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, 10.0 * delta)

	# --- AI 检测计时器：每 detection_interval 秒执行一次 AI 决策 ---
	if _detection_timer > 0.0:
		_detection_timer -= delta / off_factor
	if _detection_timer <= 0.0:
		_detection_timer = enemy_data.detection_interval
		_ai_tick()

	match _state:
		EnemyState.SPAWNING:
			_state_spawning(delta)
		EnemyState.IDLE:
			_state_idle(delta)
		EnemyState.CHASE:
			_state_chase(delta)
		EnemyState.WALKING:
			_state_walking(delta)
		EnemyState.RUNNING:
			_state_running(delta)
		EnemyState.ATTACK:
			_state_attack(delta)
		EnemyState.ATTACK_PREPARE:
			_state_attack_prepare(delta)
		EnemyState.ATTACK_ACTIVE:
			_state_attack_active(delta)
		EnemyState.ATTACK_RECOVER:
			_state_attack_recover(delta)
		EnemyState.DEFENDING:
			_state_defending(delta)
		EnemyState.PAIN:
			_state_pain(delta)
		EnemyState.STUNNED:
			_state_stunned(delta)
		EnemyState.GRABBED:
			_state_grabbed(delta)
		EnemyState.KNOCKED_DOWN:
			_state_knocked_down(delta)
		EnemyState.DEATH:
			_state_death(delta)

	if _state != EnemyState.DEATH and _state != EnemyState.GRABBED:
		velocity += _knockback_velocity

	# 眩晕/定身状态下强制归零速度
	if (_snare_timer > 0.0 or _state == EnemyState.STUNNED) and _state not in [EnemyState.GRABBED, EnemyState.DEATH]:
		velocity = Vector3.ZERO

	if _state != EnemyState.DEATH and _state != EnemyState.GRABBED and is_inside_tree():
		move_and_slide()

	_update_debug_bars()


# ==============================================================================
# AI tick — 子类覆写以自定义行为
# ==============================================================================
func _ai_tick() -> void:
	pass  # 默认什么都不做——子类（如 OrcEnemy）会覆写此方法


## 统计自己周围指定范围内的近战敌人数量
func _count_nearby_melee_enemies(radius: float) -> int:
	var count: int = 0
	for node in get_tree().get_nodes_in_group("enemy"):
		if node == self:
			continue
		if not is_instance_valid(node):
			continue
		if global_position.distance_to(node.global_position) <= radius:
			count += 1
	return count


## 统计玩家身边指定范围内的敌人数量
func _count_enemies_near_player(radius: float) -> int:
	if _player == null:
		return 0
	var count: int = 0
	for node in get_tree().get_nodes_in_group("enemy"):
		if node == self:
			continue
		if not is_instance_valid(node):
			continue
		if _player.global_position.distance_to(node.global_position) <= radius:
			count += 1
	return count


# ==============================================================================
# SPAWNING — 出生动画
# ==============================================================================
func begin_spawning() -> void:
	scale = Vector3(0.1, 0.1, 0.1)
	_transition_to(EnemyState.SPAWNING)


func _state_spawning(delta: float) -> void:
	const DURATION := 0.5
	_state_timer += delta
	var t: float = clampf(_state_timer / DURATION, 0.0, 1.0)
	scale = Vector3.ONE * lerpf(0.1, 1.0, t)
	if t >= 1.0:
		scale = Vector3.ONE
		_transition_to(EnemyState.IDLE)
		_detection_timer = 0.0  # 立即触发 AI，避免在 IDLE 挂机


# ==============================================================================
# 状态转移
# ==============================================================================
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
# IDLE → 距离检测
# ==============================================================================
func _state_idle(_delta: float) -> void:
	if _player == null:
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist <= enemy_data.sight_range:
		_transition_to(EnemyState.CHASE)


# ==============================================================================
# CHASE — 追逐状态（向后兼容，旧敌人仍使用此状态）
# ==============================================================================
func _state_chase(delta: float) -> void:
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	if dist > enemy_data.sight_range * 1.5:
		_transition_to(EnemyState.IDLE)
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


# ==============================================================================
# WALKING — 走动接近（基础移速）
# ==============================================================================
func _state_walking(delta: float) -> void:
	_move_towards_player(delta, enemy_data.move_speed)
	velocity.y = 0.0
	_face_player_flat()


# ==============================================================================
# RUNNING — 跑动接近（1.5 倍移速）
# ==============================================================================
func _state_running(delta: float) -> void:
	_move_towards_player(delta, enemy_data.move_speed * 1.5)
	velocity.y = 0.0
	_face_player_flat()


# ==============================================================================
# ATTACK — 旧版统一攻击状态（向后兼容，内部三段式）
# ==============================================================================
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


# ==============================================================================
# 新版三段式攻击状态
# ==============================================================================
func _state_attack_prepare(delta: float) -> void:
	_face_player_flat()
	_state_timer += delta
	if _state_timer >= enemy_data.attack_windup:
		_transition_to(EnemyState.ATTACK_ACTIVE)

func _state_attack_active(delta: float) -> void:
	_face_player_flat()
	if _state_timer == 0.0:
		_execute_attack()
		_attack_cooldown_timer = enemy_data.attack_cooldown
	_state_timer += delta
	if _state_timer >= enemy_data.attack_duration:
		_transition_to(EnemyState.ATTACK_RECOVER)

func _state_attack_recover(delta: float) -> void:
	_face_player_flat()
	_state_timer += delta
	if _state_timer >= enemy_data.attack_recovery:
		_transition_to(EnemyState.CHASE)


# ==============================================================================
# DEFENDING — 举盾/防御状态
# ==============================================================================
func _state_defending(_delta: float) -> void:
	_face_player_flat()


# ==============================================================================
# 攻击执行
# ==============================================================================
func _execute_attack() -> void:
	if _player == null:
		return

	var dist := _get_player_distance_xz()

	match enemy_data.damage_type:
		WeaponData.DamageType.MELEE:
			var dy := absf(_player.global_position.y - global_position.y)
			var max_dy: float = enemy_data.height * 1.0
			if dist <= enemy_data.attack_range * 1.3 and dy <= max_dy:
				_damage_player(enemy_data.attack_damage, WeaponData.DamageType.MELEE)

		WeaponData.DamageType.HITSCAN:
			_do_hitscan_attack()

		WeaponData.DamageType.PROJECTILE:
			_spawn_projectile_attack()


func _damage_player(amount: float, dtype: WeaponData.DamageType) -> void:
	# 记录攻击者位置（供受击方向指示器使用）
	GameBus.last_attacker_position = global_position

	# 盾牌阻挡检测
	var grabbed: Node = null
	if is_instance_valid(_player) and _player.has_method("get_grabbed_enemy"):
		var candidate: Node = _player.get_grabbed_enemy()
		if is_instance_valid(candidate):
			grabbed = candidate
	if grabbed != null:
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


# ==============================================================================
# PAIN / STUNNED / GRABBED / KNOCKED_DOWN / DEATH
# ==============================================================================
func _state_pain(delta: float) -> void:
	_state_timer += delta
	if _state_timer >= enemy_data.pain_duration:
		_transition_to(EnemyState.CHASE)


func _state_stunned(delta: float) -> void:
	if _state_timer == 0.0:
		# 开始眩晕脉冲（状态首次进入）
		var t := get_tree().create_timer(0.15)
		t.timeout.connect(_stun_pulse)
	_state_timer += delta
	_stun_full_timer -= delta
	if _stun_full_timer <= 0.0:
		_is_stun_full = false
		_stun = enemy_data.max_stun * 0.8
		_transition_to(EnemyState.CHASE)


func _stun_pulse() -> void:
	if _state == EnemyState.STUNNED:
		_stun_flash_toggle = not _stun_flash_toggle
		_flash_pain(Color.WHITE if _stun_flash_toggle else Color(0.3, 0.7, 1.0))
		var t := get_tree().create_timer(0.4)
		t.timeout.connect(_stun_pulse)


func _state_grabbed(_delta: float) -> void:
	if _grab_owner == null or not is_instance_valid(_grab_owner):
		release_grab()


func _state_knocked_down(delta: float) -> void:
	_state_timer += delta
	if _state_timer >= 1.5:
		_is_stun_full = false
		_stun = enemy_data.max_stun * 0.5
		_transition_to(EnemyState.CHASE)


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
# 眩晕 / 击退 / 抓取 / 处决 / 倒地 / 定身 / 增伤标记
# ==============================================================================
func apply_stun(amount: float, bypass_armor: bool = false) -> void:
	if _state == EnemyState.DEATH or _state == EnemyState.EXECUTED:
		return
	var effective: float = amount * (1.0 - enemy_data.stun_resistance)
	# 护甲抵消90%眩晕提升（有护甲时只承受10%眩晕），铁鞭可绕过
	if not bypass_armor and _current_armor > 0.0:
		effective *= 0.1
	_stun = clampf(_stun + effective, 0.0, enemy_data.max_stun)
	_stun_decay_delay = 1.0
	stun_changed.emit(_stun, enemy_data.max_stun)
	if _stun >= enemy_data.max_stun and not _is_stun_full:
		_is_stun_full = true
		_stun_full_timer = enemy_data.stun_full_duration
		stun_filled.emit(self)
		_flash_pain(Color.WHITE)
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


## 使敌人倒地
func knock_down() -> void:
	if _state == EnemyState.DEATH or _state == EnemyState.EXECUTED:
		return
	_transition_to(EnemyState.KNOCKED_DOWN)


## 判断敌人是否倒地
func is_knocked_down() -> bool:
	return _state == EnemyState.KNOCKED_DOWN


## 定身：velocity=0，持续 duration 秒
func apply_snare(duration: float) -> void:
	_snare_timer = duration


## 增伤标记：下次受击时乘以 multiplier，持续 duration 秒或被消耗
func apply_damage_mark(duration: float, multiplier: float) -> void:
	_damage_mark_multiplier = multiplier
	_damage_mark_timer = duration


# ==============================================================================
# 移动辅助
# ==============================================================================
func _register_to_manager() -> void:
	var parent := get_parent()
	while parent != null:
		for child in parent.get_children():
			if child is EnemyManager and not child.active_enemies.has(self):
				child.register_enemy(self)
				return
		parent = parent.get_parent()


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
	velocity.y = 0.0
	velocity.z = dir.z * speed


func _move_away_from_player(_delta: float, speed: float) -> void:
	var dir := -_get_player_flat_direction()
	velocity.x = dir.x * speed
	velocity.y = 0.0
	velocity.z = dir.z * speed


func _strafe_around_player(_delta: float, speed: float) -> void:
	var dir := _get_player_flat_direction()
	velocity.x = -dir.z * speed
	velocity.y = 0.0
	velocity.z = dir.x * speed


func _face_player_flat() -> void:
	var dir := _get_player_flat_direction()
	look_at(global_position + dir, Vector3.UP)


# ==============================================================================
# 受伤反馈（含 Counter 系统 + 护甲减伤）
# ==============================================================================

## 公共方法：外部触发受击反馈（iron_whip 处决视觉效果用）
func trigger_on_damaged(_amount: float, _type: WeaponData.DamageType) -> void:
	_on_damaged(_amount, _type)


func _on_damaged(amount: float, _type: WeaponData.DamageType) -> void:
	if _state == EnemyState.DEATH:
		return

	# 增伤标记消耗
	if _damage_mark_multiplier > 1.0:
		amount *= _damage_mark_multiplier
		_damage_mark_multiplier = 1.0
		_damage_mark_timer = 0.0

	# --- COUNTER 检测：仅 ATTACK_ACTIVE 判定窗口受击触发，直接眩晕满 ---
	if _state == EnemyState.ATTACK_ACTIVE:
		# Counter：眩晕值直接拉满，无视抗性
		_stun = enemy_data.max_stun
		if not _is_stun_full:
			_is_stun_full = true
			_stun_full_timer = enemy_data.stun_full_duration
			stun_filled.emit(self)
			_transition_to(EnemyState.STUNNED)
		# 白色闪烁
		_flash_pain(Color.WHITE)
		# 护甲清零 + 发射 Counter 信号
		_current_armor = 0.0
		GameBus.counter_triggered.emit(self, global_position)
		return

	# 护甲减伤（敌人护甲系统——使用每实例变量，避免共享 Resource 变异）
	# Damageable.take_damage() 已预先扣除了全额 HP，护甲吸收的部分需退回
	if _current_armor > 0.0:
		var absorbed: float = deplete_armor(amount)
		amount -= absorbed
		if absorbed > 0.0 and _damageable != null:
			_damageable.health = minf(_damageable.health + absorbed, _damageable.max_health)

	# 正常受击闪白
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
		elif child is CSGShape3D:
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
		timer.timeout.connect(func():
			var g := instance_from_id(key) as Node3D
			if g != null:
				_restore_material(g, key))


func _restore_material(geo: Node3D, key: int) -> void:
	if not is_instance_valid(geo):
		return
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
		if child is MeshInstance3D or child is CSGShape3D:
			var geo: Node3D = child
			var death_mat := StandardMaterial3D.new()
			death_mat.albedo_color = Color(0.3, 0.3, 0.3)
			geo.material_override = death_mat


# ==============================================================================
# 调试条 — 从上至下：眩晕(黄) / 护甲(蓝) / 血量(绿→橙→红)
# ==============================================================================
func _create_debug_bars() -> void:
	var bar_thick := 0.06
	var bar_z: float = -0.5

	# 眩晕条（黄色，最上方）
	_debug_stun_bar = _make_bar("StunBar", Color(1.0, 0.9, 0.1), DEBUG_BAR_Y + 0.1, bar_thick, bar_z)
	var stun_mat := _debug_stun_bar.material_override as StandardMaterial3D
	if stun_mat != null:
		stun_mat.emission_enabled = true
		stun_mat.emission = Color(1.0, 0.9, 0.1)
		stun_mat.emission_energy_multiplier = 0.5

	# 护甲条（蓝色，中间）
	_debug_armor_bar = _make_bar("ArmorBar", Color(0.2, 0.4, 1.0), DEBUG_BAR_Y, bar_thick, bar_z)
	var armor_mat := _debug_armor_bar.material_override as StandardMaterial3D
	if armor_mat != null:
		armor_mat.emission_enabled = true
		armor_mat.emission = Color(0.2, 0.4, 1.0)
		armor_mat.emission_energy_multiplier = 0.5

	# HP 血条（绿色→橙→红，最下方）
	_debug_hp_bar = _make_bar("HPBar", Color(0.2, 0.9, 0.2), DEBUG_BAR_Y - 0.1, bar_thick, bar_z)
	var hp_mat := _debug_hp_bar.material_override as StandardMaterial3D
	if hp_mat != null:
		hp_mat.emission_enabled = true
		hp_mat.emission = Color(0.2, 0.9, 0.2)
		hp_mat.emission_energy_multiplier = 0.5


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
	if _debug_stun_bar != null and enemy_data != null and enemy_data.max_stun > 0.0:
		var ratio: float = _stun / enemy_data.max_stun
		var w: float = DEBUG_BAR_FULL * ratio
		var stun_box: BoxMesh = _debug_stun_bar.mesh
		stun_box.size.x = w
		_debug_stun_bar.position.x = -(DEBUG_BAR_FULL - w) / 2.0

	if _debug_armor_bar != null and enemy_data != null:
		var armor_max: float = enemy_data.armor
		if armor_max > 0.0:
			var ratio: float = _current_armor / armor_max
			var w: float = DEBUG_BAR_FULL * ratio
			var arm_box: BoxMesh = _debug_armor_bar.mesh
			arm_box.size.x = w
			_debug_armor_bar.position.x = -(DEBUG_BAR_FULL - w) / 2.0
			_debug_armor_bar.visible = true
		else:
			_debug_armor_bar.visible = false

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

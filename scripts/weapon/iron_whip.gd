# ==============================================================================
# IronWhip — 左手铁鞭（右键控制/眩晕/拉取/抓取/盾牌/甩出/冲刺处决）
# ==============================================================================
class_name IronWhip extends Node3D

const WhipDataClass = preload("res://scripts/weapon/whip_data.gd")
const EnemyClass = preload("res://scripts/enemy/enemy.gd")

enum WhipState { IDLE, WHIPPING, PULLING, GRABBING, SHIELDING, THROWING, DASHING }

var _whip_data: WhipData
var _camera: Camera3D
var _player: CharacterBody3D

var _state: WhipState = WhipState.IDLE
var _cooldown_timer: float = 0.0
var _pulled_enemy: Enemy = null
var _grabbed_enemy: Enemy = null

var _whip_line_mesh: MeshInstance3D = null
var _whip_line_timer: float = 0.0

# 右手键按住检测
var _secondary_held: bool = false
var _was_shielding: bool = false


func setup(data: WhipData, camera: Camera3D, player: CharacterBody3D) -> void:
	_whip_data = data
	_camera = camera
	_player = player
	_setup_model()


func _setup_model() -> void:
	var idle_mesh := MeshInstance3D.new()
	idle_mesh.name = "WhipIdleModel"
	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.08, 0.08)
	idle_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.38, 0.35)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	idle_mesh.material_override = mat
	add_child(idle_mesh)

	var line_mesh := MeshInstance3D.new()
	line_mesh.name = "WhipLine"
	var line_box := BoxMesh.new()
	line_box.size = Vector3(0.05, 0.05, 0.5)
	line_mesh.mesh = line_box
	line_mesh.visible = false
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(1.0, 0.5, 0.1)
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.emission_enabled = true
	line_mat.emission = Color(1.0, 0.4, 0.0)
	line_mat.emission_energy_multiplier = 5.0
	line_mesh.material_override = line_mat
	add_child(line_mesh)
	_whip_line_mesh = line_mesh


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return

	# 滚轮向下：甩出 / 冲刺处决
	if event.is_action_pressed("whip_throw"):
		if _state == WhipState.GRABBING:
			_state = WhipState.THROWING
			_execute_throw()
			get_viewport().set_input_as_handled()
		elif _state == WhipState.SHIELDING and _grabbed_enemy != null:
			_state = WhipState.DASHING
			_start_dash()
			get_viewport().set_input_as_handled()

	# R 键处决
	if event.is_action_pressed("reload"):
		if (_state == WhipState.GRABBING or _state == WhipState.SHIELDING) and _grabbed_enemy != null:
			_execute_grabbed()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

	if _whip_line_timer > 0.0:
		_whip_line_timer -= delta

	# 右键挥鞭（仅 IDLE 状态）
	if Input.is_action_just_pressed("secondary_fire") and _state == WhipState.IDLE:
		_try_whip()

	# 盾牌模式：GRABBING 状态下按住右键进入 SHIELDING
	var sec_pressed := Input.is_action_pressed("secondary_fire")
	if _state == WhipState.GRABBING and sec_pressed and not _secondary_held:
		_enter_shielding()
	elif _state == WhipState.SHIELDING and not sec_pressed:
		_exit_shielding()
	_secondary_held = sec_pressed

	# R 键处决（Input 直接检测）
	if Input.is_action_just_pressed("reload"):
		if (_state == WhipState.GRABBING or _state == WhipState.SHIELDING) and _grabbed_enemy != null:
			_execute_grabbed()

	match _state:
		WhipState.WHIPPING:
			if _cooldown_timer <= 0.0:
				_state = WhipState.IDLE

		WhipState.PULLING:
			_process_pull(delta)

		WhipState.GRABBING:
			_process_grab(delta)

		WhipState.SHIELDING:
			_process_shielding(delta)

		WhipState.DASHING:
			_process_dash(delta)


# ==============================================================================
# 挥鞭
# ==============================================================================
func _try_whip() -> void:
	var ray_origin := _camera.global_position
	var dir := -_camera.global_transform.basis.z.normalized()
	var end: Vector3 = ray_origin + dir * _whip_data.whip_range

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, end)
	query.collision_mask = 1
	query.exclude = [_player]

	var result := space_state.intersect_ray(query)

	_cooldown_timer = _whip_data.cooldown
	_state = WhipState.WHIPPING

	var hit_point: Vector3 = end
	if not result.is_empty():
		hit_point = result.position
		var target: Node = result.collider
		_execute_whip_hit(target)

	_spawn_whip_effect(global_position, hit_point)


func _spawn_whip_effect(from: Vector3, to: Vector3) -> void:
	var root := get_tree().root
	var to_dir := to - from
	var total_len := to_dir.length()
	var dir := to_dir.normalized() if total_len > 0.01 else Vector3.FORWARD
	var segment_count: int = ceili(total_len / 0.3)
	segment_count = clampi(segment_count, 3, 20)

	for i in range(segment_count):
		var t: float = float(i) / float(segment_count - 1)
		var pos := from + dir * (total_len * t)

		var sphere := MeshInstance3D.new()
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = 0.03
		sphere_mesh.height = 0.06
		sphere.mesh = sphere_mesh

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.4, 0.05)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sphere.material_override = mat

		root.add_child(sphere)
		sphere.global_position = pos

		var timer := get_tree().create_timer(0.25)
		timer.timeout.connect(sphere.queue_free)


func _execute_whip_hit(target: Node) -> void:
	var enemy: Enemy = _find_enemy(target)
	if enemy == null:
		return

	var dmg := enemy.get_node_or_null("Damageable") as Damageable
	if dmg != null:
		dmg.take_damage(_whip_data.damage, WeaponData.DamageType.MELEE)

	enemy.apply_stun(_whip_data.stun_damage)

	if enemy.can_be_grabbed():
		_start_pull(enemy)
	else:
		var kb_dir := (enemy.global_position - _player.global_position).normalized()
		kb_dir.y = 0.0
		if kb_dir.length_squared() < 0.01:
			kb_dir = -_camera.global_transform.basis.z.normalized()
			kb_dir.y = 0.0
		enemy.apply_knockback(kb_dir, _whip_data.knockback_force)


# ==============================================================================
# 拉取
# ==============================================================================
func _start_pull(enemy: Enemy) -> void:
	_pulled_enemy = enemy
	_state = WhipState.PULLING


func _process_pull(delta: float) -> void:
	if _pulled_enemy == null or not is_instance_valid(_pulled_enemy):
		_cancel_pull()
		return

	if not _pulled_enemy.can_be_grabbed():
		_cancel_pull()
		return

	var target_pos: Vector3 = _player.global_position + (-_camera.global_transform.basis.z.normalized()) * _whip_data.grab_distance
	target_pos.y = _player.global_position.y + 0.5

	var to_target := target_pos - _pulled_enemy.global_position
	var dist: float = to_target.length()

	if dist < _whip_data.grab_distance * 1.2:
		_start_grab(_pulled_enemy)
	else:
		_pulled_enemy.global_position += to_target.normalized() * _whip_data.pull_speed * delta


func _cancel_pull() -> void:
	_pulled_enemy = null
	_state = WhipState.IDLE


# ==============================================================================
# 抓取（左手举起模式）
# ==============================================================================
func _start_grab(enemy: Enemy) -> void:
	if not enemy.start_grab(_player):
		_cancel_pull()
		return

	_pulled_enemy = null
	_grabbed_enemy = enemy
	_state = WhipState.GRABBING

	_player.grabbed_enemy = enemy

	# 缩小敌人模拟被举起
	if enemy.has_method("set_scale"):
		enemy.scale = Vector3(0.65, 0.65, 0.65)

	var weight: float = 1.0
	if enemy.enemy_data != null:
		weight = enemy.enemy_data.weight
	var speed_mult: float = clampf(1.0 / (1.0 + weight * 0.35), 0.25, 1.0)
	_player.set_speed_multiplier(speed_mult)

	_show_grab_status(enemy)


func _process_grab(_delta: float) -> void:
	if _grabbed_enemy == null or not is_instance_valid(_grabbed_enemy):
		_release_grab_internal()
		return

	# 左手举起位置：LeftHandHolder 前方上方
	var lh_pos := global_position + Vector3(0, 0.5, -0.3)
	var grab_origin := lh_pos
	var grab_transform := Transform3D(_player.global_transform.basis, grab_origin)
	_grabbed_enemy.update_grabbed_position(grab_transform, _delta)


# ==============================================================================
# 盾牌模式
# ==============================================================================
func _enter_shielding() -> void:
	if _grabbed_enemy == null:
		return
	_was_shielding = true
	_state = WhipState.SHIELDING

	# 恢复敌人大小
	if _grabbed_enemy.has_method("set_scale"):
		_grabbed_enemy.scale = Vector3(1.0, 1.0, 1.0)

	GameBus.grab_status_show.emit("盾牌模式 [滚轮=冲刺处决]")


func _exit_shielding() -> void:
	if _grabbed_enemy == null or not is_instance_valid(_grabbed_enemy):
		return
	_was_shielding = false
	_state = WhipState.GRABBING

	# 缩回举起大小
	if _grabbed_enemy.has_method("set_scale"):
		_grabbed_enemy.scale = Vector3(0.65, 0.65, 0.65)

	_show_grab_status(_grabbed_enemy)


func _process_shielding(_delta: float) -> void:
	if _grabbed_enemy == null or not is_instance_valid(_grabbed_enemy):
		_release_grab_internal()
		return

	# 盾牌位置：摄像机正前方 1.5m
	var shield_pos := _player.global_position + (-_camera.global_transform.basis.z).normalized() * 1.5 + Vector3(0, 0.3, 0)
	var shield_transform := Transform3D(_player.global_transform.basis, shield_pos)
	_grabbed_enemy.update_grabbed_position(shield_transform, _delta)


# ==============================================================================
# 甩出
# ==============================================================================
func _execute_throw() -> void:
	if _grabbed_enemy == null or not is_instance_valid(_grabbed_enemy):
		_release_grab_internal()
		return

	var enemy := _grabbed_enemy

	# 恢复大小
	if enemy.has_method("set_scale"):
		enemy.scale = Vector3(1.0, 1.0, 1.0)

	enemy.release_grab()

	# 沿摄像机前方甩出
	var throw_dir := (-_camera.global_transform.basis.z).normalized() + Vector3(0, 0.3, 0)
	enemy.global_position = _camera.global_position + throw_dir.normalized() * 1.0

	# 给敌人施加速度
	if enemy is CharacterBody3D:
		enemy.velocity = throw_dir.normalized() * _whip_data.throw_speed

	# 碰撞伤害由 enemy.gd 的 move_and_slide 处理
	# 简化：对附近敌人造成范围伤害
	_apply_aoe_damage(enemy.global_position, 3.0, _whip_data.throw_damage, _whip_data.dash_knockback)

	# 视觉：拖尾
	_spawn_whip_effect(enemy.global_position - throw_dir.normalized() * 2.0, enemy.global_position)

	_grabbed_enemy = null
	_player.grabbed_enemy = null
	_player.set_speed_multiplier(1.0)
	_hide_grab_status()
	_state = WhipState.IDLE


# ==============================================================================
# 冲刺处决（盾牌模式下滚轮向下）
# ==============================================================================
func _start_dash() -> void:
	if _grabbed_enemy == null or not is_instance_valid(_grabbed_enemy):
		_state = WhipState.IDLE
		return

	# 通知玩家开始冲刺
	if _player.has_method("start_dash"):
		var dash_dir := (-_camera.global_transform.basis.z).normalized()
		dash_dir.y = 0.0
		_player.start_dash(dash_dir, _whip_data.dash_speed, _whip_data.dash_distance)

	# 等待冲刺完成
	var timer := get_tree().create_timer(_whip_data.dash_distance / _whip_data.dash_speed)
	timer.timeout.connect(_finish_dash)


func _finish_dash() -> void:
	if _state != WhipState.DASHING:
		return

	if _grabbed_enemy != null and is_instance_valid(_grabbed_enemy):
		var enemy := _grabbed_enemy

		# 大伤害给被抓敌人
		var dmg := enemy.get_node_or_null("Damageable") as Damageable
		if dmg != null:
			dmg.take_damage(_whip_data.dash_grabbed_damage, WeaponData.DamageType.MELEE)

		# 路径 AOE
		_apply_aoe_damage(enemy.global_position, 4.0, _whip_data.dash_aoe_damage, _whip_data.dash_knockback)

		enemy.release_grab()
		if enemy.has_method("set_scale"):
			enemy.scale = Vector3(1.0, 1.0, 1.0)

		# 加分
		GameBus.run_stats.add_kill(_whip_data.execution_score_bonus)
		GameBus.pickup_notification.emit("冲刺处决 +" + str(_whip_data.execution_score_bonus), Color(1.0, 0.3, 0.1))

	_grabbed_enemy = null
	_player.grabbed_enemy = null
	_player.set_speed_multiplier(1.0)
	_hide_grab_status()
	_state = WhipState.IDLE


func _process_dash(_delta: float) -> void:
	# 冲刺由 PlayerController._physics_process 处理
	# Dash 状态在 _process 中保持，等待 _finish_dash 回调
	pass


# ==============================================================================
# 范围伤害
# ==============================================================================
func _apply_aoe_damage(center: Vector3, radius: float, damage: float, knockback: float) -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")
	for node in enemies:
		if not is_instance_valid(node):
			continue
		var dist: float = node.global_position.distance_to(center)
		if dist > radius:
			continue

		var enemy: Enemy = node as Enemy
		if enemy == null:
			continue
		if enemy == _grabbed_enemy:
			continue

		var dmg := enemy.get_node_or_null("Damageable") as Damageable
		if dmg != null:
			dmg.take_damage(damage, WeaponData.DamageType.MELEE)

		# 击退
		var kb_dir := (enemy.global_position - center).normalized()
		kb_dir.y = 0.0
		if kb_dir.length_squared() > 0.01:
			enemy.apply_knockback(kb_dir, knockback)


# ==============================================================================
# 处决
# ==============================================================================
func _execute_grabbed() -> void:
	if _grabbed_enemy == null or not is_instance_valid(_grabbed_enemy):
		return

	var enemy := _grabbed_enemy

	if enemy.has_method("set_scale"):
		enemy.scale = Vector3(1.0, 1.0, 1.0)

	enemy.execute()

	GameBus.run_stats.add_kill(_whip_data.execution_score_bonus)
	GameBus.pickup_notification.emit("处决 +" + str(_whip_data.execution_score_bonus), Color(1.0, 0.3, 0.1))

	if enemy.has_method("trigger_on_damaged"):
		enemy.trigger_on_damaged(_whip_data.execution_damage, WeaponData.DamageType.MELEE)

	_release_grab_internal()


func _release_grab_internal() -> void:
	if _grabbed_enemy != null and is_instance_valid(_grabbed_enemy):
		if _grabbed_enemy.has_method("set_scale"):
			_grabbed_enemy.scale = Vector3(1.0, 1.0, 1.0)
		_grabbed_enemy.release_grab()
	_grabbed_enemy = null
	_pulled_enemy = null
	_player.grabbed_enemy = null
	_player.set_speed_multiplier(1.0)
	_hide_grab_status()
	_state = WhipState.IDLE


func release_grab() -> void:
	_release_grab_internal()


# ==============================================================================
# 工具方法
# ==============================================================================
func _find_enemy(node: Node) -> Enemy:
	if node is Enemy:
		return node
	for child in node.get_children():
		if child is Enemy:
			return child
	var parent := node.get_parent()
	if parent != null:
		return _find_enemy(parent)
	return null


func _show_grab_status(enemy: Enemy) -> void:
	var name_str: String = "敌人"
	if enemy.enemy_data != null:
		name_str = enemy.enemy_data.enemy_name
	GameBus.grab_status_show.emit(name_str)


func _hide_grab_status() -> void:
	GameBus.grab_status_hide.emit()


func is_grabbing() -> bool:
	return (_state == WhipState.GRABBING or _state == WhipState.SHIELDING) and _grabbed_enemy != null


func get_grabbed_enemy() -> Enemy:
	return _grabbed_enemy

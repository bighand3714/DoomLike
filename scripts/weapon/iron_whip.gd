# ==============================================================================
# IronWhip — 左手铁鞭（右键控制/眩晕/拉取/抓取/处决）
# ==============================================================================
class_name IronWhip extends Node3D

const WhipDataClass = preload("res://scripts/weapon/whip_data.gd")
const EnemyClass = preload("res://scripts/enemy/enemy.gd")

enum WhipState { IDLE, WHIPPING, PULLING, GRABBING }

var _whip_data: WhipData
var _camera: Camera3D
var _player: CharacterBody3D

var _state: WhipState = WhipState.IDLE
var _cooldown_timer: float = 0.0
var _pulled_enemy: Enemy = null
var _grabbed_enemy: Enemy = null

var _whip_line_mesh: MeshInstance3D = null
var _whip_line_timer: float = 0.0


func setup(data: WhipData, camera: Camera3D, player: CharacterBody3D) -> void:
	_whip_data = data
	_camera = camera
	_player = player
	_setup_model()


func _setup_model() -> void:
	# 空闲时左手方块（亮铁灰色，无光照也能看清）
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

	# 鞭影（挥鞭时显示，默认隐藏）
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

	if event.is_action_pressed("reload"):
		if _state == WhipState.GRABBING and _grabbed_enemy != null:
			_execute_grabbed()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# 冷却计时
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

	# 鞭影计时
	if _whip_line_timer > 0.0:
		_whip_line_timer -= delta
		if _whip_line_timer <= 0.0:
			_hide_whip_line()

	# 右键挥鞭（Input 直接检测，不依赖事件传播）
	if Input.is_action_just_pressed("secondary_fire") and _state == WhipState.IDLE:
		_try_whip()

	# R 键处决（Input 直接检测）
	if Input.is_action_just_pressed("reload"):
		if _state == WhipState.GRABBING and _grabbed_enemy != null:
			_execute_grabbed()

	match _state:
		WhipState.WHIPPING:
			if _cooldown_timer <= 0.0:
				_state = WhipState.IDLE

		WhipState.PULLING:
			_process_pull(delta)

		WhipState.GRABBING:
			_process_grab(delta)


# ==============================================================================
# 挥鞭
# ==============================================================================
func _try_whip() -> void:
	# 射线从摄像机中心发出（和枪械一致，准星指哪打哪）
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

	# 视觉从左手位置发出（global_position = LeftHandHolder 世界坐标）
	_spawn_whip_effect(global_position, hit_point)


# 沿挥鞭路径生成多个发光小球，最稳妥的视觉方案
func _spawn_whip_effect(from: Vector3, to: Vector3) -> void:
	var root := get_tree().root
	var to_dir := to - from
	var total_len := to_dir.length()
	var dir := to_dir.normalized() if total_len > 0.01 else Vector3.FORWARD
	var segment_count: int = ceili(total_len / 0.3)  # 每 0.3m 一个球
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

		# 先加入场景树，再设 global_position（否则引擎报错）
		root.add_child(sphere)
		sphere.global_position = pos

		# 0.25 秒后自动删除
		var timer := get_tree().create_timer(0.25)
		timer.timeout.connect(sphere.queue_free)


func _hide_whip_line() -> void:
	# 旧单条鞭影已废弃，此函数保留给 _process 调用
	pass


func _execute_whip_hit(target: Node) -> void:
	var enemy: Enemy = _find_enemy(target)
	if enemy == null:
		return

	# 伤害：通过 Damageable 子节点（Enemy 本身没有 take_damage）
	var dmg := enemy.get_node_or_null("Damageable") as Damageable
	if dmg != null:
		dmg.take_damage(_whip_data.damage, WeaponData.DamageType.MELEE)

	# 眩晕
	enemy.apply_stun(_whip_data.stun_damage)

	# 击退（眩晕满 → 拉取；否则击退）
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

	# 如果敌人死亡或不再可抓取
	if not _pulled_enemy.can_be_grabbed():
		_cancel_pull()
		return

	# 计算目标位置（玩家前方 grab_distance 处）
	var target_pos: Vector3 = _player.global_position + (-_camera.global_transform.basis.z.normalized()) * _whip_data.grab_distance
	target_pos.y = _player.global_position.y + 0.5

	# 移动敌人朝向玩家
	var to_target := target_pos - _pulled_enemy.global_position
	var dist := to_target.length()

	if dist < _whip_data.grab_distance * 1.2:
		# 到达抓取距离 → 自动抓取
		_start_grab(_pulled_enemy)
	else:
		# 继续拉取
		_pulled_enemy.global_position += to_target.normalized() * _whip_data.pull_speed * delta


func _cancel_pull() -> void:
	_pulled_enemy = null
	_state = WhipState.IDLE


# ==============================================================================
# 抓取
# ==============================================================================
func _start_grab(enemy: Enemy) -> void:
	if not enemy.start_grab(_player):
		_cancel_pull()
		return

	_pulled_enemy = null
	_grabbed_enemy = enemy
	_state = WhipState.GRABBING

	# 设置玩家抓取状态
	_player.grabbed_enemy = enemy

	# 根据敌人重量降低玩家移速
	var weight: float = 1.0
	if enemy.enemy_data != null:
		weight = enemy.enemy_data.weight
	var speed_mult: float = clampf(1.0 / (1.0 + weight * 0.35), 0.25, 1.0)
	_player.set_speed_multiplier(speed_mult)

	# 通知 HUD
	_show_grab_status(enemy)


func _process_grab(_delta: float) -> void:
	if _grabbed_enemy == null or not is_instance_valid(_grabbed_enemy):
		_release_grab_internal()
		return

	# 更新被抓取敌人的位置（固定在玩家前方）
	var grab_origin: Vector3 = _player.global_position
	grab_origin += (-_camera.global_transform.basis.z).normalized() * _whip_data.grab_distance
	grab_origin.y += 0.3
	var grab_transform := Transform3D(_player.global_transform.basis, grab_origin)
	_grabbed_enemy.update_grabbed_position(grab_transform, _delta)


# ==============================================================================
# 处决
# ==============================================================================
func _execute_grabbed() -> void:
	if _grabbed_enemy == null or not is_instance_valid(_grabbed_enemy):
		return

	var enemy := _grabbed_enemy
	enemy.execute()

	# 加分
	GameBus.run_stats.add_kill(_whip_data.execution_score_bonus)
	# 通知 HUD
	GameBus.pickup_notification.emit("处决 +" + str(_whip_data.execution_score_bonus), Color(1.0, 0.3, 0.1))

	# 处决视觉：闪白
	if enemy.has_method("trigger_on_damaged"):
		enemy.trigger_on_damaged(_whip_data.execution_damage, WeaponData.DamageType.MELEE)

	_release_grab_internal()


func _release_grab_internal() -> void:
	if _grabbed_enemy != null and is_instance_valid(_grabbed_enemy):
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
	return _state == WhipState.GRABBING and _grabbed_enemy != null


func get_grabbed_enemy() -> Enemy:
	return _grabbed_enemy

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

var _idle_model: CSGBox3D = null
var _whip_line: CSGBox3D = null
var _whip_line_timer: float = 0.0


func setup(data: WhipData, camera: Camera3D, player: CharacterBody3D) -> void:
	_whip_data = data
	_camera = camera
	_player = player
	_setup_model()


func _setup_model() -> void:
	# 空闲时左手小方块（深灰色）
	_idle_model = CSGBox3D.new()
	_idle_model.name = "WhipIdleModel"
	_idle_model.size = Vector3(0.06, 0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.25, 0.25)
	_idle_model.material_override = mat
	_idle_model.use_collision = false
	add_child(_idle_model)

	# 鞭影（挥鞭时显示，默认隐藏）
	_whip_line = CSGBox3D.new()
	_whip_line.name = "WhipLine"
	_whip_line.size = Vector3(0.03, 0.03, 0.5)
	_whip_line.visible = false
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.6, 0.55, 0.45)
	line_mat.emission_enabled = true
	line_mat.emission = Color(0.3, 0.25, 0.15)
	line_mat.emission_energy_multiplier = 2.0
	_whip_line.material_override = line_mat
	_whip_line.use_collision = false
	add_child(_whip_line)


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return

	# 右键 = 挥鞭
	if event.is_action_pressed("secondary_fire") and _state == WhipState.IDLE:
		_try_whip()
		return

	# R 键 = 抓取中处决，否则交给武器换弹
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
			_whip_line.visible = false

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
	var origin := _camera.global_position
	var dir := -_camera.global_transform.basis.z.normalized()
	var end: Vector3 = origin + dir * _whip_data.whip_range

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = 1
	query.exclude = [_player]

	var result := space_state.intersect_ray(query)

	_cooldown_timer = _whip_data.cooldown
	_state = WhipState.WHIPPING

	# 显示鞭影
	var hit_point: Vector3 = end
	if not result.is_empty():
		hit_point = result.position
		var target: Node = result.collider
		_execute_whip_hit(target)

	_show_whip_line(origin, hit_point)


func _show_whip_line(from: Vector3, to: Vector3) -> void:
	if _whip_line == null:
		return
	var mid: Vector3 = (from + to) * 0.5
	var length: float = from.distance_to(to)

	_whip_line.global_position = mid
	_whip_line.size.z = max(length, 0.05)
	# 让鞭影朝向命中点
	var dir := (to - from).normalized()
	if dir.length_squared() > 0.001:
		_whip_line.look_at(mid + dir, Vector3.UP)
	_whip_line.visible = true
	_whip_line_timer = 0.12


func _execute_whip_hit(target: Node) -> void:
	var enemy: Enemy = _find_enemy(target)
	if enemy == null:
		return

	# 伤害 + 眩晕 + 击退
	if enemy.has_method("take_damage"):
		enemy.take_damage(_whip_data.damage, WeaponData.DamageType.MELEE)
	if enemy.has_method("apply_stun"):
		enemy.apply_stun(_whip_data.stun_damage)

	# 如果敌人可以被抓取 → 进入拉取流程；否则击退
	if enemy.can_be_grabbed():
		_start_pull(enemy)
	else:
		var kb_dir := (enemy.global_position - _player.global_position).normalized()
		kb_dir.y = 0.0
		if kb_dir.length_squared() < 0.01:
			kb_dir = -_camera.global_transform.basis.z.normalized()
			kb_dir.y = 0.0
		if enemy.has_method("apply_knockback"):
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
	var main := get_tree().root.get_node_or_null("Main")
	if main != null and main.has_method("get_run_stats"):
		var stats = main.get_run_stats()
		if stats != null:
			stats.add_kill(_whip_data.execution_score_bonus)
		# 通知 HUD
		if main.has_method("show_pickup_notification"):
			main.show_pickup_notification("处决 +" + str(_whip_data.execution_score_bonus), Color(1.0, 0.3, 0.1))

	# 处决视觉：闪白（通过 damageable 信号触发敌人白色闪烁）
	if enemy.has_method("_on_damaged"):
		enemy._on_damaged(_whip_data.execution_damage, WeaponData.DamageType.MELEE)

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
	# 在子节点中找
	for child in node.get_children():
		if child is Enemy:
			return child
	# 向父节点找
	var parent := node.get_parent()
	if parent != null:
		return _find_enemy(parent)
	return null


func _show_grab_status(enemy: Enemy) -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	var ps := main.get_node_or_null("UI/PlayerStatus")
	if ps != null and ps.has_method("show_grab_status"):
		var name_str: String = "敌人"
		if enemy.enemy_data != null:
			name_str = enemy.enemy_data.enemy_name
		ps.show_grab_status(name_str)


func _hide_grab_status() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	var ps := main.get_node_or_null("UI/PlayerStatus")
	if ps != null and ps.has_method("hide_grab_status"):
		ps.hide_grab_status()


func is_grabbing() -> bool:
	return _state == WhipState.GRABBING and _grabbed_enemy != null


func get_grabbed_enemy() -> Enemy:
	return _grabbed_enemy

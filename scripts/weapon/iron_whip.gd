# ==============================================================================
# IronWhip — 左手铁鞭（滚轮控制/眩晕/拉取/抓取/盾牌/甩出/冲刺处决）
# ==============================================================================
class_name IronWhip extends Node3D

const WhipDataClass = preload("res://scripts/weapon/whip_data.gd")
const EnemyClass = preload("res://scripts/enemy/enemy.gd")

enum WhipState { IDLE, WHIPPING, PULLING, GRABBING, SHIELDING, DASHING }

var _whip_data: WhipData
var _camera: Camera3D
var _player: CharacterBody3D

var _state: WhipState = WhipState.IDLE
var _cooldown_timer: float = 0.0
var _pulled_enemy: Enemy = null
var _grabbed_enemy: Enemy = null

var _whip_line_mesh: MeshInstance3D = null
var _whip_line_timer: float = 0.0

# 右键按住检测
var _secondary_held: bool = false
var _was_shielding: bool = false

# 冲刺过程中已命中的敌人（避免重复击退）
var _dash_hit_enemies: Array = []
var _dash_direction: Vector3 = Vector3.ZERO  # 冲刺方向（用于击退计算）
# 升级运行时修饰符（apply_whip_upgrade 修改）
var _whip_range_add: float = 0.0
var _whip_range_mult: float = 1.0
var _cooldown_mult: float = 1.0
var _stun_damage_mult: float = 1.0

var _enemy_transparent: bool = false     # 敌人半透明状态
var _saved_materials: Dictionary = {}    # 半透明时保存的原始材质


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


# ==============================================================================
# 输入处理：滚轮铁链 + F 键处决
# ==============================================================================
func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return

	# 滚轮向上/向下触发铁链
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_on_whip_scroll(true)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_on_whip_scroll(false)
			get_viewport().set_input_as_handled()

	# F 键处决
	if event.is_action_pressed("action_key"):
		if (_state == WhipState.GRABBING or _state == WhipState.SHIELDING) and _grabbed_enemy != null:
			_execute_grabbed()
			get_viewport().set_input_as_handled()


## 滚轮触发铁链的统一入口
func _on_whip_scroll(_scroll_up: bool) -> void:
	match _state:
		WhipState.IDLE:
			# IDLE 状态：滚轮任意方向都触发挥鞭
			_try_whip()

		WhipState.SHIELDING:
			# 滚轮任意方向 = 冲刺处决
			_state = WhipState.DASHING
			_start_dash()


# ==============================================================================
# _process — 状态机更新
# ==============================================================================
func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

	if _whip_line_timer > 0.0:
		_whip_line_timer -= delta

	# 右键 = 盾牌模式（抓取中按住右键进入护盾）
	var sec_pressed := Input.is_action_pressed("secondary_fire")
	if _state == WhipState.GRABBING and sec_pressed and not _secondary_held:
		_enter_shielding()
	elif _state == WhipState.SHIELDING and not sec_pressed:
		_exit_shielding()
	_secondary_held = sec_pressed

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
	var dir := -_camera.global_transform.basis.z.normalized()
	# 射线从摄像机前方 0.6m 开始，避免起点在玩家碰撞体内导致检测异常
	var ray_origin := _camera.global_position + dir * 0.6
	var end: Vector3 = ray_origin + dir * (_whip_data.whip_range + _whip_range_add)

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, end)
	query.collision_mask = 1
	if _grabbed_enemy != null:
		query.exclude.append(_grabbed_enemy)

	var result := space_state.intersect_ray(query)

	_cooldown_timer = _whip_data.cooldown * _cooldown_mult
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

	# 护甲检查：有护甲时削减护甲，眩晕效果按护甲比例减免
	if enemy.has_method("deplete_armor"):
		var absorbed: float = enemy.deplete_armor(_whip_data.damage * 0.5)
		if absorbed > 0.0:
			# 护甲存在：按已破护甲比例增加眩晕（破甲越多眩晕越多，30%~100%）
			var armor_ratio: float = 0.3
			if enemy.enemy_data != null and enemy.enemy_data.armor > 0.0:
				var remaining := enemy.get_current_armor()
				armor_ratio = clampf(1.0 - remaining / enemy.enemy_data.armor, 0.3, 1.0)
			enemy.apply_stun(_whip_data.stun_damage * _stun_damage_mult * armor_ratio, true)
			# 护甲敌人眩晕满后也可拉取，不在此return

	var dmg := enemy.get_node_or_null("Damageable") as Damageable
	if dmg != null:
		dmg.take_damage(_whip_data.damage, WeaponData.DamageType.MELEE)

	enemy.apply_stun(_whip_data.stun_damage * _stun_damage_mult)

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

	var weight: float = 1.0
	if enemy.enemy_data != null:
		weight = enemy.enemy_data.weight
	var speed_mult: float = clampf(1.0 - weight * 0.006, 0.35, 1.0)
	_player.set_speed_multiplier(speed_mult)

	_show_grab_status(enemy)


func _process_grab(_delta: float) -> void:
	if _grabbed_enemy == null or not is_instance_valid(_grabbed_enemy):
		_release_grab_internal()
		return

	var cam_forward := -_camera.global_transform.basis.z.normalized()
	cam_forward.y = 0.0
	var cam_right := _camera.global_transform.basis.x.normalized()
	var target_pos := _player.global_position - cam_right * 1.2 + cam_forward * 0.8 + Vector3(0, 0.5, 0)
	var current_pos := _grabbed_enemy.global_position
	var smoothed_pos := current_pos.lerp(target_pos, 0.3)
	var grab_transform := Transform3D(_player.global_transform.basis, smoothed_pos)
	_grabbed_enemy.update_grabbed_position(grab_transform, _delta)


# ==============================================================================
# 盾牌模式
# ==============================================================================
func _enter_shielding() -> void:
	if _grabbed_enemy == null:
		return
	_was_shielding = true
	_state = WhipState.SHIELDING

	_set_enemy_transparent(true)

	GameBus.grab_status_show.emit("盾牌模式 [滚轮=冲刺处决]")


func _exit_shielding() -> void:
	if _grabbed_enemy == null or not is_instance_valid(_grabbed_enemy):
		return
	_was_shielding = false
	_state = WhipState.GRABBING

	_set_enemy_transparent(false)

	_show_grab_status(_grabbed_enemy)


func _process_shielding(_delta: float) -> void:
	if _grabbed_enemy == null or not is_instance_valid(_grabbed_enemy):
		_release_grab_internal()
		return

	# 盾牌位置：画面正中
	var cam_forward := -_camera.global_transform.basis.z.normalized()
	cam_forward.y = 0.0
	var shield_pos := _player.global_position + cam_forward * 1.5 + Vector3(0, 0.3, 0)
	var current := _grabbed_enemy.global_position
	var smoothed := current.lerp(shield_pos, 0.4)
	var shield_transform := Transform3D(_player.global_transform.basis, smoothed)
	_grabbed_enemy.update_grabbed_position(shield_transform, _delta)



# ==============================================================================
# 冲刺处决（盾牌模式下滚轮触发）
# ==============================================================================
func _start_dash() -> void:
	if _grabbed_enemy == null or not is_instance_valid(_grabbed_enemy):
		_state = WhipState.IDLE
		return

	_dash_hit_enemies.clear()
	# 临时禁用被抓敌人的碰撞层，避免冲刺时玩家撞上它
	_grabbed_enemy.collision_layer = 0
	# 通知玩家开始冲刺
	if _player.has_method("start_dash"):
		var dash_dir := (-_camera.global_transform.basis.z).normalized()
		dash_dir.y = 0.0
		_dash_direction = dash_dir
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

		# 路径 AOE + 倒地
		var enemies := get_tree().get_nodes_in_group("enemy")
		for node in enemies:
			if not is_instance_valid(node):
				continue
			var other: Enemy = node as Enemy
			if other == null or other == enemy:
				continue
			var dist: float = other.global_position.distance_to(enemy.global_position)
			if dist <= 4.0:
				var aoe_dmg := other.get_node_or_null("Damageable") as Damageable
				if aoe_dmg != null:
					aoe_dmg.take_damage(_whip_data.dash_aoe_damage, WeaponData.DamageType.MELEE)
				var kb_dir := (other.global_position - enemy.global_position).normalized()
				kb_dir.y = 0.0
				other.apply_knockback(kb_dir, _whip_data.dash_knockback)

		enemy.release_grab()

		# 加分
		if GameBus.run_stats != null:
			GameBus.run_stats.add_kill(_whip_data.execution_score_bonus)
		GameBus.pickup_notification.emit("冲刺处决 +" + str(_whip_data.execution_score_bonus), Color(1.0, 0.3, 0.1))

	_grabbed_enemy = null
	_player.grabbed_enemy = null
	_player.set_speed_multiplier(1.0)
	_hide_grab_status()
	_state = WhipState.IDLE


func _process_dash(_delta: float) -> void:
	# 保持被抓敌人跟随玩家一起冲刺（视觉上在前方作为"盾牌冲撞"）
	if _grabbed_enemy != null and is_instance_valid(_grabbed_enemy):
		var cam_forward := -_camera.global_transform.basis.z.normalized()
		cam_forward.y = 0.0
		var target_pos := _player.global_position + cam_forward * 1.5 + Vector3(0, 0.3, 0)
		var current := _grabbed_enemy.global_position
		var smoothed := current.lerp(target_pos, 0.5)
		var dash_transform := Transform3D(_player.global_transform.basis, smoothed)
		_grabbed_enemy.update_grabbed_position(dash_transform, _delta)

	# 冲刺路径上的敌人碰撞检测——命中即停
	var space_state := get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = 1.5
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform = Transform3D(Basis(), _player.global_position)
	params.collision_mask = 1
	var results := space_state.intersect_shape(params, 16)
	for result in results:
		var body := result.get("collider") as Node3D
		if body == null:
			continue
		var enemy: Enemy = body.get_parent() as Enemy
		if enemy == null:
			enemy = body as Enemy
		if enemy == null or enemy == _grabbed_enemy:
			continue
		# 命中敌人：停止冲刺
		_player.stop_dash()
		# 伤害 + 击退（沿冲刺方向）
		var dmg := enemy.get_node_or_null("Damageable") as Damageable
		if dmg != null:
			dmg.take_damage(_whip_data.dash_damage, WeaponData.DamageType.MELEE)
		enemy.apply_knockback(_dash_direction, _whip_data.dash_knockback)
		# 1m 范围 AOE
		var all_enemies := get_tree().get_nodes_in_group("enemy")
		for node in all_enemies:
			if not is_instance_valid(node):
				continue
			var other: Enemy = node as Enemy
			if other == null or other == enemy:
				continue
			if other.global_position.distance_to(enemy.global_position) <= 1.0:
				var aoe_dmg := other.get_node_or_null("Damageable") as Damageable
				if aoe_dmg != null:
					aoe_dmg.take_damage(_whip_data.dash_damage, WeaponData.DamageType.MELEE)
				other.apply_knockback(_dash_direction, _whip_data.dash_knockback)
		# 结束冲刺
		_finish_dash()
		break


# ==============================================================================
# 处决（F 键）
# ==============================================================================
func _execute_grabbed() -> void:
	if _grabbed_enemy == null or not is_instance_valid(_grabbed_enemy):
		return

	var enemy := _grabbed_enemy

	enemy.execute()

	if GameBus.run_stats != null:
		GameBus.run_stats.add_kill(_whip_data.execution_score_bonus)
	GameBus.pickup_notification.emit("处决 +" + str(_whip_data.execution_score_bonus), Color(1.0, 0.3, 0.1))

	# execute() 可能触发 died→queue_free，需检查实例仍有效
	if is_instance_valid(enemy) and enemy.has_method("trigger_on_damaged"):
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


func is_grabbing() -> bool:
	return (_state == WhipState.GRABBING or _state == WhipState.SHIELDING) and _grabbed_enemy != null


func get_grabbed_enemy() -> Enemy:
	return _grabbed_enemy
	
# 升级系统——运行时修饰符更新（PlayerProgression 分发）
func apply_whip_upgrade(stat_key: String, value: float, operation: int) -> void:
	match stat_key:
		"whip_range":
			match operation:
				0: _whip_range_add += value
				1: _whip_range_mult *= value
		"cooldown":
			match operation:
				0: _cooldown_mult += value
				1: _cooldown_mult *= value
				2: _cooldown_mult = value
		"stun_damage":
			match operation:
				0: _stun_damage_mult += value
				1: _stun_damage_mult *= value
				2: _stun_damage_mult = value


# 设置被抓敌人半透明（替换式：新建材质避免修改共享材质）
func _set_enemy_transparent(enable: bool) -> void:
	if _grabbed_enemy == null or not is_instance_valid(_grabbed_enemy):
		return
	_enemy_transparent = enable
	for child in _grabbed_enemy.find_children("*"):
		var geo: Node3D = null
		if child is MeshInstance3D:
			geo = child as MeshInstance3D
		elif child is CSGShape3D:
			geo = child as CSGShape3D
		if geo == null:
			continue
		var key := geo.get_instance_id()
		if enable:
			# 保存原始 override，替换为新半透明材质
			if not _saved_materials.has(key):
				_saved_materials[key] = geo.material_override
			var trans_mat := StandardMaterial3D.new()
			if geo.material_override != null:
				var src := geo.material_override as StandardMaterial3D
				if src != null:
					trans_mat.albedo_color = src.albedo_color
			trans_mat.albedo_color.a = 0.35
			trans_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			trans_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			geo.material_override = trans_mat
		else:
			# 恢复原始材质
			if _saved_materials.has(key):
				geo.material_override = _saved_materials[key]
				_saved_materials.erase(key)


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

# ==============================================================================
# OrcEnemy — 普通近战兽人（持斧+圆盾）
# ==============================================================================
# 继承 Enemy 基类，使用 ATTACK_PREPARE/ACTIVE/RECOVER 三段式攻击，
# 具备 DEFENDING 举盾防御技能。
# 战斗逻辑：在 CLOSE 距离(1~3m)举盾防守+概率攻击，不主动进入 MELEE(<1m)。
# 玩家身边兽人 ≥3 时，远处兽人不再主动靠近，避免无限堆叠。
# ==============================================================================

class_name OrcEnemy extends Enemy


# ==============================================================================
# 内部变量
# ==============================================================================

var _axe_hand: Node3D = null       # 右手斧子父节点（用于攻击动画）
var _shield_node: Node3D = null    # 左手臂盾节点（用于防御动画）
var _attack_hitbox: Area3D = null  # 攻击判定框
var _axe_glow_mat: StandardMaterial3D = null  # 缓存斧头发光材质
var _axe_original_materials: Dictionary = {}  # 斧头原始 material_override 备份（用于恢复）


# ==============================================================================
# _ready() — 初始化武器引用
# ==============================================================================

func _ready() -> void:
	if enemy_data == null:
		enemy_data = load("res://assets/enemies/orc_melee.tres")
	super._ready()
	_axe_hand = get_node_or_null("RightHand")
	_shield_node = get_node_or_null("Shield/ShieldDisc")
	_create_attack_hitbox()


# ==============================================================================
# 状态进入/退出钩子
# ==============================================================================

func _state_entered(new_state: EnemyState) -> void:
	match new_state:
		EnemyState.ATTACK_PREPARE:
			_on_attack_prepare_entered()
		EnemyState.ATTACK_ACTIVE:
			_on_attack_active_entered()
		EnemyState.ATTACK_RECOVER:
			_on_attack_recover_entered()
		EnemyState.DEFENDING:
			_on_defending_entered()
		EnemyState.KNOCKED_DOWN:
			_on_knocked_down_entered()
		EnemyState.STUNNED:
			_on_stunned_entered()


func _state_exit(old_state: EnemyState) -> void:
	match old_state:
		EnemyState.ATTACK_PREPARE:
			_on_attack_prepare_exited()
		EnemyState.ATTACK_ACTIVE:
			_on_attack_active_exited()
		EnemyState.ATTACK_RECOVER:
			_on_attack_recover_exited()
		EnemyState.DEFENDING:
			_on_defending_exited()
		EnemyState.KNOCKED_DOWN:
			_on_knocked_down_exited()


# ==============================================================================
# AI 决策（覆写 _ai_tick）—— 每 0.1s 执行一次
# ==============================================================================
# 玩家身边兽人 ≥3 时，远处兽人不再靠近；只有近身兽人被杀后才会有新兽人替补
# ==============================================================================

func _ai_tick() -> void:
	if _player == null or enemy_data == null:
		return

	# 已在攻击流程或受控状态中，不打断
	if _is_in_attack_state():
		return
	if _state in [EnemyState.SPAWNING, EnemyState.STUNNED, EnemyState.GRABBED, EnemyState.PAIN, EnemyState.KNOCKED_DOWN, EnemyState.EXECUTED, EnemyState.DEATH]:
		return

	var bracket: int = get_player_distance_bracket()
	# 玩家身边已有多少兽人（3m 内）——防止无限堆叠
	var near_player: int = _count_enemies_near_player(3.0)

	match bracket:
		DistanceBracket.SUPER_FAR:  # >25m — 玩家身边人少时跑步接近
			if near_player >= 3:
				if _state != EnemyState.WALKING:
					_transition_to(EnemyState.WALKING)
			elif _state != EnemyState.RUNNING:
				_transition_to(EnemyState.RUNNING)

		DistanceBracket.FAR:  # 8~25m — 玩家身边满人则原地防御
			if near_player >= 3:
				if _state != EnemyState.DEFENDING:
					_transition_to(EnemyState.DEFENDING)
			elif _state != EnemyState.WALKING:
				_transition_to(EnemyState.WALKING)

		DistanceBracket.MEDIUM:  # 3~8m — 多敌包抄 / 单敌接近
			var nearby_count: int = _count_nearby_melee_enemies(2.0)
			if nearby_count > 2 or near_player >= 2:
				# 多敌：侧翼包抄 — 防御 + 横向移动
				if _state != EnemyState.DEFENDING:
					_transition_to(EnemyState.DEFENDING)
				_strafe_around_player(0.0, enemy_data.move_speed * 0.5)
			else:
				if _state != EnemyState.WALKING:
					_transition_to(EnemyState.WALKING)

		DistanceBracket.CLOSE:  # 1~3m — 主战斗距离：举盾 + 概率攻击
			if _state not in [EnemyState.DEFENDING, EnemyState.ATTACK_PREPARE, EnemyState.ATTACK_ACTIVE, EnemyState.ATTACK_RECOVER]:
				if randf() < enemy_data.attack_probability and _attack_cooldown_timer <= 0.0:
					_transition_to(EnemyState.ATTACK_PREPARE)
					return
			else:
				# 已在防御中：每 2s 试探一次攻击，避免永远站桩
				if _state_timer > 2.0 and randf() < 0.3 and _attack_cooldown_timer <= 0.0:
					_transition_to(EnemyState.ATTACK_PREPARE)
					return
			if _state != EnemyState.DEFENDING:
				_transition_to(EnemyState.DEFENDING)

		DistanceBracket.MELEE:  # <1m — 不进入贴身：后退到近距离
			if _state != EnemyState.DEFENDING:
				_transition_to(EnemyState.DEFENDING)


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


## 统计玩家身边指定范围内的敌人数量（决定远处兽人是否进场）
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
# 攻击阶段处理
# ==============================================================================

func _on_attack_prepare_entered() -> void:
	# 瞬移靠近玩家至 ~1m（近战范围边界），而非贴身
	if _player != null:
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		var dist := to_player.length()
		if dist > 1.0:
			var dir := to_player.normalized()
			global_position += dir * (dist - 1.0) * 0.3
	# 举斧发光 + 向后旋转30°（蓄力姿态）
	if _axe_hand != null:
		_set_node_glow(_axe_hand, true)
		var tween := create_tween()
		tween.tween_property(_axe_hand, "rotation_degrees:x", 30.0, 0.3)


func _on_attack_prepare_exited() -> void:
	# 关闭发光 + 武器回正（无论被打断还是正常过渡）
	if _axe_hand != null:
		_set_node_glow(_axe_hand, false)
		var tween := create_tween()
		tween.tween_property(_axe_hand, "rotation_degrees:x", 0.0, 0.15)


func _on_attack_active_entered() -> void:
	# 从当前蓄力角度向前挥砍一整圈（30°→0°→-330°连续过渡）
	if _axe_hand != null:
		var current_x := _axe_hand.rotation_degrees.x
		var tween := create_tween()
		tween.tween_property(_axe_hand, "rotation_degrees:x", current_x - 360.0, 0.3)
	# 激活攻击判定框
	if _attack_hitbox != null:
		_attack_hitbox.monitoring = true
		# 处理已重叠的玩家（body_entered 不会对已重叠身体触发）
		for body in _attack_hitbox.get_overlapping_bodies():
			if body == _player:
				_damage_player(enemy_data.attack_damage, WeaponData.DamageType.MELEE)
				break


func _on_attack_active_exited() -> void:
	# 关闭攻击判定框
	if _attack_hitbox != null:
		_attack_hitbox.monitoring = false


func _on_attack_recover_entered() -> void:
	pass


func _on_attack_recover_exited() -> void:
	# 攻击收刀完成：斧子回正到竖持位置
	if _axe_hand != null:
		var tween := create_tween()
		tween.tween_property(_axe_hand, "rotation_degrees:x", 0.0, 0.15)


func _on_stunned_entered() -> void:
	# 眩晕：武器回正 + 先闪白（脉冲由基类 _state_stunned 统一驱动）
	if _axe_hand != null:
		_axe_hand.rotation_degrees = Vector3(0, 0, 0)
	_flash_pain(Color.WHITE)
	_stun_flash_toggle = true


func _stun_pulse() -> void:
	if _state == EnemyState.STUNNED:
		# 交替青蓝色和白色，0.4s 间隔快速闪烁
		var is_white := _stun_flash_toggle
		_stun_flash_toggle = not _stun_flash_toggle
		_flash_pain(Color.WHITE if is_white else Color(0.3, 0.7, 1.0))
		var t := get_tree().create_timer(0.4)
		t.timeout.connect(_stun_pulse)


# ==============================================================================
# 防御阶段 — 覆写基类，增加贴身自动后退
# ==============================================================================

# 覆写基类 CHASE：攻击完成后不进入旧版 ATTACK 循环，改为防御/后退
func _state_chase(delta: float) -> void:
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist > enemy_data.sight_range * 1.5:
		_transition_to(EnemyState.IDLE)
		return
	if dist <= enemy_data.attack_range:
		# 不进入 ATTACK，让 AI tick 决定下一步（DEFENDING 或 ATTACK_PREPARE）
		_transition_to(EnemyState.DEFENDING)
		return
	_move_towards_player(delta, enemy_data.move_speed)
	velocity.y = 0.0
	_face_player_flat()


func _state_defending(_delta: float) -> void:
	velocity.y = 0.0
	if _player != null:
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		var dist := to_player.length()
		if dist < 1.0:
			# 贴身范围：自动后退
			_move_away_from_player(0.0, enemy_data.move_speed * 0.6)
	_face_player_flat()


func _on_defending_entered() -> void:
	# 举盾：盾牌移至身前 + 沿Y轴旋转
	if _shield_node != null:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_shield_node, "position", Vector3(0.0, 1.0, -0.4), 0.2)
		tween.tween_property(_shield_node, "rotation_degrees:y", -90.0, 0.2)


func _on_defending_exited() -> void:
	# 收盾：盾牌回左侧 + 恢复旋转
	if _shield_node != null:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_shield_node, "position", Vector3(-0.4, 1.2, -0.1), 0.2)
		tween.tween_property(_shield_node, "rotation_degrees:y", 0.0, 0.2)


# ==============================================================================
# 倒地处理
# ==============================================================================

func _on_knocked_down_entered() -> void:
	# 倒地视觉
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.65, 0.65, 0.65), 0.15)


func _on_knocked_down_exited() -> void:
	# 恢复站立
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.15)


# ==============================================================================
# 覆写 _execute_attack — 伤害由攻击判定框(Area3D)处理，基类版本不执行
# ==============================================================================
func _execute_attack() -> void:
	pass  # 攻击判定由 hitbox 的 body_entered 信号处理


# ==============================================================================
# 覆写受伤：防御状态下扣护甲 + Counter 检测
# ==============================================================================

func _on_damaged(amount: float, _type: WeaponData.DamageType) -> void:
	if _state == EnemyState.DEATH:
		return

	# 增伤标记加成（继承自基类）
	if _damage_mark_timer > 0.0:
		amount *= _damage_mark_multiplier
		_damage_mark_multiplier = 1.0
		_damage_mark_timer = 0.0

	# 护甲吸收（所有状态通用，先于 ATTACK_PREPARE/ATTACK_ACTIVE 特殊处理）
	if _current_armor > 0.0:
		var absorbed: float = deplete_armor(amount)
		amount -= absorbed
		if absorbed > 0.0 and _damageable != null:
			_damageable.health = minf(_damageable.health + absorbed, _damageable.max_health)
		if amount <= 0.0:
			_flash_pain(Color(0.6, 0.6, 0.7))
			return

	# ATTACK_PREPARE 受击：3倍眩晕但不触发 Counter
	if _state == EnemyState.ATTACK_PREPARE:
		apply_stun(amount * 3.0)
		_flash_pain(Color(0.7, 0.7, 0.3))
		_transition_to(EnemyState.PAIN)
		return

	# Counter 检测：仅 ATTACK_ACTIVE 判定窗口受击触发，直接眩晕满
	if _state == EnemyState.ATTACK_ACTIVE:
		# 武器回正（打断攻击动画）
		if _axe_hand != null:
			_axe_hand.rotation_degrees = Vector3(0, 0, 0)
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

	if _type == WeaponData.DamageType.MELEE:
		_flash_pain(Color(0.5, 0.5, 0.5))
	else:
		_flash_pain(Color.WHITE)

	if _state != EnemyState.STUNNED and _state != EnemyState.GRABBED:
		_transition_to(EnemyState.PAIN)


# ==============================================================================
# 攻击判定框
# ==============================================================================

func _create_attack_hitbox() -> void:
	_attack_hitbox = Area3D.new()
	_attack_hitbox.name = "AttackHitbox"
	_attack_hitbox.monitoring = false
	_attack_hitbox.monitorable = false

	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# 判定框在兽人前方 1m，1.2×1.2×1.2 覆盖正面近战范围
	box.size = Vector3(1.2, 1.2, 1.2)
	collision.shape = box
	# Godot 坐标系中 -Z 是前方（look_at 朝向玩家）
	collision.position = Vector3(0.3, 0.8, -1.2)
	_attack_hitbox.add_child(collision)

	_attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	add_child(_attack_hitbox)


func _on_attack_hitbox_body_entered(body: Node3D) -> void:
	if body == _player:
		_damage_player(enemy_data.attack_damage, WeaponData.DamageType.MELEE)


# ==============================================================================
# 工具方法
# ==============================================================================

func _set_node_glow(node: Node3D, glow: bool) -> void:
	if glow and _axe_glow_mat == null:
		_axe_glow_mat = StandardMaterial3D.new()
		_axe_glow_mat.albedo_color = Color(1.0, 0.5, 0.0)
		_axe_glow_mat.emission_enabled = true
		_axe_glow_mat.emission = Color(1.0, 0.5, 0.0)
		_axe_glow_mat.emission_energy_multiplier = 1.0

	for child in node.get_children():
		if child is MeshInstance3D or child is CSGShape3D:
			var geo: Node3D = child
			if glow:
				# 备份原始材质，再覆盖发光材质
				_axe_original_materials[geo.get_instance_id()] = geo.material_override
				geo.material_override = _axe_glow_mat
			else:
				# 恢复原始材质（.tscn 中的白银色）而非置 null
				var original: Material = _axe_original_materials.get(geo.get_instance_id())
				geo.material_override = original if original != null else null

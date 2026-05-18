# ==============================================================================
# OrcEnemy — 普通近战兽人（持斧+圆盾）
# ==============================================================================
# 继承 Enemy 基类，使用 ATTACK_PREPARE/ACTIVE/RECOVER 三段式攻击，
# 具备 DEFENDING 举盾防御技能。
# ==============================================================================

class_name OrcEnemy extends Enemy


# ==============================================================================
# 内部变量
# ==============================================================================

var _axe_hand: Node3D = null       # 右手斧子父节点（用于攻击动画）
var _shield_node: Node3D = null    # 左手臂盾节点（用于防御动画）
var _attack_hitbox: Area3D = null  # 攻击判定框


# ==============================================================================
# _ready() — 初始化武器引用
# ==============================================================================

func _ready() -> void:
	super._ready()
	_axe_hand = get_node_or_null("RightHand")
	_shield_node = get_node_or_null("Shield")
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


func _state_exit(old_state: EnemyState) -> void:
	match old_state:
		EnemyState.ATTACK_PREPARE:
			_on_attack_prepare_exited()
		EnemyState.ATTACK_ACTIVE:
			_on_attack_active_exited()
		EnemyState.DEFENDING:
			_on_defending_exited()


# ==============================================================================
# AI 决策（覆写 _ai_tick）
# ==============================================================================

func _ai_tick() -> void:
	if _player == null or enemy_data == null:
		return

	var bracket: int = get_player_distance_bracket()

	match bracket:
		DistanceBracket.SUPER_FAR:  # >5m
			if _state != EnemyState.RUNNING and _state != EnemyState.CHASE:
				_transition_to(EnemyState.RUNNING)

		DistanceBracket.FAR:  # 2~5m
			if enemy_data.can_defend:
				if _state != EnemyState.DEFENDING:
					_transition_to(EnemyState.DEFENDING)
			elif _state != EnemyState.WALKING:
				_transition_to(EnemyState.WALKING)

		DistanceBracket.MEDIUM:  # 1~2m
			# 检查周围近战敌人数量
			var nearby_count: int = _count_nearby_melee_enemies(2.0)
			if nearby_count > 2:
				# 侧翼包抄：防御 + 横向移动
				if _state != EnemyState.DEFENDING:
					_transition_to(EnemyState.DEFENDING)
				_strafe_around_player(0.0, enemy_data.move_speed * 0.5)
			else:
				if _state != EnemyState.DEFENDING:
					_transition_to(EnemyState.DEFENDING)

		DistanceBracket.CLOSE:  # 0.5~1m
			# 中等概率攻击
			if randf() < 0.4:
				if _attack_cooldown_timer <= 0.0:
					_transition_to(EnemyState.ATTACK_PREPARE)
					return
			if _state != EnemyState.DEFENDING:
				_transition_to(EnemyState.DEFENDING)

		DistanceBracket.MELEE:  # <0.5m
			if _attack_cooldown_timer <= 0.0:
				_transition_to(EnemyState.ATTACK_PREPARE)


## 统计周围指定范围内的近战敌人数量
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


# ==============================================================================
# 攻击阶段处理
# ==============================================================================

func _on_attack_prepare_entered() -> void:
	# 快速跑至距玩家 0.5m 处
	if _player != null:
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		var dist := to_player.length()
		if dist > 0.5:
			var dir := to_player.normalized()
			global_position += dir * (dist - 0.5) * 0.3
	# 举斧发光提示
	if _axe_hand != null:
		_set_node_glow(_axe_hand, true)


func _on_attack_prepare_exited() -> void:
	if _axe_hand != null:
		_set_node_glow(_axe_hand, false)


func _on_attack_active_entered() -> void:
	# 激活攻击判定框
	if _attack_hitbox != null:
		_attack_hitbox.monitoring = true


func _on_attack_active_exited() -> void:
	# 关闭攻击判定框
	if _attack_hitbox != null:
		_attack_hitbox.monitoring = false


func _on_attack_recover_entered() -> void:
	pass


# ==============================================================================
# 防御阶段处理
# ==============================================================================

func _on_defending_entered() -> void:
	# 举盾视觉
	if _shield_node != null:
		var tween := create_tween()
		tween.tween_property(_shield_node, "position", Vector3(0.1, 0.6, 0.4), 0.2)


func _on_defending_exited() -> void:
	# 收盾
	if _shield_node != null:
		var tween := create_tween()
		tween.tween_property(_shield_node, "position", Vector3(-0.3, 1.0, 0.1), 0.2)


# ==============================================================================
# 倒地处理
# ==============================================================================

func _on_knocked_down_entered() -> void:
	# 倒地视觉
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.0, 0.4, 1.0), 0.15)


# ==============================================================================
# 覆写受伤：防御状态下扣护甲 + Counter 检测
# ==============================================================================

func _on_damaged(amount: float, type: WeaponData.DamageType) -> void:
	if _state == EnemyState.DEATH:
		return

	# Counter 检测
	if _is_in_attack_state():
		GameBus.counter_triggered.emit(self, global_position)
		apply_stun(amount * 2.0)
		_flash_pain(Color(0.3, 0.7, 1.0))
		_transition_to(EnemyState.PAIN)
		return

	# 防御状态：扣护甲
	if _state == EnemyState.DEFENDING and enemy_data != null and enemy_data.armor > 0.0:
		var absorbed: float = mini(amount, enemy_data.armor)
		enemy_data.armor -= absorbed
		amount -= absorbed
		if amount <= 0.0:
			_flash_pain(Color(0.6, 0.6, 0.7))  # 护甲格挡闪白
			return

	if type == WeaponData.DamageType.MELEE:
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
	box.size = Vector3(0.5, 0.5, 0.5)
	collision.shape = box
	collision.position = Vector3(0.3, 0.0, 0.6)  # 右手前方
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
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh: MeshInstance3D = child
			if glow:
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(1.0, 0.5, 0.0)
				mat.emission_enabled = true
				mat.emission = Color(1.0, 0.5, 0.0)
				mat.emission_energy_multiplier = 1.0
				mesh.material_override = mat
			else:
				mesh.material_override = null
		elif child is CSGShape3D:
			var csg: CSGShape3D = child
			if glow:
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(1.0, 0.5, 0.0)
				mat.emission_enabled = true
				mat.emission = Color(1.0, 0.5, 0.0)
				mat.emission_energy_multiplier = 1.0
				csg.material_override = mat
			else:
				csg.material_override = null

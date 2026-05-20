# ==============================================================================
# WeaponNode — 武器节点基类
# ==============================================================================
# 所有武器（手枪、霰弹枪、未来步枪……）的共同"大脑"。
# 挂在 WeaponManager 下面，负责：
#   1. 读取 WeaponData 中的配置参数
#   2. 从摄像机中心发射射线（射线检测 = 开枪即命中，无飞行时间）
#   3. 管理弹药（弹匣 + 备弹）
#   4. 换弹逻辑（R 键换弹，换弹中不能开枪）
#   5. 散布计算（准星扩散角度 + 移动惩罚）
#   6. 射击后坐力（枪口上跳视觉反馈）
#
# 子类（Pistol、Shotgun）只需要覆写 _setup_model() 创建不同的外观模型即可，
# 射击、弹药、换弹逻辑全部在基类里完成，不需要重复写。
# ==============================================================================

class_name WeaponNode extends Node3D


# ==============================================================================
# 信号
# ==============================================================================

## 武器开火时发射——用于触发枪口闪光、音效等
signal fired()

## 子弹命中某物时发射——比如用于生成弹孔、火花特效
## @param hit_point 世界坐标命中点
## @param hit_normal 命中面的法线方向（用于正确朝向弹孔贴花）
## @param target 被命中的节点（可能是墙壁 CSGBox3D、靶子、敌人）
signal hit_something(hit_point: Vector3, hit_normal: Vector3, target: Node)

## 弹药数量改变时发射——给 HUD 更新显示用
## @param current_mag 当前弹匣剩余
## @param reserve 当前备弹剩余
signal ammo_changed(current_mag: int, reserve: int)

## 换弹开始时发射——给 HUD 显示"换弹中…"提示
## @param reload_time 换弹需要的秒数
signal reload_started(reload_time: float)

## 换弹完成时发射
signal reload_finished()


# ==============================================================================
# 导出属性
# ==============================================================================

## 武器的配置数据——在编辑器中拖入一个 WeaponData 资源文件（.tres）
@export var weapon_data: WeaponData


# ==============================================================================
# 运行时状态变量（不带 @export，因为不是配置，是"当前状态"）
# ==============================================================================

## 对摄像机节点的引用——射击射线从摄像机中心发出
var _camera: Camera3D

## 当前弹匣里还剩多少发子弹
var _current_mag: int = 0

## 备弹还剩多少发
var _current_reserve: int = 0

## 是否可以开火——泵动式霰弹枪拉泵期间为 false
var _can_fire: bool = true

## 是否正在换弹中
var _is_reloading: bool = false

## 是否当前装备中（0.3：未装备时不响应输入）
var _is_equipped: bool = false

## 射击冷却计时器（秒）——倒计时，归零后才能打下一发
var _fire_cooldown: float = 0.0

## 换弹 token——切武器后递增，使旧 timer 失效（0.4）
var _reload_token: int = 0

## 泵动 token——切武器后递增，使旧泵动 timer 失效（0.4）
var _pump_token: int = 0

## 后坐力 tween 引用——连发时 kill 旧 tween 防止堆积
var _recoil_tween: Tween = null

## 换弹动画 tween
var _reload_tween: Tween = null

## 后坐力基准位置——武器初始位置，防止累积上移
var _recoil_base_pos: Vector3 = Vector3.ZERO
var _recoil_base_set: bool = false
var _reload_base_rot: Vector3 = Vector3.ZERO
var _reload_base_pos: Vector3 = Vector3.ZERO
var _reload_base_pos_set: bool = false


# ==============================================================================
# 子节点引用（在 _ready 中动态创建）
# ==============================================================================

## 枪口位置标记——用于确定枪口闪光从哪里出现
var _muzzle: Marker3D

## 动画播放器——后续用于播放射击、换弹动画
var _anim_player: AnimationPlayer


# ==============================================================================
# setup() — 初始化武器，由 WeaponManager 调用
# ==============================================================================
# 因为武器是在 WeaponManager 中通过代码创建的（不是从场景文件加载），
# 所以不能用 @onready 获取摄像机引用。改用这个 setup() 方法，
# WeaponManager 在创建武器后会立即调用它。
#
# 参数：
#   data   —— 武器的配置数据（手枪/霰弹枪的 .tres 文件）
#   camera —— 玩家摄像机的引用，射击射线从这里发射
func setup(data: WeaponData, camera: Camera3D) -> void:
	weapon_data = data
	_camera = camera
	_current_mag = data.mag_size
	_current_reserve = data.reserve_ammo
	_fire_cooldown = 0.0


# ==============================================================================
# _ready() — 创建必须的子节点和外观模型
# ==============================================================================
func _ready() -> void:
	# 1. 创建枪口位置标记——放在武器前方，后续枪口闪光粒子从这里发射
	_muzzle = Marker3D.new()
	_muzzle.name = "MuzzleFlash"
	_muzzle.position = Vector3(0.0, 0.0, -0.5)    # 默认枪口位置：前方 0.5 米
	add_child(_muzzle)

	# 2. 创建动画播放器——射击动画、换弹动画都用它
	_anim_player = AnimationPlayer.new()
	_anim_player.name = "AnimationPlayer"
	add_child(_anim_player)

	# 3. 让子类创建它特定的外观模型（手枪形状 vs 霰弹枪形状）
	_setup_model()


# ==============================================================================
# _setup_model() — 创建武器外观模型（子类覆写此方法）
# ==============================================================================
# 基类默认什么都不做。子类（Pistol、Shotgun）会在此方法中创建
# CSGBox3D 拼成的占位模型。
func _setup_model() -> void:
	pass


# ==============================================================================
# _process(delta) — 每渲染帧自动调用
# ==============================================================================
# 在这里处理两件事：
#   1. 射击冷却倒计时（无论什么射击模式都要等冷却）
#   2. 全自动武器的"按住连发"检测（半自动和泵动式走 _input 触发）
func _process(delta: float) -> void:
	# --- 射击冷却倒计时 ---
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta

	# --- 全自动模式：按住鼠标疯狂开火 ---
	# 0.3：未装备时不处理输入
	if not _is_equipped or weapon_data == null:
		return

	if weapon_data.fire_mode == WeaponData.FireMode.AUTO:
		if Input.is_action_pressed("primary_fire"):
			_try_fire()


# ==============================================================================
# _input(event) — 处理射击和换弹输入
# ==============================================================================
# Godot 每帧对场景树中所有有 _input 的节点调用一次。
# 这里只处理瞬间动作（半自动开枪、换弹），
# 全自动模式在 _process 里通过 is_action_pressed 处理。
func _input(event: InputEvent) -> void:
	if not _is_equipped or weapon_data == null:
		return

	# --- 半自动 + 泵动式：按一下打一发 ---
	# is_action_just_pressed() 只在按键"刚按下的那一帧"返回 true。
	# 这样即使按住鼠标不放，也不会变成全自动连发。
	if event.is_action_pressed("primary_fire"):
		if weapon_data.fire_mode != WeaponData.FireMode.AUTO:
			_try_fire()

	# --- 换弹键：R 键 ---
	if event.is_action_pressed("reload"):
		_start_reload()


# ==============================================================================
# _try_fire() — 尝试开火（做所有检查，通过后调用 _fire()）
# ==============================================================================
# 这是开火的"门卫"——检查所有阻止开火的条件：
#   1. 泵动没完成？
#   2. 正在换弹？
#   3. 射速冷却没到？
#   4. 弹匣空了？
# 全部通过后才放行到 _fire()。
func _try_fire() -> void:
	# 检查 1：泵动式正在拉泵
	if not _can_fire:
		return

	# 检查 2：正在换弹中（换弹时不能开枪）
	if _is_reloading:
		return

	# 检查 3：射速冷却还没到（武器"还在后坐"）
	if _fire_cooldown > 0.0:
		return

	# 检查 4：弹匣空了——自动触发换弹
	if _current_mag <= 0:
		_start_reload()
		return

	# 所有检查通过，开枪！
	_fire()


# ==============================================================================
# _fire() — 执行开火
# ==============================================================================
# 每把枪的开火流程都一样：
#   1. 为每颗弹丸计算一个随机散布方向
#   2. 从摄像机中心向那个方向发射一根射线
#   3. 检查射线撞到了什么（靶子？墙壁？敌人？）
#   4. 扣弹药、设冷却、发射信号
#
# 霰弹枪 pellet_count=7 → 循环 7 次，每次随机方向不同 → 散射效果
# 手枪 pellet_count=1 → 循环 1 次，方向接近准星中心 → 精准射击
func _fire() -> void:
	# 近战武器：短距离判定
	if weapon_data.is_melee:
		_fire_melee()
		return

	# 为每颗弹丸分别发射一根射线
	for i in range(weapon_data.pellet_count):
		# 计算这颗弹丸的随机散布方向
		var spread_dir := _get_spread_direction(i)
		_fire_single_pellet(spread_dir)

	# --- 弹药管理 ---
	if not weapon_data.infinite_ammo:
		_current_mag -= 1

	# --- 射速冷却 ---
	_fire_cooldown = 1.0 / weapon_data.fire_rate

	# --- 视觉反馈 ---
	_apply_recoil()

	# --- 发射信号 ---
	fired.emit()
	ammo_changed.emit(_current_mag, _current_reserve)

	# --- 泵动式：射击后锁定，等待泵动完成 ---
	if weapon_data.fire_mode == WeaponData.FireMode.PUMP:
		_start_pump()
	# --- 弹匣打空：自动换弹（无限弹药跳过） ---
	elif _current_mag <= 0 and not weapon_data.infinite_ammo:
		_start_reload()


# ==============================================================================
# _fire_melee() — 近战攻击（拳头等）
# ==============================================================================
func _fire_melee() -> void:
	var space_state := get_world_3d().direct_space_state
	var origin := _camera.global_position
	var dir := -_camera.global_transform.basis.z.normalized()
	var end: Vector3 = origin + dir * weapon_data.melee_range
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = 1

	var result := space_state.intersect_ray(query)

	if result.is_empty():
		_spawn_tracer(_muzzle.global_position, end)
	else:
		var hit_point: Vector3 = result.position
		var hit_normal: Vector3 = result.normal
		var target: Node = result.collider
		_spawn_tracer(_muzzle.global_position, hit_point)
		if target.has_method("take_damage"):
			target.take_damage(weapon_data.damage, weapon_data.damage_type)
			_try_apply_stun(target)
			_try_apply_knockback(target, dir)
			_spawn_damage_number(hit_point, weapon_data.damage, false)
			GameBus.play_sfx.emit("melee_hit", hit_point)
		else:
			_try_damage_child(target)
		hit_something.emit(hit_point, hit_normal, target)

	if not weapon_data.infinite_ammo:
		_current_mag -= 1

	_fire_cooldown = 1.0 / weapon_data.fire_rate
	_apply_recoil()
	fired.emit()
	ammo_changed.emit(_current_mag, _current_reserve)

	if _current_mag <= 0 and not weapon_data.infinite_ammo:
		_start_reload()


# ==============================================================================
# _fire_single_pellet(direction) — 发射单颗弹丸的射线
# ==============================================================================
# 这是射击系统的"物理核心"——从摄像机位置向指定方向发射一根看不见的射线，
# 检查射线撞到了什么东西，然后对撞到的东西造成伤害。
#
# 原理和激光笔一样：从枪口（摄像机）射出一道光，光碰到墙壁就停。
# 只是我们用的是物理引擎的射线检测，比光速还快——瞬间就知道结果。
#
# 参数：
#   direction —— 子弹飞行的世界空间方向（已经加了随机散布）
func _fire_single_pellet(direction: Vector3) -> void:
	# --- 第一步：获取物理世界的"空间状态" ---
	# direct_space_state 是物理引擎提供的查询接口，
	# 可以用来发射射线、检测重叠区域等。
	var space_state := get_world_3d().direct_space_state

	# --- 第二步：创建射线查询参数 ---
	# PhysicsRayQueryParameters3D.create() 创建一个射线查询对象。
	# 参数 1 = 射线起点（摄像机位置）
	# 参数 2 = 射线终点（起点 + 方向 × 射程）
	# 射线从起点出发，沿着 direction 方向飞行 range 米后停止。
	var origin := _camera.global_position
	var end: Vector3 = origin + direction * weapon_data.max_range
	var query := PhysicsRayQueryParameters3D.create(origin, end)

	# 碰撞掩码设为 1（默认碰撞层）——射线会撞到所有在层 1 上的物理体
	query.collision_mask = 1

	# --- 第三步：发射射线 ---
	# intersect_ray() 返回一个字典（Dictionary），包含碰撞信息。
	# 如果没撞到任何东西，返回空字典 {}。
	var result := space_state.intersect_ray(query)

	# 弹道线：命中或落空都生成
	if result.is_empty():
		_spawn_tracer(_muzzle.global_position, end)
		return
	var hit_point: Vector3 = result.position
	var hit_normal: Vector3 = result.normal
	var target: Node = result.collider
	_spawn_tracer(_muzzle.global_position, hit_point)
	if target.has_method("take_damage"):
		target.take_damage(weapon_data.damage, weapon_data.damage_type)
		_try_apply_stun(target)
		_try_apply_knockback(target, direction)
		_spawn_damage_number(hit_point, weapon_data.damage, false)
		GameBus.play_sfx.emit("bullet_hit", hit_point)
	else:
		_try_damage_child(target)
	hit_something.emit(hit_point, hit_normal, target)


# ==============================================================================
# _try_damage_child(node) — 递归查找 Damageable 子节点并造成伤害
# ==============================================================================
# 有些节点（比如 CSGBox3D 墙壁）本身没有 take_damage 方法，
# 但它们下面可能挂了一个 Damageable 子节点。
# 这个函数递归向上和向下查找 Damageable。
#
# 查找策略：
#   1. 先在当前节点的子节点中找 Damageable
#   2. 如果找到 → 造成伤害
#   3. 如果没找到 → 向父节点继续查找（最多查 3 层，防止无限递归）
func _try_damage_child(node: Node) -> void:
	# 在子节点中找 Damageable
	for child in node.get_children():
		if child is Damageable:
			child.take_damage(weapon_data.damage, weapon_data.damage_type)
			_try_apply_stun(node)
			return

	# 没找到？向父节点继续找（靶子的碰撞体可能是 CSGBox3D 的子节点）
	var parent := node.get_parent()
	if parent:
		_try_damage_child(parent)


# 对命中目标尝试施加眩晕——从 node 向上查找 Enemy 节点，找到后调用 apply_stun
func _try_apply_stun(node: Node) -> void:
	if weapon_data.stun_damage <= 0.0:
		return
	var current: Node = node
	while current != null:
		if current is Enemy and current.has_method("apply_stun"):
			current.apply_stun(weapon_data.stun_damage)
			return
		current = current.get_parent()


# 对命中目标尝试施加击退——从 node 向上查找 Enemy 节点
func _try_apply_knockback(node: Node, direction: Vector3) -> void:
	if weapon_data.knockback_force <= 0.0:
		return
	var current: Node = node
	while current != null:
		if current is Enemy and current.has_method("apply_knockback"):
			var kb_dir := direction.normalized()
			kb_dir.y = 0.0
			if kb_dir.length_squared() < 0.01:
				kb_dir = -_camera.global_transform.basis.z.normalized()
				kb_dir.y = 0.0
			current.apply_knockback(kb_dir, weapon_data.knockback_force)
			return
		current = current.get_parent()

# ==============================================================================
# _spawn_tracer(from, to) — 生成弹道线视效
# ==============================================================================
func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var dir := to - from
	var length := dir.length()
	if length < 0.01:
		return
	var mid := from + dir * 0.5
	var tracer := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.02, 0.02, length)
	tracer.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.4)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tracer.material_override = mat
	get_tree().root.add_child(tracer)
	tracer.global_position = mid
	tracer.look_at(to, Vector3.UP)
	var timer := get_tree().create_timer(0.12)
	timer.timeout.connect(tracer.queue_free)

# ==============================================================================
# _spawn_damage_number(pos, amount, is_stun) — 生成浮动伤害数字
# ==============================================================================
func _spawn_damage_number(pos: Vector3, amount: float, is_stun: bool) -> void:
	var label := Label3D.new()
	label.text = str(roundi(amount))
	label.font_size = 28
	if is_stun:
		label.modulate = Color(0.3, 0.6, 1.0)
	else:
		label.modulate = Color(1.0, 1.0, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos + Vector3(0, 1.0, 0)
	get_tree().root.add_child(label)

	var tween := create_tween()
	tween.tween_property(label, "position:y", pos.y + 2.0, 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


# ==============================================================================
# _get_spread_direction(pellet_index) — 计算加了散布之后的子弹方向
# ==============================================================================
# 如果 spread_angle = 0（完美精准），直接返回摄像机前方方向。
# 如果 spread_angle > 0，在"散布圆锥"内随机选一个方向。
#
# 散布圆锥：
#   以摄像机前方为轴，spread_angle 为半角画一个圆锥。
#   子弹的实际飞行方向在这个圆锥内均匀随机分布。
#   角度越大 → 圆锥越胖 → 子弹越散。
#
# 参数：
#   pellet_index —— 第几颗弹丸（不影响计算结果，预留参数）
#
# 返回：
#   归一化后的世界空间方向向量
func _get_spread_direction(_pellet_index: int) -> Vector3:
	# 基础方向 = 摄像机前方（注意：Godot 中 Camera3D 的前方是 -Z）
	var forward := -_camera.global_transform.basis.z.normalized()

	# 无散布 → 直接返回基础方向
	var spread_rad := deg_to_rad(weapon_data.spread_angle)
	if spread_rad < 0.0001:
		return forward

	# --- 在散布圆锥内随机取一个方向 ---
	# 数学原理：
	#   1. 在 [0, spread_rad] 范围内随机取一个偏离角度 angle
	#   2. 在 [0, 2π] 范围内随机取一个旋转角度 theta
	#   3. 把 forward 偏离 angle（绕一个随机垂直轴旋转）
	#
	# sqrt(randf()) 让弹丸在圆锥内"均匀分布"而不是集中在圆心附近。
	# (直觉：圆面积 = πr²，所以半径应该按 sqrt 来分配概率)
	var angle := sqrt(randf()) * spread_rad
	var theta := randf_range(0.0, TAU)  # TAU = 2π

	# 以摄像机前方为轴，构造两个垂直方向
	var up := _camera.global_transform.basis.y.normalized()
	var right := _camera.global_transform.basis.x.normalized()

	# 在垂直于 forward 的平面上取一个随机方向（角度 = theta）
	# 然后在 forward 和该方向之间用 angle 做旋转
	var perp := right * cos(theta) + up * sin(theta)

	# 最终方向 = forward 朝 perp 方向偏离 angle 度
	# 公式：方向 = forward×cos(angle) + perp×sin(angle)
	var result := forward * cos(angle) + perp * sin(angle)
	return result.normalized()


# ==============================================================================
# _start_reload() — 开始换弹
# ==============================================================================
# 换弹流程：
#   1. 检查是否已经在换弹（避免重复换弹）
#   2. 检查弹匣是否已满（满了没必要换）
#   3. 检查是否还有备弹（没备弹就换不进去）
#   4. 设 _is_reloading = true，阻止开枪
#   5. 等 reload_time 秒后调用 _finish_reload()
#
# 注意：切换武器会调用 _on_unequip()，其中会取消换弹状态。
func _start_reload() -> void:
	# 已经在换了，不重复触发
	if _is_reloading:
		return

	# 弹匣已经满了，没必要换弹
	if _current_mag >= weapon_data.mag_size:
		return

	# 没有备弹了，换了也是空的
	if _current_reserve <= 0:
		return

	# 标记"换弹中"，射手逻辑会靠这个标记阻止开枪
	_is_reloading = true
	_reload_token += 1
	var token := _reload_token
	reload_started.emit(weapon_data.reload_time)

	# 换弹动画：沿近玩家端（后端 +Z）向上旋转 90°
	var back_z := 0.25
	_reload_base_rot = rotation
	_reload_base_pos = position
	_reload_base_pos_set = true
	_reload_tween = create_tween()
	_reload_tween.set_parallel(true)
	var anim_time := weapon_data.reload_time * 0.12
	_reload_tween.tween_property(self, "rotation:x", deg_to_rad(90.0), anim_time)
	_reload_tween.tween_property(self, "position:y", position.y - back_z, anim_time)
	_reload_tween.tween_property(self, "position:z", position.z + back_z, anim_time)

	# 0.4：绑定 token，timer 触发时检查是否仍有效
	var timer := get_tree().create_timer(weapon_data.reload_time)
	timer.timeout.connect(_finish_reload.bind(token))


# ==============================================================================
# _finish_reload() — 换弹完成：从备弹补充到弹匣
# ==============================================================================
func _finish_reload(token: int) -> void:
	# 0.4：token 不匹配说明已切武器，忽略
	if token != _reload_token:
		return

	var needed: int = weapon_data.mag_size - _current_mag
	var available: int = min(needed, _current_reserve)

	_current_mag += available
	_current_reserve -= available
	_is_reloading = false

	# 恢复武器姿态
	if _reload_tween != null and _reload_tween.is_valid():
		_reload_tween.kill()
	var restore_tween := create_tween()
	restore_tween.set_parallel(true)
	restore_tween.tween_property(self, "rotation:x", _reload_base_rot.x, 0.2)
	if _reload_base_pos_set:
		restore_tween.tween_property(self, "position", _reload_base_pos, 0.2)
		_reload_base_pos_set = false

	ammo_changed.emit(_current_mag, _current_reserve)
	reload_finished.emit()


# ==============================================================================
# _start_pump() / _finish_pump() — 泵动式武器的拉泵周期
# ==============================================================================
# 泵动式霰弹枪：开一枪 → 拉泵 → 才能开下一枪
# 拉泵期间 _can_fire = false，阻止继续射击。
# 拉泵时间固定 0.5 秒（后续可改为动画时长）。
# 拉泵完成后如果弹匣空了，自动开始换弹。

func _start_pump() -> void:
	_can_fire = false
	_pump_token += 1
	var token := _pump_token
	var timer := get_tree().create_timer(0.5)
	timer.timeout.connect(_finish_pump.bind(token))

func _finish_pump(token: int) -> void:
	# 0.4：token 不匹配说明已切武器，忽略
	if token != _pump_token:
		return
	_can_fire = true
	if _current_mag <= 0:
		_start_reload()


# ==============================================================================
# _apply_recoil() — 射击后坐力视觉反馈
# ==============================================================================
# DOOM 里开枪时枪口会上跳一下然后恢复——这就是后坐力。
# 这里用 Tween 做一个"快速上跳 → 慢速回落"的两段动画：
#   1. 0.03 秒内武器向上移 0.03 米、向后移 0.06 米（模拟后坐力冲击）
#   2. 0.15 秒内武器恢复到原位
#
# 两段动画连起来 = 杆子被撞了一下 → 弹回来的感觉。
func _apply_recoil() -> void:
	# 用固定的基准位置，防止连发累积上移
	if not _recoil_base_set:
		_recoil_base_pos = position
		_recoil_base_set = true
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()

	_recoil_tween = create_tween()
	_recoil_tween.tween_property(self, "position",
		_recoil_base_pos + Vector3(0.0, 0.03, 0.06), 0.03)
	_recoil_tween.tween_property(self, "position", _recoil_base_pos, 0.15)


# ==============================================================================
# _on_equip() / _on_unequip() — 武器被切换时的回调
# ==============================================================================
# 由 WeaponManager 在切换武器时调用，不是 Godot 内置回调。
#
# _on_equip()：武器被选中——显示模型、通知 HUD 当前弹药
# _on_unequip()：武器被切走——隐藏模型、取消进行中的换弹

func _on_equip() -> void:
	_is_equipped = true
	visible = true
	ammo_changed.emit(_current_mag, _current_reserve)

func _on_unequip() -> void:
	_is_equipped = false
	visible = false
	# 切换武器时中断换弹（否则新武器也显示"换弹中"）
	if _is_reloading:
		_is_reloading = false
	# 终止换弹动画，恢复姿态
	if _reload_tween != null and _reload_tween.is_valid():
		_reload_tween.kill()
		rotation.x = _reload_base_rot.x
		if _reload_base_pos_set:
			position = _reload_base_pos
			_reload_base_pos_set = false
	# 0.4：递增 token 使旧 timer 失效
	_reload_token += 1
	_pump_token += 1


# ==============================================================================
# reset_ammo() — 重置弹药到满弹匣+满备弹（关卡重启/重新开始时调用）
# ==============================================================================
# 弹药系统中有两个独立的数量需要重置：
#   _current_mag     = 当前弹匣里的子弹数（比如手枪 8 发）
#   _current_reserve = 后备弹药数（比如手枪 50 发）
#
# 这两种弹药在游戏过程中会被消耗：
#   - 每次开枪：_current_mag 减 1（弹匣打光自动换弹或手动 R 换弹）
#   - 每次换弹：从 _current_reserve 取出子弹填满 _current_mag
#
# 当关卡重启时，需要把弹药恢复到开局状态——弹匣装满、备弹补满。
# 这和 setup() 中的初始化逻辑完全一样，但 setup() 只在新创建武器时
# 调用一次（在 WeaponManager._ready() 中）。
#
# 调用时机（Phase 2+）：
#   - 选关后进入新关卡时（由 WeaponManager.reset_all_weapons() 遍历调用）
#   - 结算界面点击"重新开始"时
#
# 为什么需要发射 ammo_changed 信号：
#   重置后弹药数量变了，HUD 需要立即更新弹药显示（比如从 "2/15" 变回 "8/50"）。
#   如果不发射信号，HUD 要等到下次开枪或换弹才会刷新，看上去像是"没重置"。
#
# 类比：
#   打了一局后子弹打光了 → 重新开始 → 上膛装弹，子弹回到初始状态。
func reset_ammo() -> void:
	_current_mag = weapon_data.mag_size
	_current_reserve = weapon_data.reserve_ammo
	ammo_changed.emit(_current_mag, _current_reserve)


# ==============================================================================
# 公共访问器 —— 供其他模块（Pickup / HUD）读取/修改弹药
# ==============================================================================

## 补充备弹（ammo_pickup 拾取时调用）
func add_reserve_ammo(amount: int) -> void:
	_current_reserve += amount
	ammo_changed.emit(_current_mag, _current_reserve)

## 返回当前弹匣弹药数（HUD 显示用）
func get_current_mag() -> int:
	return _current_mag

## 返回当前备弹数（HUD 显示用）
func get_current_reserve() -> int:
	return _current_reserve

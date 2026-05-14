# ==============================================================================
# PlayerController — 第一人称玩家控制器
# ==============================================================================
# 挂在 Player 节点（CharacterBody3D）上。
# 负责四件事：
#   1. 鼠标旋转视角（左右看 + 上下看）
#   2. WASD 移动（前后左右走）
#   3. 重力（让玩家落在地面上）
#   4. 空格跳跃（只有站在地上时才能跳）
# ==============================================================================

# extends 意思是"继承"——这个脚本扩展了 CharacterBody3D 类的功能。
# CharacterBody3D 是 Godot 专门为"代码控制移动"设计的 3D 物理体，
# 自带碰撞检测、move_and_slide() 等好用方法。
extends CharacterBody3D


# ==============================================================================
# 移动参数（@export 表示这些值可以在 Godot 编辑器右侧面板直接修改，不用改代码）
# ==============================================================================

## 最大移动速度（米/秒），8.0 相当于每秒走 8 米，偏快，适合 DOOM 风格
@export var move_speed := 8.0

## 加速度——数值越大，玩家按 W 后"蹬地加速"越快
@export var acceleration := 40.0

## 摩擦力——数值越大，松开按键后停得越快（地板滑不滑）
@export var friction := 30.0


# ==============================================================================
# 重力 与 跳跃
# ==============================================================================

## 重力加速度（米/秒²）。真实世界是 9.8，这里用 20 让下落更快、手感更爽快。
#  重力越大 → 跳起后落地越快 → 手感越"沉"
#  重力越小 → 跳起后飘得越久 → 手感越"轻"（像在月球上）
@export var gravity := 20.0

## 跳跃力度——按下空格时给角色一个向上的"瞬间推力"。
#  数值越大跳得越高。12 大概能跳 2~3 米左右（取决于重力大小）。
#
#  跳跃最高点的高度公式（近似）：
#    jump_velocity² ÷ (2 × gravity)
#    例：12² ÷ (2 × 20) = 144 ÷ 40 = 3.6 米
#
#  如果你觉得跳太高或太低，调这个数值最直接。
@export var jump_velocity := 12.0


# ==============================================================================
# 鼠标设置
# ==============================================================================

## 鼠标灵敏度。0.002 是比较适中的值，数字越大转得越快
@export var mouse_sensitivity := 0.002

## 是否反转 Y 轴（飞机摇杆风格），默认 false = 不反转
@export var invert_y := false

## 上下看的最大角度限制（度数）。90 表示只能从正上方看到正下方
@export var vertical_limit := 90.0


# ==============================================================================
# 内部状态变量（下划线开头表示"私有"，外部不应该直接访问）
# ==============================================================================

## 左右旋转的累计角度（弧度制，2π ≈ 一圈）
var _yaw := 0.0

## 上下旋转的累计角度（弧度制）
var _pitch := 0.0


# ==============================================================================
# 节点引用
# ==============================================================================

# @onready 的意思是"等场景加载完再获取这个节点"。
# %Camera3D 里的 % 符号代表"唯一名称"——
# 在场景编辑器中右键节点 → "设为唯一名称"后就可以这样引用。
# 这样做比写路径（如 $"Camera3D"）更安全，不会因为改了节点名字就出错。
@onready var _camera: Camera3D = %Camera3D


# ==============================================================================
# _ready() — 生命周期函数，节点进入场景树时自动调用一次
# ==============================================================================
# Godot 会在场景加载完、第一帧开始前，自动调用所有节点的 _ready()。
# 适合做"初始化"工作，比如隐藏鼠标、设置初始状态等。
func _ready() -> void:
	# 0.5：加入 "player" group，供其他节点通过 get_first_node_in_group 查找
	add_to_group("player")

	# 锁定鼠标
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# 0.5：先检查是否已有 Damageable，避免重复创建
	var existing := get_node_or_null("Damageable")
	if existing != null and existing is Damageable:
		existing.max_health = 100.0
		existing.damaged.connect(_on_player_damaged)
	else:
		var dmg := Damageable.new()
		dmg.name = "Damageable"
		dmg.max_health = 100.0
		add_child(dmg)

		# 受伤时触发屏幕闪红
		dmg.damaged.connect(_on_player_damaged)


# ==============================================================================
# _input(event) — 每次有输入事件（按键、鼠标移动）时自动调用
# ==============================================================================
# Godot 把所有的输入——键盘、鼠标、手柄——统一打包成 InputEvent 对象。
# 这个函数每帧可能会被调用很多次（比如鼠标快速移动时）。
func _input(event: InputEvent) -> void:
	# 暂停时跳过所有游戏输入（由菜单处理）
	if get_tree().paused:
		return

	# --- 鼠标视角旋转 ---
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# event.relative 记录的是"鼠标这一小步移动了多远"（像素）
		# 乘以 sensitivity 把像素转换成旋转角度
		_yaw -= event.relative.x * mouse_sensitivity

		# 计算上下旋转的变化量
		var pitch_delta: float = event.relative.y * mouse_sensitivity

		# 如果开了 Y 轴反转，就反过来
		if invert_y:
			pitch_delta = -pitch_delta

		# clampf(value, min, max) 把值限制在 min~max 之间，保证不会翻过头
		# deg_to_rad() 把角度转成弧度（Godot 的旋转计算都用弧度）
		_pitch = clampf(_pitch - pitch_delta,
			-deg_to_rad(vertical_limit), deg_to_rad(vertical_limit))

		# --- 应用旋转 ---
		# transform.basis 是节点的 3x3 旋转矩阵。这里只绕 Y 轴旋转（左右转头）。
		# Basis.from_euler() 用欧拉角（XYZ 三轴旋转）创建旋转矩阵。
		transform.basis = Basis.from_euler(Vector3(0.0, _yaw, 0.0))

		# 摄像机的旋转只绕 X 轴（上下看）。
		# 注意：为什么不直接旋转 Player 的 X 轴？
		# 因为如果旋转 Player，会影响移动方向（可能走到地下）。
		# 所以上下看只转摄像机，左右看转整个身体。
		_camera.transform.basis = Basis.from_euler(Vector3(_pitch, 0.0, 0.0))

	# --- Esc 键：通知 main.gd 切换暂停菜单 ---
	if event.is_action_pressed("ui_cancel"):
		var main := get_tree().root.get_node_or_null("Main")
		if main != null and main.has_method("toggle_pause"):
			main.toggle_pause()


# ==============================================================================
# _physics_process(delta) — 每物理帧自动调用一次（默认每秒 60 次）
# ==============================================================================
# 所有物理相关的逻辑（移动、跳跃、碰撞）都应该写在这里。
# 这和 _process() 不同——_process 每渲染帧跑一次，帧率不固定；
# _physics_process 频率固定，适合需要稳定计算的物理逻辑。
# delta = 这一帧距离上一帧的秒数（通常约 0.016 秒）。
func _physics_process(delta: float) -> void:
	# === 重力处理 ===
	# is_on_floor() 检查角色是否站在地面/物体表面上。
	# 如果没站在地上 → 加速下落。
	# 注意：当角色在空中时，每帧 velocity.y 都会减去 gravity * delta，
	#       所以下落越来越快（这就是"重力加速度"的含义）。
	if not is_on_floor():
		velocity.y -= gravity * delta

	# === 跳跃处理 ===
	# is_action_just_pressed() 只在按键"刚按下那一瞬间"返回 true。
	# 和 is_action_pressed() 的区别非常重要：
	#   - is_action_pressed("jump")：按住空格时每帧都返回 true
	#   - is_action_just_pressed("jump")：只在按下的第一帧返回 true
	#
	# 如果用 is_action_pressed，按住空格会导致每帧都触发跳跃，
	# 角色会像火箭一样窜上天。所以跳跃一定要用 just_pressed。
	#
	# 同时检查 is_on_floor()，确保只有站在地上才能跳。
	# 这意味着不能在空中"二段跳"——这是 DOOM 经典设定。
	# 未来如果想加二段跳，改成检查"剩余跳跃次数 > 0"即可。
	if Input.is_action_just_pressed("jump") and is_on_floor():
		# 把垂直速度直接设为一个正数（向上），覆盖掉重力累加的负值。
		# 之后每帧重力会逐渐把这个值减小：
		#   +12 → +10 → +7 → +3 → 0 → -3 → -8 → ...
		# 对应运动轨迹：上升→顶点→下落，形成一条抛物线。
		velocity.y = jump_velocity

	# === 水平移动 ===
	# Input.get_vector() 一次性获取四个方向键的"组合值"。
	# 参数顺序是：左, 右, 前, 后
	# 返回值是 Vector2，例如同时按 W 和 D 会得到 (1, 1)，只按 A 得到 (-1, 0)。
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# 把 2D 输入方向转换成 3D 方向。
	# transform.basis 是玩家的朝向矩阵。
	# Vector3(input_dir.x, 0, input_dir.y)：X=左右，Y=0（上下不能走），Z=前后。
	# 乘以 basis 后，方向就变成"相对于玩家朝向"了。
	# .normalized() 确保方向向量的长度始终为 1（防止斜着走更快）。
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# 如果有按键输入
	if direction.length_squared() > 0.0:
		# move_toward(from, to, delta) 让值从 from 向 to 平滑过渡，最大步长为 delta。
		# 这里分别处理 X 和 Z 的速度，让角色加速到目标速度。
		velocity.x = move_toward(velocity.x, direction.x * move_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * move_speed, acceleration * delta)
	# 如果没按任何键
	else:
		# 用摩擦力逐渐把速度降到 0（模拟"滑步停止"，而不是瞬停）
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	# move_and_slide() 是 CharacterBody3D 的核心方法。
	# 它会：
	#   1. 用 velocity 移动角色
	#   2. 检测碰撞并自动滑过墙面/地面
	#   3. 更新 is_on_floor() 状态（跳跃后 is_on_floor() 会变成 false）
	# 必须每物理帧调用一次。
	move_and_slide()


# ==============================================================================
# _on_player_damaged() — 玩家受伤时触发屏幕闪红
# ==============================================================================
func _on_player_damaged(amount: float, _type: WeaponData.DamageType) -> void:
	# 通知 main.gd 做屏幕闪红效果
	var main := get_tree().root.get_node_or_null("Main")
	if main != null and main.has_method("player_hit"):
		main.player_hit(amount)

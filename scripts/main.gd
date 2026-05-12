# ==============================================================================
# Main — 游戏主控制器
# ==============================================================================
# 挂在场景的根节点（Main）上，负责：
#   1. 在游戏启动时初始化所有东西
#   2. 用代码搭建测试房间（地板、墙壁、天花板、灯光）
#   3. 设置 UI 准星的位置
# ==============================================================================

# 这个脚本本身不创建复杂的 3D 节点，所以直接继承最基础的 Node3D
extends Node3D


# ==============================================================================
# 节点引用
# ==============================================================================
# 通过 % 引用场景中标记了"唯一名称"的节点。
# 这样在代码里移动/修改这些节点的位置不会影响引用。

## 关卡容器——所有关卡几何体（墙壁、地板等）都放在这个节点下
@onready var _level_root: Node3D = %Level

## 准星——屏幕中央的绿色小方块，一个 ColorRect 节点
@onready var _crosshair: ColorRect = %Crosshair


# ==============================================================================
# _ready() — 游戏启动时自动执行一次
# ==============================================================================
func _ready() -> void:
	# 锁定鼠标——和 player_controller.gd 里做的一样，
	# 这里也调一次是为了确保万无一失
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# 搭建测试用的房间
	_build_test_room()

	# 初始化准星位置和样式
	_setup_crosshair()


# ==============================================================================
# _build_test_room() — 用 CSG（构造实体几何）快速搭建一个房间
# ==============================================================================
# CSG 是一种用简单形状（方盒子、圆柱、球）搭关卡的方式。
# 优点：不需要 3D 建模软件，直接在代码里写就能出关卡。
# 缺点：很复杂的场景性能不如专业建模。
# 适合做原型和测试。
func _build_test_room() -> void:
	# const = 常量，值定义后不能改。
	# 单位都是米。Godot 3D 中 1 单位 = 1 米。
	const ROOM_W := 12.0   # 房间宽度（X 轴）
	const ROOM_D := 12.0   # 房间深度（Z 轴）
	const ROOM_H := 4.0    # 房间高度（Y 轴，从地板到天花板）
	const WALL_T := 0.3    # 墙壁厚度

	# 准备三种颜色的材质。StandardMaterial3D 是 Godot 的默认 3D 材质。
	# Color(R, G, B) 的每个值范围是 0~1：
	#   - 地板：深灰棕色
	#   - 墙壁：浅灰棕色
	#   - 天花板：中灰色
	var floor_mat := _make_color_material(Color(0.3, 0.28, 0.25))
	var wall_mat := _make_color_material(Color(0.45, 0.42, 0.38))
	var ceiling_mat := _make_color_material(Color(0.35, 0.33, 0.3))

	# 创建地板和天花板
	_floor(ROOM_W, ROOM_D, WALL_T, floor_mat)
	_ceiling(ROOM_W, ROOM_D, ROOM_H, WALL_T, ceiling_mat)

	# 创建四面墙壁。
	# 每面墙是一个长方体，放在房间边缘。
	# Vector3(X, Y, Z) —— X=左右，Y=上下，Z=前后
	#   第一面：北墙（Z 轴负方向，即"前方"）
	_wall(Vector3(0, ROOM_H / 2.0, -ROOM_D / 2.0), Vector3(ROOM_W, ROOM_H, WALL_T), wall_mat)
	#   第二面：南墙（Z 轴正方向，即"后方"）
	_wall(Vector3(0, ROOM_H / 2.0, ROOM_D / 2.0), Vector3(ROOM_W, ROOM_H, WALL_T), wall_mat)
	#   第三面：西墙（X 轴负方向，即"左边"）
	_wall(Vector3(-ROOM_W / 2.0, ROOM_H / 2.0, 0), Vector3(WALL_T, ROOM_H, ROOM_D), wall_mat)
	#   第四面：东墙（X 轴正方向，即"右边"）
	_wall(Vector3(ROOM_W / 2.0, ROOM_H / 2.0, 0), Vector3(WALL_T, ROOM_H, ROOM_D), wall_mat)

	# 在房间正中央放一根柱子，用来测试绕障碍物走的感觉
	var pillar_mat := _make_color_material(Color(0.5, 0.35, 0.3))
	_csg_box(Vector3(0, ROOM_H / 2.0, 0), Vector3(1.2, ROOM_H, 1.2), pillar_mat)

	# 放置两个射击靶子，用来测试武器系统
	_spawn_target(Vector3(-2, ROOM_H / 2.0, 2), Vector3(1.0, 1.5, 1.0))
	_spawn_target(Vector3(3, ROOM_H / 2.0, -2), Vector3(0.8, 2.0, 0.8))

	# === 灯光 ===
	# Godot 中有多种灯光类型：
	#   DirectionalLight3D = 平行光（太阳光，从远处平行照过来）
	#   OmniLight3D = 点光源（灯泡，向四面八方发光）

	# 主光源——模拟日光从斜上方照进来
	var light := DirectionalLight3D.new()    # .new() 在代码中创建一个新节点
	light.position = Vector3(4, ROOM_H + 2, 2)
	light.rotation_degrees = Vector3(-45, -30, 0)   # 用角度设置旋转（-45° 俯角）
	light.light_energy = 0.8               # 亮度，1.0 = 默认亮度
	_level_root.add_child(light)            # 必须添加到场景树中才能生效

	# 补光——在房间高处放一个暗的点光源，防止阴影太黑
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, ROOM_H - 0.5, 0)
	fill.light_energy = 0.3
	_level_root.add_child(fill)


# ==============================================================================
# 辅助函数——创建地板、天花板、墙壁的快捷方式
# ==============================================================================

## 创建地板——放在 y=0 下方（地板厚度的一半在水平面以下）
func _floor(w: float, d: float, t: float, mat: Material) -> CSGBox3D:
	var box := _csg_box(Vector3(0, -t / 2.0, 0), Vector3(w, t, d), mat)
	box.name = "Floor"   # 给节点命名，方便在场景树中调试
	return box

## 创建天花板——放在房间高度上方
func _ceiling(w: float, d: float, h: float, t: float, mat: Material) -> CSGBox3D:
	var box := _csg_box(Vector3(0, h + t / 2.0, 0), Vector3(w, t, d), mat)
	box.name = "Ceiling"
	return box

## 创建墙壁——给定位置、大小和材质
func _wall(pos: Vector3, size: Vector3, mat: Material) -> CSGBox3D:
	return _csg_box(pos, size, mat)


# ==============================================================================
# _csg_box() — 创建一个 CSG 盒子（长方体）的核心函数
# ==============================================================================
# CSGBox3D 是 Godot 的"乐高积木"，用它快速拼出关卡原型。
# 每个盒子可以设置位置、大小、材质，以及是否参与碰撞。
func _csg_box(pos: Vector3, size: Vector3, mat: Material) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.position = pos            # 盒子中心的位置
	box.size = size               # 盒子的三轴尺寸
	box.material_override = mat   # 覆盖默认材质（白色），改用我们创建的有色材质
	box.use_collision = true      # 开启碰撞——这样玩家就不会穿过墙壁了
	_level_root.add_child(box)    # 把盒子挂到关卡节点下
	return box


# ==============================================================================
# _make_color_material() — 快速创建一个纯色材质
# ==============================================================================
# StandardMaterial3D 是 Godot 的 PBR（物理渲染）材质。
# albedo_color = 基础颜色（不发光、不透明）
# roughness = 粗糙度（0=光滑如镜，1=粗糙如砂纸）
func _make_color_material(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c     # 设置基础颜色
	mat.roughness = 0.9       # 高粗糙度 = 表面不反光，适合墙壁/地板
	return mat


# ==============================================================================
# _setup_crosshair() — 初始化屏幕中央的准星
# ==============================================================================
# ColorRect 是 Godot 的纯色矩形 UI 控件。
# 把它放在屏幕正中央，做成复古 FPS 的十字准星效果。
func _setup_crosshair() -> void:
	# 设置准星颜色——绿色（R=0, G=1, B=0）半透明（A=0.7）
	_crosshair.color = Color(0.0, 1.0, 0.0, 0.7)

	# 准星大小：4×4 像素的小方块（后续可以换成十字贴图）
	_crosshair.size = Vector2(4, 4)

	# 把准星放在屏幕正中央
	# get_viewport().size 返回当前窗口的像素尺寸（如 1280×720）
	# 先 / 2 得到中心点，再减去准星尺寸的一半，使准星精确居中
	_crosshair.position = Vector2(get_viewport().size) / 2.0 - _crosshair.size / 2.0

	# 连接信号——当窗口大小改变时，自动重新计算准星位置
	# "connect" 的意思是：当 size_changed 信号发出时，调用 _on_window_resized 函数
	get_tree().root.size_changed.connect(_on_window_resized)


# ==============================================================================
# _on_window_resized() — 窗口大小改变时的回调
# ==============================================================================
# 如果用户拖拽窗口边缘改变大小，这个函数会让准星自动重新居中。
func _on_window_resized() -> void:
	_crosshair.position = Vector2(get_viewport().size) / 2.0 - _crosshair.size / 2.0


# ==============================================================================
# _spawn_target() — 放置一个射击靶子
# ==============================================================================
# ShootingTarget 是一个带 Damageable 的 CSGBox3D 方块。
# 被击中时会闪白，生命归零时变灰并关闭碰撞。
func _spawn_target(pos: Vector3, size: Vector3) -> ShootingTarget:
	var target := ShootingTarget.new()
	target.position = pos
	target.size = size
	# ShootingTarget._ready() 会自动创建 Damageable 子节点
	_level_root.add_child(target)
	return target

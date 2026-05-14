# ==============================================================================
# ArenaLevel — 圆形竞技场关卡基类（Phase 2.2-2.4）
# ==============================================================================
# 所有竞技场关卡（荒漠、熔岩地狱）的共同父类，提供：
#   1. 圆形区域的半径参数（可玩区域 + 刷怪外环）
#   2. 场景树容器节点（几何/边界/道具/危险区/刷怪点）
#   3. 随机数生成器初始化
#   4. 基础地面生成（大平面 CSGBox3D）
#   5. 边界标志柱生成（沿圆周均匀排列的细高柱子）
#   6. 玩家越界检测（Phase 2.5）
#
# 子类（DesertArena、LavaArena）覆写：
#   - _get_ground_color()       → 地面颜色
#   - _get_boundary_color()     → 边界柱颜色
#   - _spawn_props()            → 生成本关特有的道具/危险区
#
# 场景树结构（_ready 后自动构建）：
#   DesertArena / LavaArena (ArenaLevel)
#   ├── GeometryRoot    (_geometry_root)
#   │    └── Ground_ArenaFloor (CSGBox3D, level_geometry)
#   ├── BoundaryRoot    (_boundary_root)
#   │    ├── BoundaryMarker_000 (CSGBox3D, level_geometry)
#   │    ├── BoundaryMarker_001 ...
#   │    └── ... (boundary_marker_count 根)
#   ├── PropsRoot       (_props_root)      —— 枯树、岩柱
#   ├── HazardsRoot     (_hazards_root)    —— 熔岩河流
#   └── SpawnRoot       (_spawn_root)      —— 刷怪标记
# ==============================================================================

class_name ArenaLevel extends Node3D


# ==============================================================================
# 信号
# ==============================================================================

## 玩家触碰圆形边界时发射 → main.gd 转发到 HUD 显示"已到达边界"
signal boundary_warning_requested()

## 竞技场构建完成时发射 → main.gd 收到后放置玩家、开始刷怪
## @param arena —— 自身引用，方便 main.gd 调用 set_player() 等方法
signal level_ready(arena: ArenaLevel)


# ==============================================================================
# 导出属性——在编辑器中可调，不同关卡可设置不同值
# ==============================================================================

## 圆形竞技场可玩区域半径（米）。玩家不能超出此范围。
## 45 米 ≈ 直径 90 米的圆形战斗区域，足够大但有边界感。
@export var arena_radius: float = 45.0

## 刷怪外环半径（米）。敌人从 arena_radius 到 spawn_outer_radius
## 之间的环形区域刷新，确保敌人不会刷在玩家脸上。
@export var spawn_outer_radius: float = 55.0

## 边界标志柱的数量。沿圆周等距排列，数值越大边界越密越明显。
## 64 根 ≈ 每根间距约 4.4 米，视觉上形成清晰的圆形围栏。
@export var boundary_marker_count: int = 64

## 随机种子。use_random_seed=true 时用于初始化 RandomNumberGenerator。
## 设为 0 则使用系统时间作为种子（每局都不同）。
@export var random_seed: int = 0

## 是否使用固定随机种子。true=每局道具位置可复现（用于调试），
## false=每次开局随机位置不同（正式游戏体验）。
@export var use_random_seed: bool = true


# ==============================================================================
# 容器节点——把不同类型的子节点分门别类放好，方便清理和管理
# ==============================================================================
# 命名约定：带下划线前缀 = 私有，外部通过方法访问而非直接操作。
# 每个容器在 _ready() 中自动创建，即使子类没用到也不会报错（空容器无害）。

## 几何体容器——地面、墙壁等基础地形
var _geometry_root: Node3D

## 边界容器——圆周上的边界标志柱
var _boundary_root: Node3D

## 道具容器——枯树、岩柱等掩体（Phase 3/4）
var _props_root: Node3D

## 危险区容器——熔岩河流等持续伤害区域（Phase 4）
var _hazards_root: Node3D

## 刷怪点容器——敌人生成标记位置（Phase 7）
var _spawn_root: Node3D


# ==============================================================================
# 随机数生成器——由 ArenaRandomizer（Phase 2.6）使用
# ==============================================================================
var rng: RandomNumberGenerator


# ==============================================================================
# _ready() — 竞技场初始化主流程
# ==============================================================================
# 初始化顺序很重要：
#   1. 创建容器节点（先把"抽屉"做出来）
#   2. 初始化随机数生成器（后续生成道具需要随机位置）
#   3. 构建基础地面（大平面，保证玩家不会掉出世界）
#   4. 构建边界标志（圆周上的柱子，视觉上划定边界）
#   5. 发出 level_ready 信号（通知 main.gd："我准备好了"）
#
# 注意：道具和危险区的生成不在这里，由子类的 _ready() 在调用
# super._ready() 之后自行处理。因为每个关卡的 prop/hazard 类型不同。
func _ready() -> void:
	# 第一步：创建容器节点（如果子类已创建则跳过）
	_create_container_nodes()

	# 第二步：初始化随机数生成器
	_setup_rng()

	# 第三步：构建基础竞技场（地面 + 边界柱）
	_build_base_arena()
	_build_boundary_markers()

	# 第四步：通知 main.gd 竞技场已就绪
	level_ready.emit(self)


# ==============================================================================
# _create_container_nodes() — 创建或获取五个容器节点
# ==============================================================================
func _create_container_nodes() -> void:
	_geometry_root = _get_or_create_child("GeometryRoot")
	_boundary_root = _get_or_create_child("BoundaryRoot")
	_props_root = _get_or_create_child("PropsRoot")
	_hazards_root = _get_or_create_child("HazardsRoot")
	_spawn_root = _get_or_create_child("SpawnRoot")


## 获取或创建指定名称的子节点
func _get_or_create_child(node_name: String) -> Node3D:
	var existing := get_node_or_null(node_name)
	if existing != null and existing is Node3D:
		return existing
	var node := Node3D.new()
	node.name = node_name
	add_child(node)
	return node


# ==============================================================================
# _setup_rng() — 初始化随机数生成器
# ==============================================================================
func _setup_rng() -> void:
	rng = RandomNumberGenerator.new()
	if use_random_seed and random_seed != 0:
		rng.seed = random_seed
	else:
		rng.randomize()


# ==============================================================================
# _build_base_arena() — 构建基础地面（Phase 2.3）
# ==============================================================================
# 用一个巨大的方形 CSGBox3D 覆盖整个圆形竞技场区域。
# 虽然是方形而非圆形，但边界柱在视觉上定义了圆形边界，
# 方形地面在边界柱之外的区域玩家走不到（被边界限制挡住），
# 所以实际上不影响体验。
#
# 地面参数：
#   宽度/深度 = arena_radius × 2 + 4（每边多出 2m 防止边缘露馅）
#   高度 = 0.3m（足够薄，看起来像地面而不是高台）
#   Y 位置 = -0.15（让顶面刚好在 Y=0）
#
# 为什么用 CSGBox3D 而不是 PlaneMesh：
#   CSGBox3D 自带碰撞体积，不需要额外加 CollisionShape3D。
#   PlaneMesh 需要再挂 StaticBody3D + CollisionShape3D，多一步操作。
#   后续替换为正式美术资源时再统一换。
func _build_base_arena() -> void:
	var ground_size := arena_radius * 2.0 + 4.0  # 每边多 2m 余量
	var ground_height := 0.3

	var ground := CSGBox3D.new()
	ground.name = "Ground_ArenaFloor"
	ground.size = Vector3(ground_size, ground_height, ground_size)
	ground.position = Vector3(0.0, -ground_height / 2.0, 0.0)
	ground.use_collision = true
	ground.add_to_group("level_geometry")

	# 设置地面材质颜色
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _get_ground_color()
	# 粗糙度高 → 漫反射 → 看起来像土地/岩石表面，不像金属
	mat.roughness = 0.9
	ground.material = mat

	_geometry_root.add_child(ground)


# ==============================================================================
# _build_boundary_markers() — 构建边界标志柱（Phase 2.4）
# ==============================================================================
# 沿圆周均匀放置细高柱子，让玩家一眼就能看到"这里是边界"。
#
# 柱子参数：
#   宽/深 = 0.3m（细——像围栏柱，不像墙壁）
#   高 = 4.0m（高于玩家视线，从竞技场中心也能看到）
#   位置 = 圆周上均匀分布，柱子底面 Y=0（站在地面上）
#
# 为什么用这么高的柱子：
#   玩家从竞技场中心（半径 45m）看向边界时，0.3m 宽的柱子
#   在远处非常细。如果不做高一点（4m），容易被敌人/道具遮挡，
#   导致玩家不知道边界在哪。4m 高 + 高亮色 = 远距离也能识别。
#
# 数学原理：
#   第 i 根柱子的角度 = i × (2π ÷ boundary_marker_count)
#   X = cos(角度) × arena_radius
#   Z = sin(角度) × arena_radius
#   这样所有柱子落在一个半径为 arena_radius 的正圆上。
func _build_boundary_markers() -> void:
	var pillar_width := 0.3
	var pillar_height := 4.0
	var angle_step := TAU / float(boundary_marker_count)  # TAU = 2π

	var mat := StandardMaterial3D.new()
	mat.albedo_color = _get_boundary_color()
	mat.roughness = 0.7

	for i in range(boundary_marker_count):
		var angle := float(i) * angle_step
		var x := cos(angle) * arena_radius
		var z := sin(angle) * arena_radius

		var pillar := CSGBox3D.new()
		pillar.name = "BoundaryMarker_%03d" % i  # 例：BoundaryMarker_000
		pillar.size = Vector3(pillar_width, pillar_height, pillar_width)
		# Y = pillar_height/2，让柱子底面贴地、柱体向上延伸
		pillar.position = Vector3(x, pillar_height / 2.0, z)
		pillar.use_collision = true
		pillar.add_to_group("level_geometry")
		pillar.material = mat

		_boundary_root.add_child(pillar)


# ==============================================================================
# 查询方法——供 main.gd / 子类 / SpawnManager 使用
# ==============================================================================

## 返回竞技场中心的世界坐标。默认就是关卡根节点的位置，
## 如果关卡在编辑器中偏移放置，这里也会自动跟随。
func get_arena_center() -> Vector3:
	return global_position


## 返回竞技场可玩区域半径
func get_arena_radius() -> float:
	return arena_radius


## 返回刷怪外环半径
func get_spawn_outer_radius() -> float:
	return spawn_outer_radius


## 检查一个 XZ 平面坐标是否在竞技场内部（不计 Y 轴高度）
func is_inside_arena(pos: Vector3) -> bool:
	var center := get_arena_center()
	var dist_xz := Vector2(pos.x - center.x, pos.z - center.z).length()
	return dist_xz <= arena_radius


# ==============================================================================
# 钩子方法——子类覆写这些方法来定制关卡外观
# ==============================================================================
# 这些方法在基类中返回默认值，子类覆写后返回各自的主题色/材质。
# Phase 3/4 由 DesertArena / LavaArena 覆写。

## 地面材质/颜色（子类覆写）
func _get_ground_color() -> Color:
	return Color(0.4, 0.4, 0.4)  # 默认灰色

## 边界柱材质/颜色（子类覆写）
func _get_boundary_color() -> Color:
	return Color(1.0, 1.0, 0.0)  # 默认黄色

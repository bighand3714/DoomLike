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

const ArenaRandomizerClass = preload("res://scripts/level/arena_randomizer.gd")


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

## 随机位置生成器——封装圆形区域内取点/互斥检测/边界外取点逻辑
var _randomizer: ArenaRandomizer

## 已占用的生成位置列表——防止道具/危险区互相重叠
var _used_spawn_points: Array[Vector3] = []

## 玩家引用——由 main.gd 在关卡加载后通过 set_player() 注入
var _player: CharacterBody3D = null


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
	# 创建随机位置生成器（Phase 2.6）
	_randomizer = ArenaRandomizerClass.new()
	_randomizer.setup(rng)


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
# 随机放置接口（Phase 2.7）
# ==============================================================================

## 清空所有随机生成的内容——道具 + 危险区 + 占用点列表
func clear_randomized_content() -> void:
	for child in _props_root.get_children():
		child.queue_free()
	for child in _hazards_root.get_children():
		child.queue_free()
	_used_spawn_points.clear()

## 注册一个已占用的位置——后续生成的道具/危险区会避开此点
func register_occupied_point(pos: Vector3) -> void:
	_used_spawn_points.append(pos)

## 获取一个合法的随机道具位置
# 条件：在 arena_radius 内 + 距出生点 > center_safe_radius + 与已占点保持 min_distance
# 返回 { "ok": bool, "position": Vector3 }
func get_random_prop_position(min_distance: float, center_safe_radius: float) -> Dictionary:
	return _randomizer.try_get_non_overlapping_point(
		get_arena_center(),
		arena_radius,
		_used_spawn_points,
		min_distance,
		2.0,  # 距边界 2m 缩进，防止道具贴边
		center_safe_radius,  # 距中心的最小距离
		20
	)


# ==============================================================================
# get_player_spawn_transform() — 返回玩家出生点的 Transform3D（Phase 2.10）
# ==============================================================================
# 优先使用场景中手动放置的 PlayerStart 标记节点（如果存在）；
# 否则返回竞技场中心上方 1.6m（玩家视线高度）的默认出生点。
#
# 方便关卡设计者：在 .tscn 中放一个 Node3D 命名为 PlayerStart，
# 玩家就会从这里出生；不放置则默认圆心出生。
func get_player_spawn_transform() -> Transform3D:
	for child in get_children():
		if child.name == "PlayerStart" and child is Node3D:
			return child.global_transform
	# 默认：圆心上方 1.6m（玩家胶囊体中心高度）
	var center := get_arena_center()
	return Transform3D(Basis(), Vector3(center.x, 1.6, center.z))


# ==============================================================================
# set_player(player_node) — 注入玩家引用（由 main.gd 在关卡加载后调用）
# ==============================================================================
func set_player(player_node: CharacterBody3D) -> void:
	_player = player_node


# ==============================================================================
# _process(delta) — 每帧检查玩家是否越界（Phase 2.5）
# ==============================================================================
# 为什么用 _process 而不是 _physics_process：
#   player_controller 在 _physics_process 中调用 move_and_slide() 移动玩家。
#   如果用 _physics_process 来检查边界，执行顺序取决于场景树顺序（不可靠），
#   可能在玩家移动之前就检查了，导致"上一帧的位置被本帧的边界检测拦截"。
#
#   _process 在所有 _physics_process 之后执行，此时玩家位置已经更新完毕，
#   直接检查并修正即可。视觉上在渲染前完成校正，玩家不会看到"出界再弹回"。
#
# 夹回逻辑：
#   1. 计算玩家到竞技场中心的 XZ 距离
#   2. 如果超出 arena_radius：
#      a. 从中心指向玩家的方向归一化（dir_xz）
#      b. 把玩家位置夹回 arena_radius - 0.5（留半米缓冲，避免贴边抖动）
#      c. 消除向外的水平速度分量（保留切向速度，让玩家能沿边界"滑行"）
#      d. 发出 boundary_warning_requested 信号 → HUD 显示"已到达边界"
#
# 关于速度修正：
#   如果不清除向外的水平速度，玩家顶着边界时 velocity 保持正值，
#   下一帧 move_and_slide() 又会尝试往外移动，位置再次被夹回，
#   形成"顶墙抖动"。只移除向外的分量（dot product > 0 的部分），
#   保留切向分量，玩家就能沿边界平滑滑动。
func _process(_delta: float) -> void:
	if _player == null:
		return

	var center := get_arena_center()
	var to_player := _player.global_position - center
	var dist_xz := Vector2(to_player.x, to_player.z).length()

	if dist_xz > arena_radius:
		# 方向：从中心指向玩家（只取 XZ 平面）
		var dir_xz := Vector2(to_player.x, to_player.z).normalized()

		# 夹回位置：arena_radius - 0.5m 缓冲
		var clamped_xz := dir_xz * (arena_radius - 0.5)
		_player.global_position = Vector3(
			center.x + clamped_xz.x,
			_player.global_position.y,  # Y 轴不受影响
			center.z + clamped_xz.y
		)

		# 消除向外的水平速度分量（dot > 0 = 正在往外走）
		var vel := _player.velocity
		var vel_xz := Vector2(vel.x, vel.z)
		var outward_speed := vel_xz.dot(dir_xz)
		if outward_speed > 0.0:
			vel.x -= dir_xz.x * outward_speed
			vel.z -= dir_xz.y * outward_speed
			_player.velocity = vel

		boundary_warning_requested.emit()


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

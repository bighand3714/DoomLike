# ==============================================================================
# SpawnManager — 刷怪与难度曲线（Phase 7）
# ==============================================================================
# 挂在 Level 节点下，负责：
#   - 根据生存时间计算强度曲线 → 控制敌人类型和刷新频率
#   - 从竞技场边界外选取刷新点
#   - 刷新前显示预警指示器
#   - 关卡差异化刷怪权重（荒漠偏地面、熔岩偏飞行/远程）
# ==============================================================================

class_name SpawnManager extends Node

signal intensity_changed(new_intensity: int)

# 敌人场景路径映射
const ENEMY_SCENES := {
	"ground_enemy": "res://scenes/enemies/ground_enemy.tscn",
	"advanced_ground_enemy": "res://scenes/enemies/advanced_ground_enemy.tscn",
	"elite_ground_enemy": "res://scenes/enemies/elite_ground_enemy.tscn",
	"ranged_enemy": "res://scenes/enemies/ranged_enemy.tscn",
	"advanced_ranged_enemy": "res://scenes/enemies/advanced_ranged_enemy.tscn",
	"flying_enemy": "res://scenes/enemies/flying_enemy.tscn",
	"advanced_flying_enemy": "res://scenes/enemies/advanced_flying_enemy.tscn",
	"flying_ranged_enemy": "res://scenes/enemies/flying_ranged_enemy.tscn",
}

# ==============================================================================
# SpawnEntry —— 单个敌人生成条目的内部类
# ==============================================================================
class SpawnEntry:
	var enemy_id: String
	var scene_path: String
	var min_intensity: int      # 此敌人开始出现的最低强度
	var weight: float           # 在当前强度下的选择权重
	var spawn_cost: int         # 消耗的波次预算

	func _init(eid: String, spath: String, min_int: int, w: float, cost: int) -> void:
		enemy_id = eid
		scene_path = spath
		min_intensity = min_int
		weight = w
		spawn_cost = cost


# ==============================================================================
# 引用
# ==============================================================================
var arena: ArenaLevel = null
var enemy_manager: Node = null

# run_stats 引用（由 main.gd 注入，用于读取 survival_time）
var _run_stats_ref: RefCounted = null

# ==============================================================================
# 状态
# ==============================================================================
var is_active: bool = false
var active_enemy_limit: int = 60
var current_intensity: int = 1

var _spawn_timer_node: Timer = null
var _spawn_entries: Array = []
var _pending_warnings: Array = []       # 预警节点列表
var _spawn_profile: String = "default"

# 荒漠配置权重倍数
const DESERT_WEIGHTS := {
	"ground_enemy": 3.0,
	"advanced_ground_enemy": 2.0,
	"elite_ground_enemy": 1.5,
	"ranged_enemy": 1.5,
	"advanced_ranged_enemy": 1.0,
	"flying_enemy": 0.3,
	"advanced_flying_enemy": 0.2,
	"flying_ranged_enemy": 0.3,
}
# 熔岩配置权重倍数
const LAVA_WEIGHTS := {
	"ground_enemy": 1.5,
	"advanced_ground_enemy": 1.0,
	"elite_ground_enemy": 1.0,
	"ranged_enemy": 2.0,
	"advanced_ranged_enemy": 1.5,
	"flying_enemy": 2.0,
	"advanced_flying_enemy": 1.5,
	"flying_ranged_enemy": 2.0,
}


# ==============================================================================
# setup / start / stop / reset
# ==============================================================================
func setup(p_arena: ArenaLevel, p_enemy_manager: Node, p_run_stats: RefCounted, profile: String = "default") -> void:
	arena = p_arena
	enemy_manager = p_enemy_manager
	_run_stats_ref = p_run_stats
	_spawn_profile = profile
	_build_spawn_entries()


func start() -> void:
	is_active = true
	current_intensity = 1
	intensity_changed.emit(current_intensity)
	# 创建并启动刷怪 Timer
	if _spawn_timer_node == null:
		_spawn_timer_node = Timer.new()
		_spawn_timer_node.one_shot = false
		_spawn_timer_node.timeout.connect(_on_spawn_timer)
		add_child(_spawn_timer_node)
	_spawn_timer_node.start(1.0)


func stop() -> void:
	is_active = false
	if _spawn_timer_node != null:
		_spawn_timer_node.stop()
	_clear_all_warnings()


func reset() -> void:
	stop()
	current_intensity = 1
	_pending_warnings.clear()
	_spawn_entries.clear()


# ==============================================================================
# _build_spawn_entries —— 构建所有敌人生成条目
# ==============================================================================
func _build_spawn_entries() -> void:
	_spawn_entries.clear()

	# 从 enemy_data .tres 读取 spawn_cost 构建条目
	var entries_data := [
		{ "id": "ground_enemy",         "min_intensity": 1, "weight": 3.0 },
		{ "id": "advanced_ground_enemy","min_intensity": 4, "weight": 2.0 },
		{ "id": "elite_ground_enemy",   "min_intensity": 6, "weight": 1.5 },
		{ "id": "ranged_enemy",         "min_intensity": 2, "weight": 2.0 },
		{ "id": "advanced_ranged_enemy","min_intensity": 4, "weight": 1.5 },
		{ "id": "flying_enemy",         "min_intensity": 3, "weight": 1.5 },
		{ "id": "advanced_flying_enemy","min_intensity": 5, "weight": 1.0 },
		{ "id": "flying_ranged_enemy",  "min_intensity": 5, "weight": 1.5 },
	]

	for ed in entries_data:
		var eid: String = ed.id
		var scene_path: String = ENEMY_SCENES.get(eid, "")
		if scene_path.is_empty():
			continue

		# 尝试加载 .tres 获取 spawn_cost
		var cost: int = 1
		var tres_path := "res://assets/enemies/" + eid + ".tres"
		if ResourceLoader.exists(tres_path):
			var data = load(tres_path)
			if data != null:
				cost = int(data.get("spawn_cost") if "spawn_cost" in data else 1)

		var entry := SpawnEntry.new(eid, scene_path, ed.min_intensity, ed.weight, cost)
		_spawn_entries.append(entry)


# ==============================================================================
# _process(delta) —— 主刷怪循环
# ==============================================================================
func _on_spawn_timer() -> void:
	if not is_active:
		return
	if arena == null or enemy_manager == null:
		return
	if _run_stats_ref == null:
		return

	# 更新强度
	_update_intensity()

	# 检查存活上限
	var alive_count := 0
	if enemy_manager.has_method("get_active_count"):
		alive_count = enemy_manager.get_active_count()
	elif "active_enemies" in enemy_manager:
		alive_count = (enemy_manager.active_enemies as Array).size()

	if alive_count >= active_enemy_limit:
		_spawn_timer_node.start(_get_spawn_interval())
		return

	_spawn_wave()
	_spawn_timer_node.start(_get_spawn_interval())


# ==============================================================================
# _update_intensity —— 根据生存时间计算当前强度
# ==============================================================================
func _update_intensity() -> void:
	var t: float = _run_stats_ref.survival_time
	var new_intensity: int = 1

	if t >= 320.0:
		new_intensity = 6
	elif t >= 210.0:
		new_intensity = 5
	elif t >= 130.0:
		new_intensity = 4
	elif t >= 75.0:
		new_intensity = 3
	elif t >= 30.0:
		new_intensity = 2
	else:
		new_intensity = 1

	if new_intensity != current_intensity:
		current_intensity = new_intensity
		intensity_changed.emit(current_intensity)


# ==============================================================================
# _get_spawn_interval —— 获取当前刷新间隔（强度越高间隔越短）
# ==============================================================================
func _get_spawn_interval() -> float:
	match current_intensity:
		1: return 4.0
		2: return 3.0
		3: return 2.2
		4: return 1.7
		5: return 1.4
		6: return 1.2
		_: return 4.0


# ==============================================================================
# _get_wave_budget —— 获取当前波次预算（强度越高预算越多）
# ==============================================================================
func _get_wave_budget() -> int:
	match current_intensity:
		1: return 2
		2: return 3
		3: return 4
		4: return 5
		5: return 6
		6: return 8
		_: return 2


# ==============================================================================
# _spawn_wave —— 按波次预算选择敌人并创建预警
# ==============================================================================
func _spawn_wave() -> void:
	if arena == null:
		return

	var budget := _get_wave_budget()
	var center := arena.get_arena_center()
	var arena_r := arena.get_arena_radius()
	var outer_r := arena.get_spawn_outer_radius()

	# 筛选当前强度可用的条目
	var available: Array = []
	for entry in _spawn_entries:
		if entry.min_intensity <= current_intensity:
			available.append(entry)

	if available.is_empty():
		return

	# 按权重选择敌人，直到预算耗尽
	var spawned_count := 0
	var max_per_wave := 6
	var attempts := 0

	while budget > 0 and spawned_count < max_per_wave and attempts < 10:
		attempts += 1

		# 加权随机选择
		var entry: SpawnEntry = _weighted_select(available)
		if entry == null:
			continue

		if entry.spawn_cost > budget:
			continue

		# 选取边界外刷新点
		var spawn_pos := _get_spawn_point(center, arena_r, outer_r)
		if spawn_pos == Vector3.ZERO:
			continue

		# 读取 enemy_data 获取飞行高度
		var fly_height := 0.0
		var tres_path := "res://assets/enemies/" + entry.enemy_id + ".tres"
		if ResourceLoader.exists(tres_path):
			var data = load(tres_path)
			if data != null and data.get("is_flying") == true:
				fly_height = float(data.get("hover_height") if "hover_height" in data else 3.0)

		# 创建预警
		_create_spawn_warning(spawn_pos + Vector3(0, fly_height, 0), entry)

		budget -= entry.spawn_cost
		spawned_count += 1


# ==============================================================================
# _weighted_select —— 加权随机选择条目，应用关卡 profile 修正
# ==============================================================================
func _weighted_select(available: Array) -> SpawnEntry:
	if available.is_empty():
		return null

	var profile_weights: Dictionary
	match _spawn_profile:
		"desert": profile_weights = DESERT_WEIGHTS
		"lava":   profile_weights = LAVA_WEIGHTS
		_:        profile_weights = {}

	var total_weight: float = 0.0
	var weighted: Array = []
	for entry in available:
		var w: float = entry.weight
		if profile_weights.has(entry.enemy_id):
			w *= profile_weights[entry.enemy_id]
		weighted.append({ "entry": entry, "weight": w })
		total_weight += w

	if total_weight <= 0.0:
		return available[0] as SpawnEntry

	var roll := randf() * total_weight
	var accumulated: float = 0.0
	for item in weighted:
		accumulated += item.weight
		if roll <= accumulated:
			return item.entry as SpawnEntry

	return available[0] as SpawnEntry


# ==============================================================================
# _get_spawn_point —— 获取边界外的合法刷新点
# ==============================================================================
func _get_spawn_point(center: Vector3, arena_radius: float, outer_radius: float) -> Vector3:
	if arena == null:
		return Vector3.ZERO

	# 使用竞技场的随机数生成器
	var randomizer = arena.get("_randomizer")
	if randomizer == null:
		# fallback: 简单随机
		var inner := arena_radius + 3.0
		var outer := outer_radius - 2.0
		var r := randf_range(inner, outer)
		var angle := randf_range(0.0, TAU)
		return Vector3(center.x + cos(angle) * r, 0.0, center.z + sin(angle) * r)

	return randomizer.get_random_point_outside_boundary(center, arena_radius, outer_radius)


# ==============================================================================
# _create_spawn_warning —— 创建刷怪预警节点
# ==============================================================================
const WARNING_DURATION := 1.2        # 预警持续时间
const WARNING_HEIGHT := 1.5          # 预警柱高度
const WARNING_WIDTH := 0.6           # 预警柱宽/深

func _create_spawn_warning(pos: Vector3, entry: SpawnEntry) -> void:
	# 预警柱：半透明红色发光柱体
	var pillar := CSGBox3D.new()
	pillar.name = "SpawnWarning_Temp"
	pillar.size = Vector3(WARNING_WIDTH, WARNING_HEIGHT, WARNING_WIDTH)
	pillar.position = Vector3(pos.x, WARNING_HEIGHT / 2.0, pos.z)
	pillar.use_collision = false

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.1, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.05)
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pillar.material = mat

	if arena != null:
		var spawn_root = arena.get_node_or_null("SpawnRoot")
		if spawn_root != null:
			spawn_root.add_child(pillar)
		else:
			add_child(pillar)
	else:
		add_child(pillar)

	_pending_warnings.append({ "node": pillar, "entry": entry, "pos": pos })

	# 预警结束后生成敌人
	var timer := get_tree().create_timer(WARNING_DURATION)
	timer.timeout.connect(_on_warning_expired.bind(pillar, entry, pos))


# ==============================================================================
# _on_warning_expired —— 预警结束，实例化敌人
# ==============================================================================
func _on_warning_expired(pillar: CSGBox3D, entry: SpawnEntry, pos: Vector3) -> void:
	# 先移除预警引用
	for i in range(_pending_warnings.size() - 1, -1, -1):
		if _pending_warnings[i].node == pillar:
			_pending_warnings.remove_at(i)
			break

	if is_instance_valid(pillar):
		pillar.queue_free()

	if not is_active:
		return

	# 加载场景并实例化
	var packed := load(entry.scene_path) as PackedScene
	if packed == null:
		push_error("SpawnManager: 无法加载敌人场景 '%s'" % entry.scene_path)
		return

	var enemy: Node = packed.instantiate()
	if enemy == null:
		return

	# 加载 enemy_data 并在加入场景前设置
	var tres_path := "res://assets/enemies/" + entry.enemy_id + ".tres"
	if ResourceLoader.exists(tres_path):
		var data = load(tres_path)
		if data != null:
			enemy.set("enemy_data", data)

	# 先加入场景树，再设置全局位置
	var parent := get_parent()
	parent.add_child(enemy)
	if "global_position" in enemy:
		enemy.global_position = pos

	if enemy_manager != null and enemy_manager.has_method("register_enemy"):
		enemy_manager.register_enemy(enemy)


# ==============================================================================
# _clear_all_warnings —— 清除所有预警节点
# ==============================================================================
func _clear_all_warnings() -> void:
	for item in _pending_warnings:
		var node = item.node
		if is_instance_valid(node):
			node.queue_free()
	_pending_warnings.clear()

	# 也清理 SpawnRoot 下的残余预警
	if arena != null:
		var spawn_root = arena.get_node_or_null("SpawnRoot")
		if spawn_root != null:
			for child in spawn_root.get_children():
				if child.name == "SpawnWarning_Temp":
					child.queue_free()

# ==============================================================================
# SpawnManager — 刷怪与难度曲线（Phase 7）
# ==============================================================================
# 挂在 Level 节点下，负责：
#   - 根据生存时间计算强度曲线 → 控制敌人类型和刷新频率
#   - 从竞技场边界外选取刷新点
#   - 刷新前显示预警指示器
#   - 关卡差异化刷怪权重（荒漠偏地面、熔岩偏飞行/远程）
#   - 按强度等级限制存活敌人数
# ==============================================================================

class_name SpawnManager extends Node

signal intensity_changed(new_intensity: int)

const ENEMY_SCENES := {
	"ground_enemy": "res://scenes/enemies/ground_enemy.tscn",
	"advanced_ground_enemy": "res://scenes/enemies/advanced_ground_enemy.tscn",
	"elite_ground_enemy": "res://scenes/enemies/elite_ground_enemy.tscn",
	"ranged_enemy": "res://scenes/enemies/ranged_enemy.tscn",
	"advanced_ranged_enemy": "res://scenes/enemies/advanced_ranged_enemy.tscn",
	"flying_enemy": "res://scenes/enemies/flying_enemy.tscn",
	"advanced_flying_enemy": "res://scenes/enemies/advanced_flying_enemy.tscn",
	"flying_ranged_enemy": "res://scenes/enemies/flying_ranged_enemy.tscn",
	"orc_melee": "res://scenes/enemies/orc_enemy.tscn",
}


class SpawnEntry:
	var enemy_id: String
	var scene_path: String
	var min_intensity: int
	var weight: float
	var spawn_cost: int

	func _init(eid: String, spath: String, min_int: int, w: float, cost: int) -> void:
		enemy_id = eid
		scene_path = spath
		min_intensity = min_int
		weight = w
		spawn_cost = cost


# ==============================================================================
# 引用/状态
# ==============================================================================
var arena: ArenaLevel = null
var enemy_manager: Node = null
var _run_stats_ref: RefCounted = null

var is_active: bool = false
var current_intensity: int = 1

var _spawn_timer_node: Timer = null
var _spawn_entries: Array = []
var _pending_warnings: Array = []
var _spawn_profile: String = "default"

const DESERT_WEIGHTS := {
	"ground_enemy": 3.0, "advanced_ground_enemy": 2.0, "elite_ground_enemy": 1.5,
	"ranged_enemy": 1.5, "advanced_ranged_enemy": 1.0,
	"flying_enemy": 0.3, "advanced_flying_enemy": 0.2, "flying_ranged_enemy": 0.3,
	"orc_melee": 2.5,
}
const LAVA_WEIGHTS := {
	"ground_enemy": 1.5, "advanced_ground_enemy": 1.0, "elite_ground_enemy": 1.0,
	"ranged_enemy": 2.0, "advanced_ranged_enemy": 1.5,
	"flying_enemy": 2.0, "advanced_flying_enemy": 1.5, "flying_ranged_enemy": 2.0,
	"orc_melee": 1.5,
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
# 敌人池
# ==============================================================================
func _build_spawn_entries() -> void:
	_spawn_entries.clear()
	var entries_data := [
		{ "id": "ground_enemy",         "min_intensity": 1, "weight": 3.0 },
		{ "id": "advanced_ground_enemy","min_intensity": 4, "weight": 2.0 },
		{ "id": "elite_ground_enemy",   "min_intensity": 6, "weight": 1.5 },
		{ "id": "ranged_enemy",         "min_intensity": 2, "weight": 2.0 },
		{ "id": "advanced_ranged_enemy","min_intensity": 4, "weight": 1.5 },
		{ "id": "flying_enemy",         "min_intensity": 3, "weight": 1.5 },
		{ "id": "advanced_flying_enemy","min_intensity": 5, "weight": 1.0 },
		{ "id": "flying_ranged_enemy",  "min_intensity": 5, "weight": 1.5 },
		{ "id": "orc_melee",           "min_intensity": 2, "weight": 2.5 },
	]
	for ed in entries_data:
		var eid: String = ed.id
		var scene_path: String = ENEMY_SCENES.get(eid, "")
		if scene_path.is_empty():
			continue
		var cost: int = 1
		var tres_path := "res://assets/enemies/" + eid + ".tres"
		if ResourceLoader.exists(tres_path):
			var data = load(tres_path)
			if data != null:
				cost = int(data.get("spawn_cost") if "spawn_cost" in data else 1)
		_spawn_entries.append(SpawnEntry.new(eid, scene_path, ed.min_intensity, ed.weight, cost))


# ==============================================================================
# Timer 驱动刷怪
# ==============================================================================
func _on_spawn_timer() -> void:
	if not is_active:
		return
	if arena == null or enemy_manager == null or _run_stats_ref == null:
		return

	_update_intensity()

	var alive_count := 0
	if enemy_manager.has_method("get_active_count"):
		alive_count = enemy_manager.get_active_count()
	elif "active_enemies" in enemy_manager:
		alive_count = (enemy_manager.active_enemies as Array).size()

	var limit := _get_active_enemy_limit()
	if alive_count >= limit:
		_spawn_timer_node.start(_get_spawn_interval())
		return

	_spawn_wave()
	_spawn_timer_node.start(_get_spawn_interval())


# ==============================================================================
# 强度曲线 + 参数
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

	if new_intensity != current_intensity:
		current_intensity = new_intensity
		intensity_changed.emit(current_intensity)


func _get_spawn_interval() -> float:
	match current_intensity:
		1: return 4.0
		2: return 3.0
		3: return 2.2
		4: return 1.7
		5: return 1.4
		6: return 1.2
		_: return 4.0


func _get_active_enemy_limit() -> int:
	match current_intensity:
		1: return 8
		2: return 12
		3: return 16
		4: return 20
		5: return 25
		6: return 32
		_: return 8


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
# 波次生成
# ==============================================================================
func _spawn_wave() -> void:
	if arena == null:
		return

	var budget := _get_wave_budget()
	var center := arena.get_arena_center()
	var arena_r := arena.get_arena_radius()
	var outer_r := arena.get_spawn_outer_radius()

	var available: Array = []
	for entry in _spawn_entries:
		if entry.min_intensity <= current_intensity:
			available.append(entry)
	if available.is_empty():
		return

	var spawned_count := 0
	var max_per_wave := 4
	var attempts := 0

	while budget > 0 and spawned_count < max_per_wave and attempts < 10:
		attempts += 1
		var entry: SpawnEntry = _weighted_select(available)
		if entry == null:
			continue
		if entry.spawn_cost > budget:
			continue

		var spawn_pos := _get_spawn_point(center, arena_r, outer_r)
		if spawn_pos == Vector3.ZERO:
			continue

		var fly_height := 0.0
		var tres_path := "res://assets/enemies/" + entry.enemy_id + ".tres"
		if ResourceLoader.exists(tres_path):
			var data = load(tres_path)
			if data != null and data.get("is_flying") == true:
				fly_height = float(data.get("hover_height") if "hover_height" in data else 3.0)

		_create_spawn_warning(spawn_pos + Vector3(0, fly_height, 0), entry)
		budget -= entry.spawn_cost
		spawned_count += 1


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


func _get_spawn_point(center: Vector3, arena_radius: float, outer_radius: float) -> Vector3:
	if arena == null:
		return Vector3.ZERO
	var randomizer = arena.get_randomizer()
	if randomizer == null:
		var inner := arena_radius + 3.0
		var outer := outer_radius - 2.0
		var r := randf_range(inner, outer)
		var angle := randf_range(0.0, TAU)
		return Vector3(center.x + cos(angle) * r, 0.0, center.z + sin(angle) * r)
	return randomizer.get_random_point_outside_boundary(center, arena_radius, outer_radius)


# ==============================================================================
# 预警 + 生成
# ==============================================================================
const WARNING_DURATION := 1.2
const WARNING_HEIGHT := 1.5
const WARNING_WIDTH := 0.6

func _create_spawn_warning(pos: Vector3, entry: SpawnEntry) -> void:
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
	var timer := get_tree().create_timer(WARNING_DURATION)
	timer.timeout.connect(_on_warning_expired.bind(pillar, entry, pos))


func _on_warning_expired(_timer, pillar, entry: SpawnEntry, pos: Vector3) -> void:
	for i in range(_pending_warnings.size() - 1, -1, -1):
		if _pending_warnings[i].node == pillar:
			_pending_warnings.remove_at(i)
			break
	if is_instance_valid(pillar):
		pillar.queue_free()
	if not is_active:
		return

	var packed := load(entry.scene_path) as PackedScene
	if packed == null:
		return
	var enemy: Node = packed.instantiate()
	if enemy == null:
		return

	var tres_path := "res://assets/enemies/" + entry.enemy_id + ".tres"
	if ResourceLoader.exists(tres_path):
		var data = load(tres_path)
		if data != null:
			enemy.set("enemy_data", data)

	var parent := get_parent()
	parent.add_child(enemy)
	if "global_position" in enemy:
		enemy.global_position = pos

	if enemy_manager != null and enemy_manager.has_method("register_enemy"):
		enemy_manager.register_enemy(enemy)

	if enemy.has_method("begin_spawning"):
		enemy.begin_spawning()


func _clear_all_warnings() -> void:
	for item in _pending_warnings:
		var node = item.node
		if is_instance_valid(node):
			node.queue_free()
	_pending_warnings.clear()
	if arena != null:
		var spawn_root = arena.get_node_or_null("SpawnRoot")
		if spawn_root != null:
			for child in spawn_root.get_children():
				if child.name == "SpawnWarning_Temp":
					child.queue_free()

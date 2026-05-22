# ==============================================================================
# DesertArena — 荒漠竞技场（Phase 3）
# ==============================================================================
# 继承 ArenaLevel，覆写地面/边界颜色为荒漠主题（沙黄+浅黄白），
# 并在 _ready() 中随机生成枯树作为掩体道具。
#
# 枯树随机生成规则：
#   - 数量由 dead_tree_count 控制（默认 24 棵）
#   - 每棵枯树之间保持 dead_tree_min_distance（默认 5m）
#   - 出生点周围 dead_tree_safe_radius 内不生成（默认 8m）
#   - Y 轴旋转随机 + 缩放随机（0.8~1.3），避免所有树看起来一样
#   - 距边界 2m 内不生成（避免堵住边界通道）
# ==============================================================================

class_name DesertArena extends ArenaLevel


# ==============================================================================
# 荒漠专属参数
# ==============================================================================

## 枯树数量
@export var dead_tree_count: int = 24

## 枯树之间最小间距（米）
@export var dead_tree_min_distance: float = 5.0

## 出生点周围安全半径（米）——此范围内不生成枯树
@export var dead_tree_safe_radius: float = 8.0


# ==============================================================================
# _ready() —— 先调基类构建竞技场，再生成荒漠特有的枯树
# ==============================================================================
func _ready() -> void:
	# 先让基类生成地面 + 边界柱 + 容器节点 + 随机数生成器
	super._ready()

	# 荒漠特有：静态全局光照
	_setup_directional_light()

	# 荒漠特有：随机生成枯树掩体
	_spawn_dead_trees()


# ==============================================================================
# 蒿子方法 —— 荒漠主题色
# ==============================================================================

func _get_ground_color() -> Color:
	return Color(0.76, 0.66, 0.4)  # 沙黄色

func _get_boundary_color() -> Color:
	return Color(1.0, 0.95, 0.7)  # 浅黄白色，远距离明显

func _get_fog_color() -> Color:
	return Color(0.76, 0.66, 0.4)


# ==============================================================================
# _setup_directional_light() —— 静态全局光照（沙漠日光）
# ==============================================================================
func _setup_directional_light() -> void:
	var light := DirectionalLight3D.new()
	light.name = "DesertSun"
	light.light_energy = 1.0
	light.light_color = Color(1.0, 0.92, 0.75)
	light.shadow_enabled = true
	light.rotation_degrees = Vector3(-45.0, 135.0, 0.0)
	add_child(light)

# ==============================================================================
# _spawn_dead_trees() —— 随机生成枯树道具（Phase 3.6）
# ==============================================================================
func _spawn_dead_trees() -> void:
	# 预加载枯树场景
	var DeadTreeScene := preload("res://scenes/props/dead_tree_prop.tscn")

	var spawned := 0
	var _max_attempts_per_tree := 20

	for _i in range(dead_tree_count):
		# 尝试找到不重叠的位置
		var result := get_random_prop_position(dead_tree_min_distance, dead_tree_safe_radius)

		if not result.ok:
			# 找不到合适位置（竞技场太挤了），跳过剩余枯树
			print("DesertArena: 只生成了 %d/%d 棵枯树（位置不足）" % [spawned, dead_tree_count])
			break

		var pos: Vector3 = result.position
		# Y 轴放在地面上
		pos.y = 0.0

		var tree := DeadTreeScene.instantiate()
		# 必须先加进场景树，global_position 才能正确计算
		_props_root.add_child(tree)
		tree.global_position = pos

		# 随机 Y 轴旋转（0~360°），避免所有树朝向相同
		tree.rotation_degrees.y = rng.randf_range(0.0, 360.0)

		# 随机缩放（0.8~1.3），让树的大小有差异
		var scale_factor := rng.randf_range(0.8, 1.3)
		tree.scale = Vector3(scale_factor, scale_factor, scale_factor)

		register_occupied_point(pos)
		spawned += 1

	print("DesertArena: 生成了 %d 棵枯树" % spawned)

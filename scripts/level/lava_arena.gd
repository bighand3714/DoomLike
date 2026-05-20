# ==============================================================================
# LavaArena — 熔岩地狱竞技场（Phase 4）
# ==============================================================================
# 继承 ArenaLevel，覆写地面/边界颜色为熔岩主题（暗红黑+亮橙红），
# 随机生成熔岩河流（持续伤害）和柱状岩石（掩体）。
#
# 生成顺序：
#   1. 基类 _ready() → 地面 + 边界柱 + 容器 + RNG
#   2. _spawn_lava_rivers() → 随机位置/旋转，注册占用点
#   3. _spawn_rock_columns() → 避开熔岩占用 + 出生点安全区
# ==============================================================================

class_name LavaArena extends ArenaLevel


# ==============================================================================
# 熔岩专属参数
# ==============================================================================

## 熔岩河流数量
@export var lava_river_count: int = 2

## 柱状岩石数量
@export var rock_column_count: int = 18

## 岩石之间最小间距（米）
@export var rock_column_min_distance: float = 5.0

## 出生点安全半径（米）——此范围内不生成熔岩和岩石
@export var center_safe_radius: float = 10.0


# ==============================================================================
# _ready()
# ==============================================================================
func _ready() -> void:
	super._ready()
	_spawn_lava_rivers()
	_spawn_rock_columns()


# ==============================================================================
# 蒿子方法 —— 熔岩地狱主题色
# ==============================================================================

func _get_ground_color() -> Color:
	return Color(0.35, 0.12, 0.06)  # 暗红褐色地面，有足够亮度可见

func _get_boundary_color() -> Color:
	return Color(1.0, 0.35, 0.08)  # 亮橙红色边界柱

func _get_fog_color() -> Color:
	return Color(0.25, 0.1, 0.06)  # 暗红雾色，提供一定环境光


# ==============================================================================
# _spawn_lava_rivers() — 随机生成熔岩河流（Phase 4.5）
# ==============================================================================
# 每条河流：
#   - 在竞技场内随机选取中心位置
#   - 随机 Y 轴旋转角度
#   - 距出生点 > center_safe_radius，距边界 > 5m
#   - 河流之间保持 8m 以上间距（注册占用点）
func _spawn_lava_rivers() -> void:
	var LavaRiverScene := preload("res://scenes/hazards/lava_river.tscn")

	var spawned := 0
	for _i in range(lava_river_count):
		# 用大 margin 确保河流整体在竞技场内（河流长度 ~28m，一半 = 14m，加 5m 缓冲）
		var result := _randomizer.try_get_non_overlapping_point(
			get_arena_center(), arena_radius, _used_spawn_points,
			8.0,  # 河流之间最小间距 8m
			5.0,  # 距边界 5m 缩进
			center_safe_radius,  # 距出生点安全距离
			15
		)

		if not result.ok:
			print("LavaArena: 只生成了 %d/%d 条熔岩河流（位置不足）" % [spawned, lava_river_count])
			break

		var pos: Vector3 = result.position
		pos.y = 0.0

		var river := LavaRiverScene.instantiate()
		_hazards_root.add_child(river)
		river.global_position = pos
		river.rotation_degrees.y = rng.randf_range(0.0, 360.0)

		# 注册占用点（河流中心 + 半长作为近似影响范围）
		register_occupied_point(pos)
		spawned += 1

	print("LavaArena: 生成了 %d 条熔岩河流" % spawned)


# ==============================================================================
# _spawn_rock_columns() — 随机生成柱状岩石（Phase 4.7）
# ==============================================================================
# 岩石需要避开熔岩河流位置（通过 _used_spawn_points 自动互斥）+ 出生点安全区。
# 每根岩石距离边界至少 3m（避免卡住沿边界移动的玩家）。
func _spawn_rock_columns() -> void:
	var RockColumnScene := preload("res://scenes/props/rock_column_prop.tscn")

	var spawned := 0
	for _i in range(rock_column_count):
		var result := get_random_prop_position(rock_column_min_distance, center_safe_radius)

		if not result.ok:
			print("LavaArena: 只生成了 %d/%d 根岩石（位置不足）" % [spawned, rock_column_count])
			break

		var pos: Vector3 = result.position
		pos.y = 0.0

		var rock := RockColumnScene.instantiate()
		_props_root.add_child(rock)
		rock.global_position = pos
		rock.rotation_degrees.y = rng.randf_range(0.0, 360.0)

		# 随机缩放（0.9~1.4），让岩石大小有差异
		var sf := rng.randf_range(0.9, 1.4)
		rock.scale = Vector3(sf, sf, sf)

		register_occupied_point(pos)
		spawned += 1

	print("LavaArena: 生成了 %d 根岩石" % spawned)

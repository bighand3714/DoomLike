# ==============================================================================
# ArenaRandomizer — 竞技场随机数工具类（Phase 2.6）
# ==============================================================================
# 封装竞技场中所有"随机位置"的计算逻辑。每个 ArenaLevel 拥有自己独立的
# ArenaRandomizer 实例，通过 ArenaLevel.rng 提供随机数。
#
# 为什么需要这个类：
#   道具（枯树、岩柱）、危险区（熔岩河流）、刷怪点都需要在圆形区域内
#   随机选取位置。如果每个系统各自写随机逻辑，容易出现以下问题：
#     - 两个道具叠在一起（没做互斥检测）
#     - 道具刷在出生点旁边堵住玩家（没做安全距离）
#     - 道具刷到边界外面（没用 sqrt 分布）
#
#   集中在这里统一管理，所有随机位置都经过同样的"合法性检查"。
#
# 随机数原理（为什么用 sqrt(randf())）：
#   在圆形区域内均匀取点，如果直接随机半径，点会向中心聚集
#   （因为半径小的地方面积也小，半径大的地方面积大很多）。
#   sqrt(randf()) 让半径分布偏向边缘——面积越大的环概率越高，
#   结果才是真正的"均匀分布在圆内"。
# ==============================================================================

class_name ArenaRandomizer extends RefCounted

# ArenaLevel 的随机数生成器引用
var rng: RandomNumberGenerator


# ==============================================================================
# setup(rng_instance) — 绑定 ArenaLevel 的 RNG
# ==============================================================================
func setup(rng_instance: RandomNumberGenerator) -> void:
	rng = rng_instance


# ==============================================================================
# random_angle() — 返回 [0, 2π) 范围内的随机角度（弧度）
# ==============================================================================
func random_angle() -> float:
	return rng.randf_range(0.0, TAU)


# ==============================================================================
# get_random_point_inside(center, radius, margin) — 圆形区域内随机一点
# ==============================================================================
# margin —— 从实际边界向内缩进的距离，防止道具贴边生成。
#          例如 radius=45, margin=2 → 实际生成范围是半径 0~43 的圆。
#          返回的 Y 坐标为 0（地面高度），调用方根据道具类型自行调整。
func get_random_point_inside(center: Vector3, radius: float, margin: float = 0.0) -> Vector3:
	var effective_radius := radius - margin
	if effective_radius <= 0.0:
		return center

	# sqrt(randf()) 保证在圆形区域内均匀分布
	var r := sqrt(rng.randf()) * effective_radius
	var angle := rng.randf_range(0.0, TAU)

	return Vector3(
		center.x + cos(angle) * r,
		0.0,  # Y 坐标 = 地面高度，调用方可调整
		center.z + sin(angle) * r
	)


# ==============================================================================
# get_random_point_outside_boundary(center, arena_radius, spawn_outer_radius) — 边界外随机一点
# ==============================================================================
# 用于敌人生成：在圆形边界外（arena_radius）到刷怪外环（spawn_outer_radius）
# 之间的环形区域随机选点。敌人在此范围内出现，然后向竞技场内移动。
#
# 半径选取：
#   在 [arena_radius + 2, spawn_outer_radius - 1] 范围内均匀随机，
#   确保敌人不会正好刷在边界柱上（+2m 内缩）也不会刷到无限远。
func get_random_point_outside_boundary(center: Vector3, arena_radius: float, spawn_outer_radius: float) -> Vector3:
	var inner := arena_radius + 2.0
	var outer := spawn_outer_radius - 1.0
	var r := rng.randf_range(inner, outer)
	var angle := rng.randf_range(0.0, TAU)

	return Vector3(
		center.x + cos(angle) * r,
		0.0,
		center.z + sin(angle) * r
	)


# ==============================================================================
# is_far_enough(point, used_points, min_distance) — 检查点是否与已有点保持距离
# ==============================================================================
# 遍历已有位置列表，如果新点与任何一个旧点的 XZ 距离 < min_distance → 返回 false。
# 用于防止两个道具重叠生成。
#
# 参数：
#   point        —— 候选位置（Vector3）
#   used_points  —— 已占用的位置列表（Array[Vector3]）
#   min_distance —— 最小间距（米）
func is_far_enough(point: Vector3, used_points: Array, min_distance: float) -> bool:
	var p2 := Vector2(point.x, point.z)
	for used in used_points:
		var u2 := Vector2(used.x, used.z)
		if p2.distance_to(u2) < min_distance:
			return false
	return true


# ==============================================================================
# try_get_non_overlapping_point(center, radius, used_points, min_distance, margin, max_attempts) — 尝试获取不重叠的随机点
# ==============================================================================
# 在圆形区域内尝试 max_attempts 次随机取点，返回第一个满足所有条件的点。
# 如果全部尝试都失败，返回 { "ok": false, "position": Vector3.ZERO }。
#
# 参数：
#   center                  —— 竞技场中心
#   radius                  —— 竞技场可玩半径
#   used_points             —— 已占用的点列表
#   min_distance            —— 与已占点的最小间距
#   margin                  —— 距边界的缩进（0 = 可以贴边）
#   min_distance_from_center —— 距中心的最小距离（0 = 可以在圆心）
#   max_attempts            —— 最大尝试次数（默认 20）
#
# 返回 Dictionary：
#   "ok"       —— bool，是否成功找到合法位置
#   "position" —— Vector3，找到的位置（失败则为 ZERO）
func try_get_non_overlapping_point(center: Vector3, radius: float, used_points: Array, min_distance: float, margin: float = 0.0, min_distance_from_center: float = 0.0, max_attempts: int = 20) -> Dictionary:
	for _i in range(max_attempts):
		var pos := get_random_point_inside(center, radius, margin)
		if pos.distance_to(center) < min_distance_from_center:
			continue
		if is_far_enough(pos, used_points, min_distance):
			return { "ok": true, "position": pos }
	return { "ok": false, "position": Vector3.ZERO }

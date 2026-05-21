# ==============================================================================
# Minimap — 屏幕角落 180x180 圆形小地图，25m 半径范围
# ==============================================================================
# 每 0.03s 刷新数据 + 重绘，20+ FPS 保证流畅度。
# 显示玩家绿点 + 敌人红点 + 玩家朝向箭头 + 红圈边界。
# ==============================================================================

class_name Minimap extends Control

@export var map_size: float = 180.0
@export var world_range: float = 25.0
@export var refresh_interval: float = 0.03
@export var background_color: Color = Color(0.0, 0.0, 0.0, 0.55)
@export var player_color: Color = Color(0.0, 1.0, 0.0, 0.9)
@export var enemy_color: Color = Color(1.0, 0.15, 0.15, 0.85)

var _player: CharacterBody3D = null
var _refresh_timer: float = 0.0
var _data_timer: float = 0.0
var _enemy_positions: Array = []
var _player_pos: Vector3 = Vector3.ZERO
var _player_yaw: float = 0.0

func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	offset_left = -(map_size + 12.0)
	offset_right = -12.0
	offset_top = 12.0
	offset_bottom = map_size + 12.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	_refresh_timer -= delta
	_data_timer -= delta

	# 每 0.1s 采集一次敌人位置（避免每帧遍历所有敌人）
	if _data_timer <= 0.0:
		_data_timer = 0.1
		_update_map_data()

	# 高频重绘保证流畅（仅重绘缓存的点，极低开销）
	if _refresh_timer <= 0.0:
		_refresh_timer = refresh_interval
		queue_redraw()

func _update_map_data() -> void:
	if _player == null:
		return
	_player_pos = _player.global_position
	_player_yaw = _player.rotation.y
	_enemy_positions.clear()
	for node in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(node):
			continue
		_enemy_positions.append(node.global_position)

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(map_size, map_size))
	var center := rect.get_center()
	var radius: float = map_size / 2.0
	var map_scale: float = map_size / (world_range * 2.0)

	# 背景圆
	draw_circle(center, radius, background_color)

	# 红圈边界（25m 范围）
	draw_arc(center, radius, 0.0, TAU, 48, Color(1.0, 0.15, 0.15, 0.6), 1.5)

	# 敌人红点
	var clip_r := radius - 3.0
	for enemy_pos in _enemy_positions:
		var rel: Vector3 = enemy_pos - _player_pos
		var map_x: float = rel.x * map_scale
		var map_z: float = rel.z * map_scale
		var dot_pos := center + Vector2(map_x, map_z)
		if dot_pos.distance_squared_to(center) < clip_r * clip_r:
			draw_circle(dot_pos, 2.5, enemy_color)

	# 玩家绿点（中心）
	draw_circle(center, 4.0, player_color)

	# 玩家朝向箭头
	var arrow_dir := Vector2(-sin(_player_yaw), -cos(_player_yaw))
	var arrow_tip := center + arrow_dir * 11.0
	var arrow_left := center + arrow_dir.rotated(PI * 0.75) * 7.0
	var arrow_right := center + arrow_dir.rotated(-PI * 0.75) * 7.0
	draw_colored_polygon(PackedVector2Array([arrow_tip, arrow_left, arrow_right]), player_color)

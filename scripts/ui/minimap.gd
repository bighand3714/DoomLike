# ==============================================================================
# Minimap — 屏幕角落 150x150 圆形小地图
# ==============================================================================
# 每 0.2s 刷新，显示玩家绿点 + 敌人红点 + 玩家朝向箭头。
# ==============================================================================

class_name Minimap extends Control

@export var map_size: float = 150.0
@export var world_range: float = 30.0
@export var refresh_interval: float = 0.2
@export var background_color: Color = Color(0.0, 0.0, 0.0, 0.5)
@export var player_color: Color = Color(0.0, 1.0, 0.0, 0.9)
@export var enemy_color: Color = Color(1.0, 0.0, 0.0, 0.8)

var _player: CharacterBody3D = null
var _refresh_timer: float = 0.0
var _enemy_positions: Array = []
var _player_pos: Vector3 = Vector3.ZERO
var _player_yaw: float = 0.0

func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	offset_left = -(map_size + 10.0)
	offset_right = -10.0
	offset_top = 10.0
	offset_bottom = map_size + 10.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = refresh_interval
		_update_map_data()
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
	var map_scale: float = map_size / (world_range * 2.0)

	# 背景圆
	draw_circle(center, map_size / 2.0, background_color)

	# 敌人红点
	for enemy_pos in _enemy_positions:
		var rel: Vector3 = enemy_pos - _player_pos
		var map_x: float = rel.x * map_scale
		var map_z: float = rel.z * map_scale
		var dot_pos := center + Vector2(map_x, map_z)
		if dot_pos.distance_to(center) < map_size / 2.0 - 3.0:
			draw_circle(dot_pos, 3.0, enemy_color)

	# 玩家绿点（中心）
	draw_circle(center, 4.0, player_color)

	# 玩家朝向箭头
	var arrow_dir := Vector2(sin(_player_yaw), -cos(_player_yaw))
	var arrow_tip := center + arrow_dir * 10.0
	var arrow_left := center + arrow_dir.rotated(PI * 0.8) * 6.0
	var arrow_right := center + arrow_dir.rotated(-PI * 0.8) * 6.0
	draw_colored_polygon(PackedVector2Array([arrow_tip, arrow_left, arrow_right]), player_color)

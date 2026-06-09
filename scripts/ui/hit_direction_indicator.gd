# ==============================================================================
# HitDirectionIndicator — 受击方向指示器 + 近身威胁指示器
# ==============================================================================
# 红色三角箭头：受伤时指向攻击者方向，1s 渐隐。
# 灰色三角箭头：敌人/子弹进入绿圈(3m)时持续显示方位。
# 挂在 UI CanvasLayer 下。
# ==============================================================================

class_name HitDirectionIndicator extends Control

@export var arrow_size: float = 40.0
@export var arrow_color: Color = Color(1.0, 0.2, 0.1, 0.8)
@export var fade_time: float = 1.0
@export var edge_margin: float = 60.0

@export var proximity_color: Color = Color(0.55, 0.55, 0.55, 0.7)
@export var proximity_arrow_size: float = 22.0
@export var proximity_range: float = 3.0

var _indicators: Array = []
var _proximity_angles: Array[float] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_on_resized)


func _on_resized() -> void:
	queue_redraw()


## 添加一个受击方向指示器
func add_hit_indicator(direction_3d: Vector3, camera_basis: Basis) -> void:
	var local_dir := camera_basis.inverse() * direction_3d
	var screen_dir := Vector2(local_dir.x, local_dir.z)
	if screen_dir.length_squared() < 0.01:
		screen_dir = Vector2.DOWN
	var angle: float = screen_dir.angle()
	_indicators.append({
		"angle": angle,
		"alpha": 1.0,
		"timer": fade_time
	})


## 更新近身威胁方向（主循环每帧调用）
func update_proximity_threats(world_positions: Array[Vector3], player_pos: Vector3, camera_basis: Basis) -> void:
	_proximity_angles.clear()
	for pos in world_positions:
		var to_threat := pos - player_pos
		var dist_xz := Vector2(to_threat.x, to_threat.z).length()
		if dist_xz > proximity_range:
			continue
		var local_dir := camera_basis.inverse() * to_threat.normalized()
		var screen_dir := Vector2(local_dir.x, local_dir.z)
		if screen_dir.length_squared() < 0.01:
			screen_dir = Vector2.DOWN
		_proximity_angles.append(screen_dir.angle())
	queue_redraw()


func _process(delta: float) -> void:
	var needs_update: bool = false
	for i in range(_indicators.size() - 1, -1, -1):
		_indicators[i]["timer"] -= delta
		_indicators[i]["alpha"] = clampf(_indicators[i]["timer"] / fade_time, 0.0, 1.0)
		if _indicators[i]["timer"] <= 0.0:
			_indicators.remove_at(i)
			needs_update = true
		else:
			needs_update = true
	if needs_update:
		queue_redraw()


func _draw() -> void:
	var canvas_size: Vector2 = size
	if canvas_size.x <= 0.0 or canvas_size.y <= 0.0:
		return
	var center: Vector2 = canvas_size / 2.0
	var radius: float = maxf(0.0, minf(canvas_size.x, canvas_size.y) / 2.0 - edge_margin)

	# 灰色近身威胁箭头
	for angle in _proximity_angles:
		var dir := Vector2(cos(angle), sin(angle))
		var pos: Vector2 = center + dir * radius
		var color := proximity_color
		var sz: float = proximity_arrow_size
		var perp := Vector2(-dir.y, dir.x) * (sz * 0.3)
		var points := PackedVector2Array([
			pos + dir * sz * 0.6,
			pos - dir * sz * 0.3 + perp,
			pos - dir * sz * 0.3 - perp
		])
		draw_colored_polygon(points, color)

	# 红色受击方向箭头
	for indicator in _indicators:
		var angle: float = indicator["angle"]
		var alpha: float = indicator["alpha"]
		var dir := Vector2(cos(angle), sin(angle))
		var pos: Vector2 = center + dir * radius

		var color := arrow_color
		color.a *= alpha

		var perp := Vector2(-dir.y, dir.x) * (arrow_size * 0.3)
		var points := PackedVector2Array([
			pos + dir * arrow_size * 0.6,
			pos - dir * arrow_size * 0.3 + perp,
			pos - dir * arrow_size * 0.3 - perp
		])
		draw_colored_polygon(points, color)

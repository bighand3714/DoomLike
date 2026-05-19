# ==============================================================================
# HitDirectionIndicator — 受击方向指示器
# ==============================================================================
# 屏幕边缘显示红色弧形箭头，指向伤害来源方向，1s 渐隐。
# 挂在 UI CanvasLayer 下。
# ==============================================================================

class_name HitDirectionIndicator extends Control

@export var arrow_size: float = 40.0
@export var arrow_color: Color = Color(1.0, 0.2, 0.1, 0.8)
@export var fade_time: float = 1.0
@export var edge_margin: float = 60.0

var _indicators: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## 添加一个受击方向指示器
func add_hit_indicator(direction_3d: Vector3, camera_basis: Basis) -> void:
	# 将世界空间方向转换到相机局部空间，再映射为屏幕方向
	var local_dir := camera_basis.inverse() * direction_3d
	var screen_dir := Vector2(local_dir.x, -local_dir.z)
	if screen_dir.length_squared() < 0.01:
		screen_dir = Vector2.DOWN
	var angle: float = screen_dir.angle()
	_indicators.append({
		"angle": angle,
		"alpha": 1.0,
		"timer": fade_time
	})

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
	var viewport_size: Vector2 = get_viewport().size
	var center: Vector2 = viewport_size / 2.0
	var radius: float = minf(viewport_size.x, viewport_size.y) / 2.0 - edge_margin

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

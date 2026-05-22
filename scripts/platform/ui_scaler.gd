extends Node

const DESIGN_WIDTH: float = 1280.0
const DESIGN_HEIGHT: float = 720.0

func _ready() -> void:
	get_tree().root.size_changed.connect(_update_scale)
	_update_scale()

func _update_scale() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var scale_x := viewport_size.x / DESIGN_WIDTH
	var scale_y := viewport_size.y / DESIGN_HEIGHT
	var scale := minf(scale_x, scale_y)
	var parent_node := get_parent()
	if is_instance_valid(parent_node) and parent_node is CanvasItem:
		parent_node.scale = Vector2(scale, scale)

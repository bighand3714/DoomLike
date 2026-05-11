extends Node3D

@onready var _player: CharacterBody3D = %Player
@onready var _level_root: Node3D = %Level
@onready var _crosshair: ColorRect = %Crosshair


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_test_room()
	_setup_crosshair()


func _build_test_room() -> void:
	const ROOM_W := 12.0
	const ROOM_D := 12.0
	const ROOM_H := 4.0
	const WALL_T := 0.3

	var floor_mat := _make_color_material(Color(0.3, 0.28, 0.25))
	var wall_mat := _make_color_material(Color(0.45, 0.42, 0.38))
	var ceiling_mat := _make_color_material(Color(0.35, 0.33, 0.3))

	_floor(ROOM_W, ROOM_D, WALL_T, floor_mat)
	_ceiling(ROOM_W, ROOM_D, ROOM_H, WALL_T, ceiling_mat)
	_wall(Vector3(0, ROOM_H / 2.0, -ROOM_D / 2.0), Vector3(ROOM_W, ROOM_H, WALL_T), wall_mat)
	_wall(Vector3(0, ROOM_H / 2.0, ROOM_D / 2.0), Vector3(ROOM_W, ROOM_H, WALL_T), wall_mat)
	_wall(Vector3(-ROOM_W / 2.0, ROOM_H / 2.0, 0), Vector3(WALL_T, ROOM_H, ROOM_D), wall_mat)
	_wall(Vector3(ROOM_W / 2.0, ROOM_H / 2.0, 0), Vector3(WALL_T, ROOM_H, ROOM_D), wall_mat)

	# Central pillar for testing movement around obstacles
	var pillar_mat := _make_color_material(Color(0.5, 0.35, 0.3))
	_csg_box(Vector3(0, ROOM_H / 2.0, 0), Vector3(1.2, ROOM_H, 1.2), pillar_mat)

	# Directional light
	var light := DirectionalLight3D.new()
	light.position = Vector3(4, ROOM_H + 2, 2)
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 0.8
	_level_root.add_child(light)

	# Fill light
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, ROOM_H - 0.5, 0)
	fill.light_energy = 0.3
	_level_root.add_child(fill)


func _floor(w: float, d: float, t: float, mat: Material) -> CSGBox3D:
	var box := _csg_box(Vector3(0, -t / 2.0, 0), Vector3(w, t, d), mat)
	box.name = "Floor"
	return box


func _ceiling(w: float, d: float, h: float, t: float, mat: Material) -> CSGBox3D:
	var box := _csg_box(Vector3(0, h + t / 2.0, 0), Vector3(w, t, d), mat)
	box.name = "Ceiling"
	return box


func _wall(pos: Vector3, size: Vector3, mat: Material) -> CSGBox3D:
	return _csg_box(pos, size, mat)


func _csg_box(pos: Vector3, size: Vector3, mat: Material) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.position = pos
	box.size = size
	box.material_override = mat
	box.use_collision = true
	_level_root.add_child(box)
	return box


func _make_color_material(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.9
	return mat


func _setup_crosshair() -> void:
	_crosshair.color = Color(0.0, 1.0, 0.0, 0.7)
	_crosshair.size = Vector2(4, 4)
	_crosshair.position = Vector2(get_viewport().size) / 2.0 - _crosshair.size / 2.0
	get_tree().root.size_changed.connect(_on_window_resized)


func _on_window_resized() -> void:
	_crosshair.position = Vector2(get_viewport().size) / 2.0 - _crosshair.size / 2.0

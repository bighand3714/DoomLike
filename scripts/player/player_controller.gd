extends CharacterBody3D

## Movement settings
@export var move_speed := 8.0
@export var acceleration := 40.0
@export var friction := 30.0

## Gravity
@export var gravity := 20.0

## Mouse settings
@export var mouse_sensitivity := 0.002
@export var invert_y := false
@export var vertical_limit := 90.0

var _yaw := 0.0
var _pitch := 0.0

@onready var _camera: Camera3D = %Camera3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		var pitch_delta: float = event.relative.y * mouse_sensitivity
		if invert_y:
			pitch_delta = -pitch_delta
		_pitch = clampf(_pitch - pitch_delta, -deg_to_rad(vertical_limit), deg_to_rad(vertical_limit))

		transform.basis = Basis.from_euler(Vector3(0.0, _yaw, 0.0))
		_camera.transform.basis = Basis.from_euler(Vector3(_pitch, 0.0, 0.0))

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			get_tree().quit()


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Horizontal movement
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction.length_squared() > 0.0:
		velocity.x = move_toward(velocity.x, direction.x * move_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * move_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	move_and_slide()

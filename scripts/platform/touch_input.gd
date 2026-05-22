extends Control

## 虚拟触屏 HUD — Android/触摸设备 DOOM 风格操作层
## 通过 Input.parse_input_event() 注入虚拟输入，现有游戏逻辑无需修改

const JOYSTICK_RADIUS: float = 80.0
const JOYSTICK_DEADZONE: float = 20.0
const BUTTON_SIZE: float = 64.0
const BTN_MARGIN: float = 12.0

var _move_touch_index: int = -1
var _look_touch_index: int = -1
var _move_origin: Vector2 = Vector2.ZERO
var _active_actions: Dictionary = {}  # touch_index -> action_name

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return

	var ev: InputEvent = event
	var screen_pos: Vector2 = ev.position
	var half_width: float = get_viewport().get_visible_rect().size.x * 0.5
	var is_left: bool = screen_pos.x < half_width

	if event is InputEventScreenTouch:
		var touch_ev := event as InputEventScreenTouch
		if touch_ev.pressed:
			if is_left:
				_start_move_joystick(touch_ev.index, screen_pos)
			else:
				_start_look(touch_ev.index, screen_pos)
		else:
			if touch_ev.index == _move_touch_index:
				_stop_move_joystick()
			elif touch_ev.index == _look_touch_index:
				_stop_look()

	elif event is InputEventScreenDrag:
		var drag_ev := event as InputEventScreenDrag
		if drag_ev.index == _move_touch_index:
			_update_move(drag_ev.position)
		elif drag_ev.index == _look_touch_index:
			_update_look(drag_ev.relative)

func _start_move_joystick(index: int, pos: Vector2) -> void:
	_move_touch_index = index
	_move_origin = pos

func _stop_move_joystick() -> void:
	_move_touch_index = -1
	_move_origin = Vector2.ZERO
	_inject_action("move_forward", false)
	_inject_action("move_back", false)
	_inject_action("move_left", false)
	_inject_action("move_right", false)

func _update_move(pos: Vector2) -> void:
	var offset := pos - _move_origin
	var direction := offset.normalized()
	var strength := minf(offset.length() / JOYSTICK_RADIUS, 1.0)
	if offset.length() < JOYSTICK_DEADZONE:
		strength = 0.0

	var deadzone_factor := 0.0
	if strength > 0.0:
		deadzone_factor = (strength - JOYSTICK_DEADZONE / JOYSTICK_RADIUS) / (1.0 - JOYSTICK_DEADZONE / JOYSTICK_RADIUS)
		deadzone_factor = clampf(deadzone_factor, 0.0, 1.0)

	_inject_action("move_forward", direction.y < -0.3 and deadzone_factor > 0.0, absf(direction.y) * deadzone_factor)
	_inject_action("move_back", direction.y > 0.3 and deadzone_factor > 0.0, absf(direction.y) * deadzone_factor)
	_inject_action("move_left", direction.x < -0.3 and deadzone_factor > 0.0, absf(direction.x) * deadzone_factor)
	_inject_action("move_right", direction.x > 0.3 and deadzone_factor > 0.0, absf(direction.x) * deadzone_factor)

func _start_look(index: int, pos: Vector2) -> void:
	_look_touch_index = index

func _stop_look() -> void:
	_look_touch_index = -1

func _update_look(relative: Vector2) -> void:
	if relative.length_squared() < 0.01:
		return
	var mouse_ev := InputEventMouseMotion.new()
	mouse_ev.relative = relative * 0.5  # 灵敏度减半防止过于灵敏
	Input.parse_input_event(mouse_ev)

func _inject_action(action_name: String, pressed: bool, strength: float = 1.0) -> void:
	var ev := InputEventAction.new()
	ev.action = action_name
	ev.pressed = pressed
	ev.strength = strength
	Input.parse_input_event(ev)

# ==============================================================================
# 按钮 HUD 布局（代码创建，无需场景文件）
# ==============================================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_create_buttons.call_deferred()

func _create_buttons() -> void:
	if not PlatformDetector.is_touch_primary():
		return
	_create_button("btn_fire", "Fire", Vector2(1.0, 0.82), "primary_fire")
	_create_button("btn_jump", "Jump", Vector2(0.88, 0.62), "jump")
	_create_button("btn_whip", "Whip", Vector2(1.0, 0.62), "whip_throw")
	_create_button("btn_dash", "Dash", Vector2(0.88, 0.42), "dash_sprint")
	_create_button("btn_action", "Act", Vector2(1.0, 0.42), "action_key")
	_create_button("btn_reload", "Rel", Vector2(0.88, 0.22), "reload")

	# 武器栏水平排列
	_create_button("btn_w1", "1", Vector2(0.36, 0.02), "weapon_1")
	_create_button("btn_w2", "2", Vector2(0.43, 0.02), "weapon_2")
	_create_button("btn_w3", "3", Vector2(0.50, 0.02), "weapon_3")
	_create_button("btn_w4", "4", Vector2(0.57, 0.02), "weapon_4")

func _create_button(btn_name: String, label: String, anchor_pos: Vector2, action: String) -> void:
	var btn := Button.new()
	btn.name = btn_name
	btn.text = label
	btn.flat = false

	# 锚点定位
	btn.anchor_left = anchor_pos.x
	btn.anchor_right = anchor_pos.x
	btn.anchor_top = anchor_pos.y
	btn.anchor_bottom = anchor_pos.y
	btn.offset_left = -BUTTON_SIZE / 2.0
	btn.offset_right = BUTTON_SIZE / 2.0
	btn.offset_top = -BUTTON_SIZE / 2.0
	btn.offset_bottom = BUTTON_SIZE / 2.0
	btn.mouse_filter = Control.MOUSE_FILTER_PASS

	# 样式
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 1.0, 1.0, 0.35)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)

	var style_pressed := style.duplicate() as StyleBoxFlat
	style_pressed.bg_color = Color(1.0, 1.0, 1.0, 0.3)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.85))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))

	# 连接信号
	btn.button_down.connect(_on_hud_button_down.bind(action))
	btn.button_up.connect(_on_hud_button_up.bind(action))

	add_child(btn)

func _on_hud_button_down(action: String) -> void:
	_inject_action(action, true)

func _on_hud_button_up(action: String) -> void:
	_inject_action(action, false)

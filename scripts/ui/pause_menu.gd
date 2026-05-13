# ==============================================================================
# PauseMenu — 暂停菜单
# ==============================================================================
# 游戏中按 Esc 显示，覆盖在当前画面上。
# ==============================================================================

extends CanvasLayer

signal resumed()
signal back_to_menu()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_ui()
	hide()


func _create_ui() -> void:
	# 半透明黑底
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 标题
	var title := Label.new()
	title.text = "暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.anchor_top = 0.0
	title.offset_left = -100.0
	title.offset_right = 100.0
	title.offset_top = 180.0
	add_child(title)

	_add_button("继续游戏", 260.0, _on_resume)
	_add_button("返回主菜单", 320.0, _on_back_to_menu)


func _add_button(text: String, y: float, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 18)
	btn.anchor_left = 0.5
	btn.anchor_right = 0.5
	btn.anchor_top = 0.0
	btn.offset_left = -100.0
	btn.offset_right = 100.0
	btn.offset_top = y
	btn.offset_bottom = y + 36.0
	btn.pressed.connect(callback)
	add_child(btn)


func _on_resume() -> void:
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resumed.emit()


func _on_back_to_menu() -> void:
	hide()
	get_tree().paused = false
	back_to_menu.emit()


func _input(event: InputEvent) -> void:
	# Esc 键恢复游戏
	if event.is_action_pressed("ui_cancel") and visible:
		_on_resume()


func show_pause() -> void:
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

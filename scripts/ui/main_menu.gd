# ==============================================================================
# MainMenu — 主菜单
# ==============================================================================
# CanvasLayer，挂在 UI 下。游戏启动时显示，点击"开始游戏"后隐藏。
# ==============================================================================

extends CanvasLayer

signal game_started()


func _ready() -> void:
	# PROCESS_MODE_ALWAYS 确保暂停时按钮仍可点击
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func _create_ui() -> void:
	# 纯黑背景
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 标题
	var title := Label.new()
	title.text = "DOOM-LIKE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.0))
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.anchor_top = 0.0
	title.offset_left = -200.0
	title.offset_right = 200.0
	title.offset_top = 120.0
	add_child(title)

	# 副标题
	var subtitle := Label.new()
	subtitle.text = "一款复古风第一人称射击游戏"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	subtitle.anchor_left = 0.5
	subtitle.anchor_right = 0.5
	subtitle.anchor_top = 0.0
	subtitle.offset_left = -200.0
	subtitle.offset_right = 200.0
	subtitle.offset_top = 190.0
	add_child(subtitle)

	# 按钮
	_add_button("开始游戏", 280.0, _on_start)
	_add_button("退出", 340.0, _on_quit)


func _add_button(text: String, y: float, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 20)
	btn.anchor_left = 0.5
	btn.anchor_right = 0.5
	btn.anchor_top = 0.0
	btn.offset_left = -100.0
	btn.offset_right = 100.0
	btn.offset_top = y
	btn.offset_bottom = y + 40.0
	btn.pressed.connect(callback)
	add_child(btn)


func _on_start() -> void:
	# 隐藏自己，恢复游戏
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	game_started.emit()


func _on_quit() -> void:
	get_tree().quit()


func show_menu() -> void:
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

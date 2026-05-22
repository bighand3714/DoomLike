# ==============================================================================
# GameOverScreen — 结算界面
# ==============================================================================
# 玩家死亡后显示本局统计和历史记录。按钮操作通过信号通知 main.gd。
# ==============================================================================

extends CanvasLayer

const LevelRegistryClass = preload("res://scripts/level/level_registry.gd")

signal restart_requested()
signal level_select_requested()
signal main_menu_requested()

var _buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_ui()
	hide()


func _create_ui() -> void:
	# 半透明黑底
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 标题
	_title = _make_centered_label("", 36, Color(1.0, 0.3, 0.0))
	_title.offset_top = 60.0
	_title.offset_bottom = 100.0

	# 新纪录
	_new_record = _make_centered_label("★ 新纪录 ★", 22, Color(1.0, 0.85, 0.1))
	_new_record.offset_top = 105.0
	_new_record.offset_bottom = 135.0
	_new_record.hide()

	# 本局统计
	_score_label = _make_centered_label("分数: 0", 24, Color.WHITE)
	_score_label.offset_top = 155.0
	_score_label.offset_bottom = 185.0

	_time_label = _make_centered_label("时间: 0.0 秒", 20, Color(0.8, 0.8, 0.8))
	_time_label.offset_top = 195.0
	_time_label.offset_bottom = 225.0

	_kills_label = _make_centered_label("击杀: 0", 20, Color(0.8, 0.8, 0.8))
	_kills_label.offset_top = 235.0
	_kills_label.offset_bottom = 265.0

	# 历史记录
	_best_score_label = _make_centered_label("历史最高分: ---", 18, Color(1.0, 0.85, 0.3))
	_best_score_label.offset_top = 290.0
	_best_score_label.offset_bottom = 316.0

	_best_time_label = _make_centered_label("历史最长时间: ---", 18, Color(1.0, 0.85, 0.3))
	_best_time_label.offset_top = 322.0
	_best_time_label.offset_bottom = 348.0

	# 按钮
	_add_button("重新开始本关", 390.0, _on_restart)
	_add_button("返回选关", 440.0, _on_level_select)
	_add_button("返回主菜单", 490.0, _on_main_menu)


# Label 引用
var _title: Label
var _new_record: Label
var _score_label: Label
var _time_label: Label
var _kills_label: Label
var _best_score_label: Label
var _best_time_label: Label


func _make_centered_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.anchor_top = 0.0
	label.anchor_bottom = 0.0
	label.offset_left = -200.0
	label.offset_right = 200.0
	add_child(label)
	return label


func _add_button(text: String, y: float, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 18)
	btn.anchor_left = 0.45
	btn.anchor_right = 0.55
	btn.anchor_top = 0.0
	btn.anchor_bottom = 0.0
	btn.offset_left = -90.0
	btn.offset_right = 90.0
	btn.offset_top = y
	btn.offset_bottom = y + 36.0
	btn.pressed.connect(callback)
	_buttons.append(btn)
	add_child(btn)


# ==============================================================================
# show_results(data) — 显示结算数据
# ==============================================================================
func show_results(data: Dictionary) -> void:
	# 关卡名——从 LevelRegistry 读取，不再硬编码
	var level_id: String = data.get("level_id", "")
	_title.text = LevelRegistryClass.get_display_name(level_id)

	# 本局
	_score_label.text = "分数: %d" % data.get("score", 0)
	_time_label.text = "时间: %.1f 秒" % data.get("survival_time", 0.0)
	_kills_label.text = "击杀: %d" % data.get("kills", 0)

	# 历史
	_best_score_label.text = "历史最高分: %d" % data.get("best_score", 0)
	_best_time_label.text = "历史最长时间: %.1f 秒" % data.get("best_time", 0.0)

	# 新纪录
	if data.get("is_new_record", false):
		_new_record.show()
	else:
		_new_record.hide()
	if not _buttons.is_empty():
		_buttons[0].grab_focus()
		for j in range(_buttons.size() - 1):
			_buttons[j].focus_neighbor_bottom = _buttons[j + 1].get_path()
			_buttons[j + 1].focus_neighbor_top = _buttons[j].get_path()


# ==============================================================================
# 按钮回调
# ==============================================================================


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		_on_main_menu()

func _on_restart() -> void:
	restart_requested.emit()

func _on_level_select() -> void:
	level_select_requested.emit()

func _on_main_menu() -> void:
	main_menu_requested.emit()

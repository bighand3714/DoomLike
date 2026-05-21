# ==============================================================================
# PauseMenu — 暂停菜单
# ==============================================================================
# 游戏中按 Esc 显示，覆盖在当前画面上。
# 按钮操作通过信号通知 main.gd 状态机，不直接控制游戏状态。
# 显示当前已拥有的技能及等级。
# ==============================================================================

extends CanvasLayer

signal resumed()
signal back_to_menu()

var _skills_container: VBoxContainer


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

	# --- 已拥有技能面板 ---
	var skills_title := Label.new()
	skills_title.text = "已拥有技能"
	skills_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skills_title.add_theme_font_size_override("font_size", 20)
	skills_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	skills_title.anchor_left = 0.5
	skills_title.anchor_right = 0.5
	skills_title.anchor_top = 0.0
	skills_title.offset_left = -200.0
	skills_title.offset_right = 200.0
	skills_title.offset_top = 400.0
	skills_title.offset_bottom = 426.0
	add_child(skills_title)

	_skills_container = VBoxContainer.new()
	_skills_container.anchor_left = 0.5
	_skills_container.anchor_right = 0.5
	_skills_container.anchor_top = 0.0
	_skills_container.offset_left = -250.0
	_skills_container.offset_right = 250.0
	_skills_container.offset_top = 436.0
	_skills_container.add_theme_constant_override("separation", 6)
	add_child(_skills_container)


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
	resumed.emit()


func _on_back_to_menu() -> void:
	back_to_menu.emit()


func _input(event: InputEvent) -> void:
	# Esc 键恢复游戏——通过信号通知状态机
	if event.is_action_pressed("ui_cancel") and visible:
		resumed.emit()


func show_pause() -> void:
	_refresh_skills()
	show()


## 从 PlayerProgression 读取已拥有技能并刷新显示
func _refresh_skills() -> void:
	# 清空旧内容
	for child in _skills_container.get_children():
		_skills_container.remove_child(child)
		child.queue_free()

	var progression = GameBus.player_progression
	if progression == null or not progression.has_method("get_owned_upgrades"):
		var empty_label := Label.new()
		empty_label.text = "暂无技能"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_skills_container.add_child(empty_label)
		return

	var owned: Array = progression.get_owned_upgrades()
	if owned.is_empty():
		var empty_label := Label.new()
		empty_label.text = "暂无技能"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_skills_container.add_child(empty_label)
		return

	var cat_names := ["武器", "铁鞭", "生存", "经济", "工具"]
	for info in owned:
		var cat: int = info.get("category", 0)
		var cat_name: String = cat_names[cat] if cat < cat_names.size() else "其他"
		var name_str: String = info.get("name", "???")
		var lv: int = info.get("level", 1)
		var max_lv: int = info.get("max_level", 99)
		var text := "%s  %s  Lv.%d/%d" % [cat_name, name_str, lv, max_lv]

		var label := Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		_skills_container.add_child(label)

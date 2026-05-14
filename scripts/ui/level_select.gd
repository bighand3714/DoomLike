# ==============================================================================
# LevelSelect — 选关界面
# ==============================================================================
# 显示两个关卡面板（荒漠 / 熔岩地狱），含关卡名、历史最高分、最长时间。
# 点击面板发射 level_selected(level_id)，由 main.gd 状态机处理。
# ==============================================================================

extends CanvasLayer

signal level_selected(level_id: String)
signal back_requested()

const LEVELS: Array[Dictionary] = [
	{ id = "desert", name = "第一关：荒漠", desc = "枯树作为掩体\n视野开阔，适合入门", color = Color(0.76, 0.66, 0.4) },
	{ id = "lava",   name = "第二关：熔岩地狱", desc = "熔岩河流持续伤害\n柱状岩石提供掩体", color = Color(0.7, 0.2, 0.1) },
]


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
	var title := Label.new()
	title.text = "选择关卡"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.anchor_top = 0.0
	title.offset_left = -150.0
	title.offset_right = 150.0
	title.offset_top = 60.0
	title.offset_bottom = 100.0
	add_child(title)

	# 两个关卡面板（左右排列）
	_create_level_panel(0, LEVELS[0])
	_create_level_panel(1, LEVELS[1])

	# 返回按钮
	var back_btn := Button.new()
	back_btn.text = "返回主菜单"
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.anchor_left = 0.5
	back_btn.anchor_right = 0.5
	back_btn.anchor_top = 1.0
	back_btn.anchor_bottom = 1.0
	back_btn.offset_left = -80.0
	back_btn.offset_right = 80.0
	back_btn.offset_top = -56.0
	back_btn.offset_bottom = -20.0
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)


func _create_level_panel(index: int, data: Dictionary) -> void:
	var center_x := 0.31 + float(index) * 0.38

	# 面板背景（ColorRect + 边框）
	var bg := ColorRect.new()
	bg.color = Color(data.color.r * 0.15, data.color.g * 0.15, data.color.b * 0.05, 0.9)
	bg.anchor_left = center_x - 0.16
	bg.anchor_right = center_x + 0.16
	bg.anchor_top = 0.0
	bg.anchor_bottom = 0.0
	bg.offset_top = 140.0
	bg.offset_bottom = 430.0
	add_child(bg)

	# 边框（用四个 ColorRect 拼出 2px 边框）
	var bc: Color = data.color
	# 上
	var top := ColorRect.new(); top.color = bc; bg.add_child(top)
	top.anchor_left = 0.0; top.anchor_right = 1.0
	top.anchor_top = 0.0; top.anchor_bottom = 0.0
	top.offset_top = 0.0; top.offset_bottom = 2.0
	# 下
	var bottom := ColorRect.new(); bottom.color = bc; bg.add_child(bottom)
	bottom.anchor_left = 0.0; bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0; bottom.anchor_bottom = 1.0
	bottom.offset_top = -2.0; bottom.offset_bottom = 0.0
	# 左
	var left := ColorRect.new(); left.color = bc; bg.add_child(left)
	left.anchor_left = 0.0; left.anchor_right = 0.0
	left.anchor_top = 0.0; left.anchor_bottom = 1.0
	left.offset_left = 0.0; left.offset_right = 2.0
	# 右
	var right := ColorRect.new(); right.color = bc; bg.add_child(right)
	right.anchor_left = 1.0; right.anchor_right = 1.0
	right.anchor_top = 0.0; right.anchor_bottom = 1.0
	right.offset_left = -2.0; right.offset_right = 0.0

	# 关卡名称
	var name_label := Label.new()
	name_label.text = data.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", data.color)
	name_label.anchor_left = 0.0
	name_label.anchor_right = 1.0
	name_label.anchor_top = 0.0
	name_label.offset_top = 20.0
	name_label.offset_bottom = 50.0
	bg.add_child(name_label)

	# 关卡描述
	var desc_label := Label.new()
	desc_label.text = data.desc
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_label.anchor_left = 0.0
	desc_label.anchor_right = 1.0
	desc_label.anchor_top = 0.0
	desc_label.offset_top = 60.0
	desc_label.offset_bottom = 110.0
	bg.add_child(desc_label)

	# 最高分（1.6 存档系统完成前显示占位）
	var score_label := Label.new()
	score_label.text = "最高分: ---"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 16)
	score_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	score_label.anchor_left = 0.0
	score_label.anchor_right = 1.0
	score_label.anchor_top = 0.0
	score_label.offset_top = 140.0
	score_label.offset_bottom = 170.0
	bg.add_child(score_label)

	# 最长时间（1.6 存档系统完成前显示占位）
	var time_label := Label.new()
	time_label.text = "最长时间: ---"
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 16)
	time_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	time_label.anchor_left = 0.0
	time_label.anchor_right = 1.0
	time_label.anchor_top = 0.0
	time_label.offset_top = 175.0
	time_label.offset_bottom = 205.0
	bg.add_child(time_label)

	# 选择按钮
	var select_btn := Button.new()
	select_btn.text = "选择此关"
	select_btn.add_theme_font_size_override("font_size", 18)
	select_btn.anchor_left = 0.25
	select_btn.anchor_right = 0.75
	select_btn.anchor_top = 0.0
	select_btn.offset_top = 240.0
	select_btn.offset_bottom = 278.0
	select_btn.pressed.connect(_on_level_selected.bind(data.id))
	bg.add_child(select_btn)


func _on_level_selected(level_id: String) -> void:
	level_selected.emit(level_id)


func _on_back() -> void:
	back_requested.emit()

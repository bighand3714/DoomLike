# ==============================================================================
# LevelUpPanel — 三选一升级选择面板
# ==============================================================================
# 升级暂停时显示，包含标题、3 个技能卡按钮。
# 鼠标点击或键盘 1/2/3 选择后发出 upgrade_chosen(index) 信号。
# process_mode = ALWAYS 保证暂停时可交互。
# ==============================================================================

class_name LevelUpPanel extends CanvasLayer

signal upgrade_chosen(index: int)


# ==============================================================================
# 内部引用
# ==============================================================================

var _options: Array = []
var _cards: Array[Button] = []
var _title: Label


# ==============================================================================
# _ready()
# ==============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_ui()
	hide()


# ==============================================================================
# _create_ui() — 构建面板
# ==============================================================================

func _create_ui() -> void:
	# 半透明黑底
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 标题
	_title = Label.new()
	_title.text = "升级！选择一项能力"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_title.anchor_left = 0.5
	_title.anchor_right = 0.5
	_title.offset_left = -300.0
	_title.offset_right = 300.0
	_title.offset_top = 50.0
	_title.offset_bottom = 90.0
	add_child(_title)

	# 3 张卡片按钮
	var card_width := 200.0
	var card_height := 260.0
	var total_width := card_width * 3 + 40.0 * 2  # 3 张卡片 + 2 个间距
	var start_x := -total_width / 2.0

	for i in range(3):
		var card := Button.new()
		card.name = "Card_%d" % i
		card.anchor_left = 0.5
		card.anchor_top = 0.5
		card.offset_left = start_x + float(i) * (card_width + 40.0)
		card.offset_right = card.offset_left + card_width
		card.offset_top = -80.0
		card.offset_bottom = card.offset_top + card_height
		card.pressed.connect(_on_card_pressed.bind(i))

		# 文字换行 + 居中
		card.add_theme_font_size_override("font_size", 14)
		card.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		add_child(card)
		_cards.append(card)


# ==============================================================================
# _input(event) — 键盘 1/2/3 选择
# ==============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("weapon_1"):
		_on_card_pressed(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("weapon_2"):
		_on_card_pressed(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("weapon_3"):
		_on_card_pressed(2)
		get_viewport().set_input_as_handled()


# ==============================================================================
# show_options(level, options) — 显示升级选项
# ==============================================================================

func show_options(level: int, options: Array) -> void:
	_options = options
	_title.text = "升级！选择一项能力（Lv.%d）" % level

	for i in range(3):
		if i < options.size() and options[i] != null:
			var upg: UpgradeData = options[i]
			var lv_text := ""
			if upg.max_level > 1:
				lv_text = " [%d/%d]" % [1, upg.max_level]  # 简化：显示 1/max
			_cards[i].text = "%s\n\n%s\n%s" % [upg.display_name, upg.description, lv_text]
			_cards[i].disabled = false
			_cards[i].show()
		else:
			_cards[i].hide()

	show()


# ==============================================================================
# hide_panel() — 隐藏面板
# ==============================================================================

func hide_panel() -> void:
	hide()
	_options.clear()


# ==============================================================================
# _on_card_pressed(index) — 卡片点击
# ==============================================================================

func _on_card_pressed(index: int) -> void:
	if index < 0 or index >= _options.size():
		return
	if _options[index] == null:
		return
	upgrade_chosen.emit(index)

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

		card.add_theme_font_size_override("font_size", 14)
		card.add_theme_color_override("font_color", Color.WHITE)
		card.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.3))
		card.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.alignment = HORIZONTAL_ALIGNMENT_CENTER

		var card_bg := StyleBoxFlat.new()
		card_bg.bg_color = Color(0.15, 0.15, 0.2, 0.9)
		card_bg.border_width_left = 2
		card_bg.border_width_right = 2
		card_bg.border_width_top = 2
		card_bg.border_width_bottom = 2
		card_bg.border_color = Color(0.5, 0.5, 0.6)
		card_bg.corner_radius_top_left = 8
		card_bg.corner_radius_top_right = 8
		card_bg.corner_radius_bottom_left = 8
		card_bg.corner_radius_bottom_right = 8
		card.add_theme_stylebox_override("normal", card_bg)
		var hover_bg := card_bg.duplicate()
		hover_bg.bg_color = Color(0.25, 0.25, 0.3, 0.9)
		hover_bg.border_color = Color(1.0, 0.85, 0.3)
		card.add_theme_stylebox_override("hover", hover_bg)

		add_child(card)
		_cards.append(card)


# ==============================================================================
# _input(event) — 键盘 1/2/3 选择
# ==============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return
	# 键盘快捷键 1/2/3 选卡（限制 Keyboard 事件，避免手柄 D-pad 误触）
	if event is InputEventKey and not event.echo:
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
				var current_lv: int = 0
				if GameBus.player_progression != null:
					current_lv = GameBus.player_progression.selected_levels.get(upg.upgrade_id, 0)
				var next_lv := current_lv + 1
				lv_text = " [%d/%d]" % [next_lv, upg.max_level]
			_cards[i].text = "%s\n\n%s\n%s" % [upg.display_name, upg.description, lv_text]
			_cards[i].disabled = false
			_cards[i].show()
		else:
			_cards[i].hide()

	# 为所有可见卡片设置焦点邻居，让手柄十字键/摇杆可以左右切换
	var first_visible: int = -1
	for j in range(_cards.size()):
		if _cards[j].visible:
			if first_visible == -1:
				first_visible = j
			if j + 1 < _cards.size() and _cards[j + 1].visible:
				_cards[j].focus_neighbor_right = _cards[j + 1].get_path()
				_cards[j + 1].focus_neighbor_left = _cards[j].get_path()
	if first_visible >= 0:
		_cards[first_visible].grab_focus()
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

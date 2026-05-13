# ==============================================================================
# PlayerStatus — 玩家状态 HUD + 生命条 + 护甲 + 武器栏位 + 拾取通知
# ==============================================================================
extends Node

const EnemyManagerClass = preload("res://scripts/enemy/enemy_manager.gd")

@export var update_interval: float = 0.1

@onready var _player: CharacterBody3D = %Player
@onready var _enemy_manager: Node = %EnemyManager

var _weapon_manager: WeaponManager
var _current_weapon: WeaponNode = null
var _player_dmg: Damageable

# Label 引用
var _position_label: Label
var _state_label: Label
var _health_bar_bg: ColorRect
var _health_bar_fill: ColorRect
var _health_label: Label
var _armor_label: Label
var _kills_label: Label
var _weapon_label: Label
var _ammo_label: Label
var _reload_label: Label
var _weapon_slots_label: Label
var _pickup_notify: Label

var _update_timer: float = 0.0
var _kill_count: int = 0
var _notify_timer: float = 0.0

const BAR_W := 200.0
const BAR_H := 12.0
const RIGHT_MARGIN := 12.0
const LABEL_W := 280.0

func _ready() -> void:
	_create_labels()
	call_deferred("_connect_signals")
	call_deferred("_connect_enemy_manager")


# ==============================================================================
# _create_labels()
# ==============================================================================
func _create_labels() -> void:
	# 位置 y=12
	_position_label = _make_label(12.0, 14, Color.WHITE, 0.9)

	# 状态 y=36
	_state_label = _make_label(36.0, 14, Color(0.7, 0.7, 0.7), 0.85)

	# 生命条背景 y=56, 生命条填充 y=56
	_health_bar_bg = _make_rect(56.0, BAR_W, BAR_H, Color(0.15, 0.15, 0.15, 0.8))
	_health_bar_fill = _make_rect(56.0, BAR_W, BAR_H, Color(0.2, 1.0, 0.2, 0.8))

	# 生命文字 y=56（覆盖在生命条上方）
	_health_label = _make_label(56.0, 14, Color.WHITE, 1.0)

	# 护甲 y=72
	_armor_label = _make_label(72.0, 14, Color(0.4, 0.7, 1.0), 0.9)

	# 击杀数 y=94
	_kills_label = _make_label(94.0, 14, Color(1.0, 0.85, 0.3), 0.9)

	# 武器名 y=122
	_weapon_label = _make_label(122.0, 15, Color(0.75, 0.75, 0.75), 0.85)

	# 弹药 y=142
	_ammo_label = _make_label(142.0, 22, Color.WHITE, 0.9)

	# 换弹提示 y=168
	_reload_label = _make_label(168.0, 14, Color(1.0, 0.7, 0.0), 1.0)
	_reload_label.hide()

	# 武器栏位 y=188
	_weapon_slots_label = _make_label(188.0, 13, Color(0.6, 0.6, 0.6), 0.8)

	# 拾取通知（屏幕中上，居中）
	_pickup_notify = Label.new()
	_pickup_notify.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pickup_notify.add_theme_font_size_override("font_size", 20)
	_pickup_notify.add_theme_color_override("font_color", Color.WHITE)
	_pickup_notify.anchor_left = 0.5
	_pickup_notify.anchor_right = 0.5
	_pickup_notify.anchor_top = 0.0
	_pickup_notify.offset_left = -150.0
	_pickup_notify.offset_right = 150.0
	_pickup_notify.offset_top = 80.0
	_pickup_notify.offset_bottom = 108.0
	_pickup_notify.hide()
	add_child(_pickup_notify)


# ==============================================================================
# _make_label(top, font_size, color, alpha)
# ==============================================================================
func _make_label(top_offset: float, font_size: int, color: Color, alpha: float) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", Color(color.r, color.g, color.b, alpha))
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.anchor_left = 1.0
	label.anchor_right = 1.0
	label.anchor_top = 0.0
	label.anchor_bottom = 0.0
	label.offset_left = -(LABEL_W + RIGHT_MARGIN)
	label.offset_right = -RIGHT_MARGIN
	label.offset_top = top_offset
	label.offset_bottom = top_offset + font_size + 6.0
	add_child(label)
	return label


# ==============================================================================
# _make_rect(top, w, h, color)
# ==============================================================================
func _make_rect(top_offset: float, w: float, h: float, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.anchor_left = 1.0
	rect.anchor_right = 1.0
	rect.anchor_top = 0.0
	rect.anchor_bottom = 0.0
	rect.offset_left = -(w + RIGHT_MARGIN)
	rect.offset_right = -RIGHT_MARGIN
	rect.offset_top = top_offset
	rect.offset_bottom = top_offset + h
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


# ==============================================================================
# _connect_signals / _connect_enemy_manager
# ==============================================================================
func _connect_signals() -> void:
	_weapon_manager = _player.find_child("WeaponManager", true, false) as WeaponManager
	if _weapon_manager == null:
		return
	if not _weapon_manager.weapon_changed.is_connected(_on_weapon_changed):
		_weapon_manager.weapon_changed.connect(_on_weapon_changed)
	var weapon := _weapon_manager.get_current_weapon()
	if weapon != null:
		_on_weapon_changed(weapon.weapon_data.weapon_name, weapon.weapon_data.slot_index)


func _connect_enemy_manager() -> void:
	if _enemy_manager == null:
		return
	_enemy_manager.connect("enemy_killed", _on_enemy_killed)
	_player_dmg = _player.get_node_or_null("Damageable") as Damageable
	# 连接护甲变化信号
	if _player_dmg != null and not _player_dmg.armor_changed.is_connected(_on_armor_changed):
		_player_dmg.armor_changed.connect(_on_armor_changed)


# ==============================================================================
# _process(delta)
# ==============================================================================
func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer < update_interval:
		# 但仍需处理通知倒计时
		if _notify_timer > 0.0:
			_notify_timer -= delta
			if _notify_timer <= 0.0:
				_pickup_notify.hide()
		return
	_update_timer = 0.0

	var pos := _player.global_position
	_position_label.text = "位置: %.1f  %.1f  %.1f" % [pos.x, pos.y, pos.z]
	_state_label.text = _get_state_text()

	if _player_dmg != null:
		var hp := _player_dmg.health
		var max_hp := _player_dmg.max_health
		var ratio := hp / max_hp
		_health_label.text = "生命: %.0f / %.0f" % [hp, max_hp]
		_health_bar_fill.offset_right = -(RIGHT_MARGIN + BAR_W * (1.0 - ratio))

		# 颜色：绿→橙→红
		var bar_color: Color
		if ratio > 0.7:
			bar_color = Color(0.2, 0.9, 0.2, 0.9)
		elif ratio > 0.3:
			bar_color = Color(1.0, 0.65, 0.1, 0.9)
		else:
			bar_color = Color(1.0, 0.15, 0.15, 1.0)
			# 低血闪烁
			if fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.0:
				bar_color.a = 0.4
		_health_bar_fill.color = bar_color

		_armor_label.text = "护甲: %.0f / %.0f" % [_player_dmg.armor, _player_dmg.max_armor]

	# 武器栏位
	_update_weapon_slots()

	# 通知倒计时
	if _notify_timer > 0.0:
		_notify_timer -= delta
		if _notify_timer <= 0.0:
			_pickup_notify.hide()


# ==============================================================================
# _get_state_text()
# ==============================================================================
func _get_state_text() -> String:
	var parts: Array[String] = []
	if _player.is_on_floor():
		parts.append("地面")
	else:
		if _player.velocity.y > 0.5:
			parts.append("上升")
		elif _player.velocity.y < -0.5:
			parts.append("下落")
		else:
			parts.append("空中")
	var h_speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	parts.append("移动中" if h_speed > 0.3 else "静止")
	return "  ".join(parts)


# ==============================================================================
# _update_weapon_slots() — 武器栏位指示器
# ==============================================================================
func _update_weapon_slots() -> void:
	if _weapon_manager == null:
		return
	var slots_text := ""
	var weapons := _weapon_manager._weapons
	for i in range(weapons.size()):
		var w := weapons[i] as WeaponNode
		if w == null or w.weapon_data == null:
			continue
		if i == _weapon_manager._current_index:
			slots_text += "[%d] %s  " % [i + 1, w.weapon_data.weapon_name]
		else:
			slots_text += " %d  %s  " % [i + 1, w.weapon_data.weapon_name]
	_weapon_slots_label.text = slots_text


# ==============================================================================
# show_notification(text, color) — 拾取通知
# ==============================================================================
func show_notification(text: String, color: Color) -> void:
	_pickup_notify.text = text
	_pickup_notify.add_theme_color_override("font_color", color)
	_pickup_notify.modulate = Color.WHITE
	_pickup_notify.show()
	_notify_timer = 1.5


# ==============================================================================
# 信号回调
# ==============================================================================
func _on_enemy_killed(enemy_name: String) -> void:
	_kill_count += 1
	_kills_label.text = "击杀: %d  (%s)" % [_kill_count, enemy_name]


func _on_armor_changed(_current: float, _max_val: float) -> void:
	pass  # _process 中每 0.1s 已更新显示


func _on_weapon_changed(weapon_name: String, _slot_index: int) -> void:
	if _current_weapon != null:
		if _current_weapon.ammo_changed.is_connected(_on_ammo_changed):
			_current_weapon.ammo_changed.disconnect(_on_ammo_changed)
		if _current_weapon.reload_started.is_connected(_on_reload_started):
			_current_weapon.reload_started.disconnect(_on_reload_started)
		if _current_weapon.reload_finished.is_connected(_on_reload_finished):
			_current_weapon.reload_finished.disconnect(_on_reload_finished)

	_current_weapon = _weapon_manager.get_current_weapon()
	if _current_weapon != null:
		_current_weapon.ammo_changed.connect(_on_ammo_changed)
		_current_weapon.reload_started.connect(_on_reload_started)
		_current_weapon.reload_finished.connect(_on_reload_finished)

	_weapon_label.text = weapon_name
	if _current_weapon != null:
		_on_ammo_changed(_current_weapon._current_mag, _current_weapon._current_reserve)


func _on_ammo_changed(current_mag: int, reserve: int) -> void:
	_ammo_label.text = "%d / %d" % [current_mag, reserve]


func _on_reload_started(_reload_time: float) -> void:
	_reload_label.text = "换弹中..."
	_reload_label.show()


func _on_reload_finished() -> void:
	_reload_label.hide()

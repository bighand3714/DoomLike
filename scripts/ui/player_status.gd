# ==============================================================================
# PlayerStatus — 玩家状态 HUD
# ==============================================================================
# 布局：
#   左上角：分数  击杀  时间（一行）
#   正上方居中：血量条（加粗）+ 生命值数字在条下方
#   右上角：小地图（由 main.gd 独立放置）
#   小地图下方：位置 → 状态 → 护甲 → 武器 → 弹药 → 换弹 → 换弹进度条 → 武器槽
#   屏幕中央：拾取通知 / 边界警告 / 抓取状态 / 盾牌 / 波次
# ==============================================================================

extends Control

const EnemyManagerClass = preload("res://scripts/enemy/enemy_manager.gd")

@export var update_interval: float = 0.1

@onready var _player: CharacterBody3D = %Player
@onready var _enemy_manager: Node = %EnemyManager

var _weapon_manager: WeaponManager
var _current_weapon: WeaponNode = null
var _player_dmg: Damageable

# 居中血条
var _center_health_bg: ColorRect
var _center_health_fill: ColorRect
var _center_health_label: Label

# 左上角（FPS 下方，纵向排列）
var _score_label: Label
var _kills_label: Label
var _time_label: Label
var _intensity_label: Label

# 右上角（小地图下方）
var _position_label: Label
var _state_label: Label
var _armor_label: Label
var _weapon_label: Label
var _ammo_label: Label
var _reload_label: Label
var _reload_bar_bg: ColorRect
var _reload_bar_fill: ColorRect
var _reload_elapsed: float = 0.0
var _reload_duration: float = 0.0
var _weapon_slots_label: Label

# 中央
var _pickup_notify: Label
var _boundary_warning: Label
var _grab_status_label: Label
var _shield_block_label: Label
var _wave_notify_label: Label

var _update_timer: float = 0.0
var _kill_count: int = 0
var _current_intensity: int = 1
var _notify_timer: float = 0.0
var _boundary_warning_timer: float = 0.0
var _shield_block_timer: float = 0.0
var _wave_notify_timer: float = 0.0

const BAR_W := 300.0
const BAR_H := 20.0
const RIGHT_MARGIN := 12.0
const LABEL_W := 260.0
# 小地图在右上角约 153px 高（150 + 3 margin），下面 UI 从这里开始
const RIGHT_TOP_OFFSET := 170.0
const RELOAD_BAR_W := 120.0
const RELOAD_BAR_H := 6.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_create_labels()
	call_deferred("_connect_signals")
	call_deferred("_connect_enemy_manager")


# ==============================================================================
# _create_labels()
# ==============================================================================
func _create_labels() -> void:
	# --- 左上角：FPS 下方纵向排列 ---
	var left_y := 36.0
	_score_label = _make_left_label(left_y, 16, Color(1.0, 0.85, 0.3))
	left_y += 22
	_kills_label = _make_left_label(left_y, 14, Color(1.0, 0.85, 0.3))
	left_y += 22
	_time_label = _make_left_label(left_y, 14, Color(0.85, 0.85, 0.85))
	left_y += 22
	_intensity_label = _make_left_label(left_y, 14, Color(0.9, 0.5, 0.3))
	_intensity_label.text = "强度: %d" % _current_intensity

	# --- 正上方居中：血条 ---
	_center_health_bg = ColorRect.new()
	_center_health_bg.color = Color(0.1, 0.1, 0.1, 0.85)
	_center_health_bg.anchor_left = 0.5
	_center_health_bg.anchor_right = 0.5
	_center_health_bg.anchor_top = 0.0
	_center_health_bg.anchor_bottom = 0.0
	_center_health_bg.offset_left = -BAR_W / 2.0
	_center_health_bg.offset_right = BAR_W / 2.0
	_center_health_bg.offset_top = 14.0
	_center_health_bg.offset_bottom = 14.0 + BAR_H
	_center_health_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center_health_bg)

	_center_health_fill = ColorRect.new()
	_center_health_fill.color = Color(0.2, 0.9, 0.2, 0.9)
	_center_health_fill.anchor_left = 0.5
	_center_health_fill.anchor_right = 0.5
	_center_health_fill.anchor_top = 0.0
	_center_health_fill.anchor_bottom = 0.0
	_center_health_fill.offset_left = -BAR_W / 2.0
	_center_health_fill.offset_right = BAR_W / 2.0
	_center_health_fill.offset_top = 14.0
	_center_health_fill.offset_bottom = 14.0 + BAR_H
	_center_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center_health_fill)

	_center_health_label = Label.new()
	_center_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_health_label.add_theme_font_size_override("font_size", 16)
	_center_health_label.add_theme_color_override("font_color", Color.WHITE)
	_center_health_label.anchor_left = 0.5
	_center_health_label.anchor_right = 0.5
	_center_health_label.anchor_top = 0.0
	_center_health_label.anchor_bottom = 0.0
	_center_health_label.offset_left = -100.0
	_center_health_label.offset_right = 100.0
	_center_health_label.offset_top = 14.0 + BAR_H + 4.0
	_center_health_label.offset_bottom = 14.0 + BAR_H + 24.0
	add_child(_center_health_label)

	# --- 右上角：小地图下方 ---
	var y := RIGHT_TOP_OFFSET

	_position_label = _make_label(y, 14, Color.WHITE, 0.9)
	y += 22

	_state_label = _make_label(y, 14, Color(0.7, 0.7, 0.7), 0.85)
	y += 22

	_armor_label = _make_label(y, 14, Color(0.4, 0.7, 1.0), 0.9)
	y += 28

	_weapon_label = _make_label(y, 15, Color(0.75, 0.75, 0.75), 0.85)
	y += 22

	_ammo_label = _make_label(y, 22, Color.WHITE, 0.9)
	y += 28

	_reload_label = _make_label(y, 14, Color(1.0, 0.7, 0.0), 1.0)
	_reload_label.hide()
	y += 22

	# 换弹进度条（小横条，在"换弹中…"下方）
	_reload_bar_bg = ColorRect.new()
	_reload_bar_bg.color = Color(0.1, 0.1, 0.1, 0.8)
	_reload_bar_bg.anchor_left = 1.0
	_reload_bar_bg.anchor_right = 1.0
	_reload_bar_bg.anchor_top = 0.0
	_reload_bar_bg.anchor_bottom = 0.0
	_reload_bar_bg.offset_left = -(RELOAD_BAR_W + RIGHT_MARGIN)
	_reload_bar_bg.offset_right = -RIGHT_MARGIN
	_reload_bar_bg.offset_top = y
	_reload_bar_bg.offset_bottom = y + RELOAD_BAR_H
	_reload_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reload_bar_bg.hide()
	add_child(_reload_bar_bg)

	_reload_bar_fill = ColorRect.new()
	_reload_bar_fill.color = Color(1.0, 0.7, 0.0, 0.9)
	_reload_bar_fill.anchor_left = 1.0
	_reload_bar_fill.anchor_right = 1.0
	_reload_bar_fill.anchor_top = 0.0
	_reload_bar_fill.anchor_bottom = 0.0
	_reload_bar_fill.offset_left = -(RELOAD_BAR_W + RIGHT_MARGIN)
	_reload_bar_fill.offset_right = -RIGHT_MARGIN
	_reload_bar_fill.offset_top = y
	_reload_bar_fill.offset_bottom = y + RELOAD_BAR_H
	_reload_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reload_bar_fill.hide()
	add_child(_reload_bar_fill)
	y += RELOAD_BAR_H + 6

	_weapon_slots_label = _make_label(y, 13, Color(0.6, 0.6, 0.6), 0.8)

	# --- 中央提示 ---
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

	_boundary_warning = Label.new()
	_boundary_warning.text = "已到达边界"
	_boundary_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boundary_warning.add_theme_font_size_override("font_size", 22)
	_boundary_warning.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1))
	_boundary_warning.anchor_left = 0.5
	_boundary_warning.anchor_right = 0.5
	_boundary_warning.anchor_top = 0.0
	_boundary_warning.offset_left = -160.0
	_boundary_warning.offset_right = 160.0
	_boundary_warning.offset_top = 140.0
	_boundary_warning.offset_bottom = 168.0
	_boundary_warning.hide()
	add_child(_boundary_warning)

	_grab_status_label = Label.new()
	_grab_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grab_status_label.add_theme_font_size_override("font_size", 18)
	_grab_status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	_grab_status_label.anchor_left = 0.5
	_grab_status_label.anchor_right = 0.5
	_grab_status_label.anchor_top = 0.0
	_grab_status_label.offset_left = -180.0
	_grab_status_label.offset_right = 180.0
	_grab_status_label.offset_top = 180.0
	_grab_status_label.offset_bottom = 206.0
	_grab_status_label.hide()
	add_child(_grab_status_label)

	_shield_block_label = Label.new()
	_shield_block_label.text = "盾牌抵挡!"
	_shield_block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shield_block_label.add_theme_font_size_override("font_size", 20)
	_shield_block_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	_shield_block_label.anchor_left = 0.5
	_shield_block_label.anchor_right = 0.5
	_shield_block_label.anchor_top = 0.0
	_shield_block_label.offset_left = -150.0
	_shield_block_label.offset_right = 150.0
	_shield_block_label.offset_top = 110.0
	_shield_block_label.offset_bottom = 136.0
	_shield_block_label.hide()

	_wave_notify_label = Label.new()
	_wave_notify_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_notify_label.add_theme_font_size_override("font_size", 36)
	_wave_notify_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_wave_notify_label.anchor_left = 0.5
	_wave_notify_label.anchor_right = 0.5
	_wave_notify_label.anchor_top = 0.5
	_wave_notify_label.offset_left = -200.0
	_wave_notify_label.offset_right = 200.0
	_wave_notify_label.offset_top = -40.0
	_wave_notify_label.offset_bottom = 10.0
	_wave_notify_label.hide()
	add_child(_wave_notify_label)
	add_child(_shield_block_label)


# ==============================================================================
# _make_label(top, font_size, color, alpha) — 右上角标签（右对齐）
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
# _make_left_label(top, font_size, color) — 左上角标签（左对齐）
# ==============================================================================
func _make_left_label(top_offset: float, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.anchor_left = 0.0
	label.anchor_right = 0.0
	label.anchor_top = 0.0
	label.anchor_bottom = 0.0
	label.offset_left = 12.0
	label.offset_right = 400.0
	label.offset_top = top_offset
	label.offset_bottom = top_offset + font_size + 6.0
	add_child(label)
	return label


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
	if _player_dmg != null and not _player_dmg.armor_changed.is_connected(_on_armor_changed):
		_player_dmg.armor_changed.connect(_on_armor_changed)


# ==============================================================================
# _process(delta)
# ==============================================================================
func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer < update_interval:
		# 快速通道：每帧处理独立倒计时
		if _notify_timer > 0.0:
			_notify_timer -= delta
			if _notify_timer <= 0.0:
				_pickup_notify.hide()
		if _boundary_warning_timer > 0.0:
			_boundary_warning_timer -= delta
			if _boundary_warning_timer <= 0.0:
				_boundary_warning.hide()
		if _wave_notify_timer > 0.0:
			_wave_notify_timer -= delta
			if _wave_notify_timer <= 0.0:
				_wave_notify_label.hide()
			elif _wave_notify_timer < 0.5:
				_wave_notify_label.modulate.a = _wave_notify_timer / 0.5
		if _shield_block_timer > 0.0:
			_shield_block_timer -= delta
			if _shield_block_timer <= 0.0:
				_shield_block_label.hide()
		# 换弹进度条
		if _reload_duration > 0.0:
			_reload_elapsed += delta
			var ratio: float = clampf(_reload_elapsed / _reload_duration, 0.0, 1.0)
			var fill_right: float = -RIGHT_MARGIN - RELOAD_BAR_W * (1.0 - ratio)
			_reload_bar_fill.offset_right = fill_right
		return
	_update_timer = 0.0

	var pos := _player.global_position
	_position_label.text = "位置: %.1f  %.1f  %.1f" % [pos.x, pos.y, pos.z]
	_state_label.text = _get_state_text()

	if _player_dmg != null:
		var hp := _player_dmg.health
		var max_hp := _player_dmg.max_health
		var ratio: float = hp / max_hp

		# 居中血条
		_center_health_fill.offset_right = BAR_W / 2.0 - BAR_W * (1.0 - ratio)
		_center_health_label.text = "%.0f / %.0f" % [hp, max_hp]

		var bar_color: Color
		if ratio > 0.7:
			bar_color = Color(0.2, 0.9, 0.2, 0.9)
		elif ratio > 0.3:
			bar_color = Color(1.0, 0.65, 0.1, 0.9)
		else:
			bar_color = Color(1.0, 0.15, 0.15, 1.0)
			if fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.0:
				bar_color.a = 0.4
		_center_health_fill.color = bar_color

		_armor_label.text = "护甲: %.0f / %.0f" % [_player_dmg.armor, _player_dmg.max_armor]

	_update_top_left()
	_update_weapon_slots()

	if _notify_timer > 0.0:
		_notify_timer -= delta
		if _notify_timer <= 0.0:
			_pickup_notify.hide()


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


func _update_top_left() -> void:
	if GameBus.run_stats == null:
		_score_label.text = ""
		_kills_label.text = ""
		_time_label.text = ""
		_intensity_label.text = ""
		return
	var stats = GameBus.run_stats
	_score_label.text = "分数: %d" % stats.score
	_kills_label.text = "击杀: %d" % _kill_count
	_time_label.text = "时间: %.1f" % stats.survival_time
	_intensity_label.text = "强度: %d" % _current_intensity


func _update_weapon_slots() -> void:
	if _weapon_manager == null:
		return
	var slots_text := ""
	var count := _weapon_manager.get_weapon_count()
	var current_idx := _weapon_manager.get_current_index()
	for i in range(count):
		var w := _weapon_manager.get_weapon_at(i)
		if w == null or w.weapon_data == null:
			continue
		if i == current_idx:
			slots_text += "[%d] %s  " % [i + 1, w.weapon_data.weapon_name]
		else:
			slots_text += " %d  %s  " % [i + 1, w.weapon_data.weapon_name]
	_weapon_slots_label.text = slots_text


# ==============================================================================
# show_notification(text, color)
# ==============================================================================
func show_notification(text: String, color: Color) -> void:
	_pickup_notify.text = text
	_pickup_notify.add_theme_color_override("font_color", color)
	_pickup_notify.modulate = Color.WHITE
	_pickup_notify.show()
	_notify_timer = 1.5


func show_boundary_warning() -> void:
	_boundary_warning.show()
	_boundary_warning_timer = 1.5


func reset_kill_count() -> void:
	_kill_count = 0
	_current_intensity = 1


func update_intensity(new_intensity: int) -> void:
	_current_intensity = new_intensity


func show_grab_status(enemy_name: String) -> void:
	_grab_status_label.text = "抓取中: " + enemy_name + "  [R处决]"
	_grab_status_label.show()


func hide_grab_status() -> void:
	_grab_status_label.hide()


func show_shield_block() -> void:
	_shield_block_label.show()
	_shield_block_timer = 0.8


func show_wave_notification(wave_number: int) -> void:
	if _wave_notify_label == null:
		return
	_wave_notify_label.text = "第 %d 波" % wave_number
	_wave_notify_label.modulate = Color.WHITE
	_wave_notify_label.show()
	_wave_notify_timer = 2.0


# ==============================================================================
# 信号回调
# ==============================================================================
func _on_enemy_killed(enemy_name: String, _score_value: int) -> void:
	_kill_count += 1


func _on_armor_changed(_current: float, _max_val: float) -> void:
	pass


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
	# 切武器时重置换弹进度条
	_hide_reload_bar()
	if _current_weapon != null:
		_on_ammo_changed(_current_weapon.get_current_mag(), _current_weapon.get_current_reserve())


func _on_ammo_changed(current_mag: int, reserve: int) -> void:
	if _current_weapon != null and _current_weapon.weapon_data != null and _current_weapon.weapon_data.infinite_ammo:
		_ammo_label.text = "∞ / ∞"
	else:
		_ammo_label.text = "%d / %d" % [current_mag, reserve]


func _on_reload_started(reload_time: float) -> void:
	_reload_label.text = "换弹中..."
	_reload_label.show()
	_reload_elapsed = 0.0
	_reload_duration = reload_time
	_reload_bar_bg.show()
	_reload_bar_fill.show()
	# 重置 fill 为满宽
	_reload_bar_fill.offset_right = -RIGHT_MARGIN


func _on_reload_finished() -> void:
	_reload_label.hide()
	_hide_reload_bar()


func _hide_reload_bar() -> void:
	_reload_duration = 0.0
	_reload_elapsed = 0.0
	_reload_bar_bg.hide()
	_reload_bar_fill.hide()

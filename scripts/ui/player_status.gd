# ==============================================================================
# PlayerStatus — 玩家状态 HUD 显示
# ==============================================================================
# 挂在 UI 节点下，在屏幕上显示：
#   右上角：位置坐标 → 动作状态 → 生命值 → 击杀数 → 分隔线 → 武器名 → 弹药 → 换弹
#
# 锚点策略：所有标签锚定右上角，从上到下排列
# ==============================================================================

extends Node

# 预加载依赖的类
const EnemyManagerClass = preload("res://scripts/enemy/enemy_manager.gd")

# ==============================================================================
# 导出属性
# ==============================================================================

@export var update_interval: float = 0.1


# ==============================================================================
# 节点引用
# ==============================================================================

@onready var _player: CharacterBody3D = %Player
@onready var _enemy_manager: Node = %EnemyManager
var _weapon_manager: WeaponManager
var _current_weapon: WeaponNode = null
var _player_dmg: Damageable


# ==============================================================================
# Label 引用
# ==============================================================================

var _position_label: Label
var _state_label: Label
var _health_label: Label
var _kills_label: Label
var _weapon_label: Label
var _ammo_label: Label
var _reload_label: Label

var _update_timer: float = 0.0
var _kill_count: int = 0


# ==============================================================================
# _ready()
# ==============================================================================

func _ready() -> void:
	_create_labels()
	call_deferred("_connect_signals")
	call_deferred("_connect_enemy_manager")


# ==============================================================================
# _create_labels() — 所有标签从上到下排列在右上角
# ==============================================================================
# 每个标签距上边缘的 offset 依次递增（12, 36, 60, 84, 112, 136, 162...）
func _create_labels() -> void:
	# --- 位置（y = 12）---
	_position_label = _make_top_right_label(12.0)
	_position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_position_label.add_theme_font_size_override("font_size", 14)

	# --- 状态（y = 36）---
	_state_label = _make_top_right_label(36.0)
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_state_label.add_theme_font_size_override("font_size", 14)
	_state_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.85))

	# --- 生命值（y = 60）---
	_health_label = _make_top_right_label(60.0)
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_health_label.add_theme_font_size_override("font_size", 15)
	_health_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 0.9))

	# --- 击杀数（y = 82）---
	_kills_label = _make_top_right_label(82.0)
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_kills_label.add_theme_font_size_override("font_size", 14)
	_kills_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 0.9))

	# --- 武器名（y = 110，下方留更大间距当分隔）---
	_weapon_label = _make_top_right_label(110.0)
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weapon_label.add_theme_font_size_override("font_size", 15)
	_weapon_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 0.85))

	# --- 弹药（y = 130）---
	_ammo_label = _make_top_right_label(130.0)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_label.add_theme_font_size_override("font_size", 22)

	# --- 换弹提示（y = 156）---
	_reload_label = _make_top_right_label(156.0)
	_reload_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_reload_label.add_theme_font_size_override("font_size", 14)
	_reload_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0, 1.0))
	_reload_label.hide()


# ==============================================================================
# _make_top_right_label(top_offset) — 创建锚定右上角的标签
# ==============================================================================
func _make_top_right_label(top_offset: float) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))

	# 左右锚定屏幕右边缘
	label.anchor_left = 1.0
	label.anchor_right = 1.0
	label.offset_left = -292.0
	label.offset_right = -12.0

	# 上下锚定屏幕上边缘
	label.anchor_top = 0.0
	label.anchor_bottom = 0.0
	label.offset_top = top_offset
	label.offset_bottom = top_offset + 24.0

	add_child(label)
	return label


# ==============================================================================
# _connect_signals() — 连接武器信号
# ==============================================================================

func _connect_signals() -> void:
	# WeaponManager 有 unique_name，直接引用
	_weapon_manager = _player.find_child("WeaponManager", true, false) as WeaponManager
	if _weapon_manager == null:
		return
	if not _weapon_manager.weapon_changed.is_connected(_on_weapon_changed):
		_weapon_manager.weapon_changed.connect(_on_weapon_changed)
	var weapon := _weapon_manager.get_current_weapon()
	if weapon != null:
		_on_weapon_changed(weapon.weapon_data.weapon_name, weapon.weapon_data.slot_index)


# ==============================================================================
# _connect_enemy_manager() — 连接击杀信号
# ==============================================================================

func _connect_enemy_manager() -> void:
	if _enemy_manager == null:
		return
	# 用字符串连接信号——因为 _enemy_manager 类型是 Node，编译器不知道它有 enemy_killed 信号
	_enemy_manager.connect("enemy_killed", _on_enemy_killed)

	# 获取玩家 Damageable
	_player_dmg = _player.get_node_or_null("Damageable") as Damageable


# ==============================================================================
# _process(delta) — 定时刷新
# ==============================================================================

func _process(delta: float) -> void:

	_update_timer += delta
	if _update_timer < update_interval:
		return
	_update_timer = 0.0

	var pos := _player.global_position
	_position_label.text = "位置: %.1f  %.1f  %.1f" % [pos.x, pos.y, pos.z]
	_state_label.text = _get_state_text()

	# 更新血量
	if _player_dmg != null:
		var hp := _player_dmg.health
		var max_hp := _player_dmg.max_health
		_health_label.text = "生命: %.0f / %.0f" % [hp, max_hp]
		# 血量低时变红
		if hp < max_hp * 0.3:
			_health_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
		else:
			_health_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 0.9))


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
	if h_speed > 0.3:
		parts.append("移动中")
	else:
		parts.append("静止")

	return "  ".join(parts)


# ==============================================================================
# _on_enemy_killed() — 击杀计数回调
# ==============================================================================

func _on_enemy_killed(enemy_name: String) -> void:
	_kill_count += 1
	_kills_label.text = "击杀: %d  (%s)" % [_kill_count, enemy_name]


# ==============================================================================
# 武器信号回调
# ==============================================================================

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

# ==============================================================================
# PlayerStatus — 玩家状态 HUD 显示
# ==============================================================================
# 挂在 UI 节点下，在屏幕上显示：
#   1. 右上角：位置坐标（白色） + 动作状态（灰色）
#   2. 右下角：武器名称 + 弹药数 + 换弹提示
#
# 锚点策略（简单可靠）：
#   右上角标签 → left/right 锚定屏幕右边，top/bottom 锚定屏幕上边
#   右下角标签 → left/right 锚定屏幕右边，top/bottom 锚定屏幕下边
#   这样 offset 就是"距离屏幕边缘的像素数"，不会跑偏。
# ==============================================================================

extends Node


# ==============================================================================
# 导出属性
# ==============================================================================

## 状态显示更新间隔（秒）
@export var update_interval: float = 0.1


# ==============================================================================
# 节点引用
# ==============================================================================

@onready var _player: CharacterBody3D = %Player
var _weapon_manager: WeaponManager
var _current_weapon: WeaponNode = null


# ==============================================================================
# Label 引用
# ==============================================================================

var _position_label: Label
var _state_label: Label
var _weapon_label: Label
var _ammo_label: Label
var _reload_label: Label

var _update_timer: float = 0.0


# ==============================================================================
# _ready()
# ==============================================================================

func _ready() -> void:
	_create_position_labels()
	_create_weapon_labels()
	call_deferred("_connect_signals")


# ==============================================================================
# _create_position_labels() — 右上角：位置 + 状态
# ==============================================================================
# 两个标签叠在右上角。因为左右锚定在屏幕右侧、上下锚定在屏幕上侧，
# offset 值 = 距离右边缘和上边缘的像素距离。
func _create_position_labels() -> void:
	# --- 位置标签 ---
	# 锚定方式：四个边都锚在同一角（右-右，上-上）
	# offset_left/offset_right = 相对右边缘的距离（负值 = 往左缩）
	# offset_top/offset_bottom = 相对上边缘的距离
	_position_label = _create_label_at_corner(
		CORNER_TOP_RIGHT,
		Vector2(280, 0),   # size（宽280，高自动）
		Vector2(12, 12)    # margin（距右边12px，距上边12px）
	)
	_position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_position_label.add_theme_font_size_override("font_size", 14)

	# --- 状态标签（位置下方 24px）---
	_state_label = _create_label_at_corner(
		CORNER_TOP_RIGHT,
		Vector2(280, 0),
		Vector2(12, 36)   # 距上边 36px（= 12 + 24）
	)
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_state_label.add_theme_font_size_override("font_size", 14)
	_state_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.85))


# ==============================================================================
# _create_weapon_labels() — 右上角武器信息：武器名 + 弹药 + 换弹提示
# ==============================================================================
# 放在位置/状态标签的下方。
# 布局（从上到下）：位置 → 状态 → 武器名 → 弹药 → 换弹提示（隐藏）
func _create_weapon_labels() -> void:
	# --- 武器名称（位置/状态下方，小字灰色）---
	_weapon_label = _create_label_at_corner(
		CORNER_TOP_RIGHT,
		Vector2(200, 0),
		Vector2(12, 64)
	)
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weapon_label.add_theme_font_size_override("font_size", 15)
	_weapon_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 0.85))

	# --- 弹药显示（武器名下方，大字白色）---
	_ammo_label = _create_label_at_corner(
		CORNER_TOP_RIGHT,
		Vector2(200, 0),
		Vector2(12, 84)
	)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_label.add_theme_font_size_override("font_size", 22)

	# --- 换弹提示（弹药下方，橙色，默认隐藏）---
	_reload_label = _create_label_at_corner(
		CORNER_TOP_RIGHT,
		Vector2(200, 0),
		Vector2(12, 110)
	)
	_reload_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_reload_label.add_theme_font_size_override("font_size", 14)
	_reload_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0, 1.0))
	_reload_label.hide()


# ==============================================================================
# 角枚举
# ==============================================================================

enum Corner {
	TOP_RIGHT,
	BOTTOM_RIGHT,
}


# ==============================================================================
# _create_label_at_corner() — 在指定屏幕角落创建一个锚定好的标签
# ==============================================================================
# 参数：
#   corner — 贴哪个角（TOP_RIGHT 或 BOTTOM_RIGHT）
#   size   — 标签的矩形大小（x=宽, y=高，y=0 表示高度自动）
#   margin — 距角落的像素距离（x=距右边, y=距上/下边）
#
# 原理：
#   对于右上角：anchor_left=1, anchor_right=1 → offset控制距右边缘距离
#               anchor_top=0, anchor_bottom=0 → offset控制距上边缘距离
#   对于右下角：anchor_left=1, anchor_right=1 → offset控制距右边缘距离
#               anchor_top=1, anchor_bottom=1 → offset控制距下边缘距离
func _create_label_at_corner(corner: Corner, size: Vector2, margin: Vector2) -> Label:
	var label := Label.new()

	# 文字默认白色半透明
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))

	# --- 锚定到屏幕右边缘 ---
	label.anchor_left = 1.0
	label.anchor_right = 1.0

	# offset_left 和 offset_right 都从右边缘开始算
	# 例如 size.x=280, margin.x=12:
	#   offset_right = -12（右边缘往左 12px）
	#   offset_left = -12 - 280 = -292（左边缘在右边缘往左 292px）
	label.offset_right = -margin.x
	label.offset_left = -(margin.x + size.x)

	# --- 锚定到屏幕上/下边缘 ---
	if corner == CORNER_TOP_RIGHT:
		# 贴屏幕上边
		label.anchor_top = 0.0
		label.anchor_bottom = 0.0
		label.offset_top = margin.y
		label.offset_bottom = margin.y + size.y
	else:
		# 贴屏幕下边
		label.anchor_top = 1.0
		label.anchor_bottom = 1.0
		label.offset_top = -(margin.y + size.y)
		label.offset_bottom = -margin.y

	add_child(label)
	return label


# ==============================================================================
# _connect_signals() — 连接武器信号
# ==============================================================================

func _connect_signals() -> void:
	_weapon_manager = _player.get_node("WeaponHolder/WeaponManager") as WeaponManager
	if _weapon_manager == null:
		push_error("PlayerStatus: 无法找到 WeaponManager")
		return

	if not _weapon_manager.weapon_changed.is_connected(_on_weapon_changed):
		_weapon_manager.weapon_changed.connect(_on_weapon_changed)

	# 手动触发一次，显示初始武器
	var weapon := _weapon_manager.get_current_weapon()
	if weapon != null:
		_on_weapon_changed(weapon.weapon_data.weapon_name, weapon.weapon_data.slot_index)


# ==============================================================================
# _process(delta) — 定时刷新位置和状态
# ==============================================================================

func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer < update_interval:
		return
	_update_timer = 0.0

	var pos := _player.global_position
	_position_label.text = "位置: %.1f  %.1f  %.1f" % [pos.x, pos.y, pos.z]
	_state_label.text = _get_state_text()


# ==============================================================================
# _get_state_text() — 玩家动作状态
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
# _on_weapon_changed() — 武器切换回调
# ==============================================================================

func _on_weapon_changed(weapon_name: String, _slot_index: int) -> void:
	# 断开旧武器信号
	if _current_weapon != null:
		if _current_weapon.ammo_changed.is_connected(_on_ammo_changed):
			_current_weapon.ammo_changed.disconnect(_on_ammo_changed)
		if _current_weapon.reload_started.is_connected(_on_reload_started):
			_current_weapon.reload_started.disconnect(_on_reload_started)
		if _current_weapon.reload_finished.is_connected(_on_reload_finished):
			_current_weapon.reload_finished.disconnect(_on_reload_finished)

	# 连接新武器信号
	_current_weapon = _weapon_manager.get_current_weapon()
	if _current_weapon != null:
		_current_weapon.ammo_changed.connect(_on_ammo_changed)
		_current_weapon.reload_started.connect(_on_reload_started)
		_current_weapon.reload_finished.connect(_on_reload_finished)

	_weapon_label.text = weapon_name

	if _current_weapon != null:
		_on_ammo_changed(_current_weapon._current_mag, _current_weapon._current_reserve)


# ==============================================================================
# 弹药 / 换弹回调
# ==============================================================================

func _on_ammo_changed(current_mag: int, reserve: int) -> void:
	_ammo_label.text = "%d / %d" % [current_mag, reserve]


func _on_reload_started(_reload_time: float) -> void:
	_reload_label.text = "换弹中..."
	_reload_label.show()


func _on_reload_finished() -> void:
	_reload_label.hide()

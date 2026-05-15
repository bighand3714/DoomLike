# ==============================================================================
# PlayerStatus — 玩家状态 HUD + 生命条 + 护甲 + 武器栏位 + 拾取通知 + 边界提示
# ==============================================================================
# 屏幕布局（Phase 1.8）：
#
#   左上角                         右上角
#   FPS  (由 fps_counter.gd)      位置: x  y  z
#   分数: 0                        地面  移动中
#   时间: 0.0                      ████████████████  (生命条)
#   强度: 1                        生命: 100 / 100
#                                   护甲: 0 / 100
#   屏幕中上                        击杀: 0  (小恶魔)
#   +30 弹药 (拾取通知)             手枪
#   已到达边界 (边界提示)           8 / 50
#                                  [1] 手枪  2  霰弹枪
#                                   换弹中...
# ==============================================================================

extends Control

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
var _score_label: Label
var _time_label: Label
var _intensity_label: Label
var _boundary_warning: Label

var _update_timer: float = 0.0
var _kill_count: int = 0
var _current_intensity: int = 1
var _notify_timer: float = 0.0
var _boundary_warning_timer: float = 0.0

var _grab_status_label: Label = null
var _shield_block_label: Label = null
var _shield_block_timer: float = 0.0

const BAR_W := 200.0
const BAR_H := 12.0
const RIGHT_MARGIN := 12.0
const LABEL_W := 280.0

func _ready() -> void:
	# 填满全屏——否则 Control 默认 0×0，子节点锚点全部塌缩到原点
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

	# 分数（左上角，FPS 下方 y=36）
	_score_label = _make_left_label(36.0, 16, Color(1.0, 0.85, 0.3))

	# 时间（左上角，分数下方 y=56）
	_time_label = _make_left_label(56.0, 14, Color(0.85, 0.85, 0.85))

	# 强度（左上角，时间下方 y=76），Phase 7 前固定显示 1
	_intensity_label = _make_left_label(76.0, 14, Color(0.9, 0.5, 0.3))
	_intensity_label.text = "强度: %d" % _current_intensity

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

	# 边界提示（屏幕中下，居中），默认隐藏，触碰边界时短暂显示
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

	# 抓取状态（屏幕中下偏上，居中），显示"抓取中: <敌人名> [R处决]"
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

	# 盾牌抵挡通知（屏幕中上，短暂闪现）
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
	label.offset_right = 200.0
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
		# 但仍需处理两个独立倒计时（不受 0.1s 刷新间隔限制）
		if _notify_timer > 0.0:
			_notify_timer -= delta
			if _notify_timer <= 0.0:
				_pickup_notify.hide()
		if _boundary_warning_timer > 0.0:
			_boundary_warning_timer -= delta
			if _boundary_warning_timer <= 0.0:
				_boundary_warning.hide()
		if _shield_block_timer > 0.0:
			_shield_block_timer -= delta
			if _shield_block_timer <= 0.0:
				_shield_block_label.hide()
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

	# 分数、时间和强度
	_update_score_and_time()

	# 武器栏位
	_update_weapon_slots()

	# 通知倒计时（fast path 中也有一份处理，这里是慢通道保险）
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
# _update_score_and_time() — 从 main.gd RunStats 读取分数/时间/强度并显示
# ==============================================================================
# 每 0.1 秒调用一次（由 _process 的 update_interval 控制）。
# 当 main 为 null 或没有 get_run_stats 方法时（即不在 PLAYING 状态），
# 清空所有数据显示——这样主菜单/选关/结算界面时左上角不会残留数字。
#
# 强度（intensity）说明：
#   表示当前的"刷怪难度等级"，数值越高刷怪越快、越强。
#   Phase 7 会接入 SpawnManager 的时间驱动刷新频率系统，
#   届时这里的 "1" 会被替换为实际的当前强度值。
func _update_score_and_time() -> void:
	if GameBus.run_stats == null:
		_score_label.text = ""
		_time_label.text = ""
		_intensity_label.text = ""
		return
	var stats = GameBus.run_stats
	_score_label.text = "分数: %d" % stats.score
	_time_label.text = "时间: %.1f" % stats.survival_time
	_intensity_label.text = "强度: %d" % _current_intensity


# ==============================================================================
# _update_weapon_slots() — 武器栏位指示器
# ==============================================================================
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
# show_notification(text, color) — 拾取通知
# ==============================================================================
# 在屏幕中上显示短文本（如"+30 弹药"），1.5 秒后自动淡出隐藏。
# 由 main.gd 的 show_pickup_notification() 转发调用。
func show_notification(text: String, color: Color) -> void:
	_pickup_notify.text = text
	_pickup_notify.add_theme_color_override("font_color", color)
	_pickup_notify.modulate = Color.WHITE
	_pickup_notify.show()
	_notify_timer = 1.5


# ==============================================================================
# show_boundary_warning() — 显示"已到达边界"警告（Phase 1.8 新增）
# ==============================================================================
# 当玩家试图走出圆形竞技场边界时，ArenaLevel 会发出
# boundary_warning_requested 信号，main.gd 转发到这个方法。
#
# 显示效果：
#   - 屏幕中下出现橙红色"已到达边界"大字（22号字体）
#   - 1.5 秒后自动消失
#   - 如果玩家一直顶在边界上持续触发，每次调用都会刷新 timer，
#     所以警告会一直显示直到玩家离开边界后 1.5 秒
#
# 为什么用 1.5 秒：
#   太短（0.3s）玩家可能还没注意到就消失了；
#   太长（3s+）会遮挡战斗视野。1.5 秒是一个折中值。
#
# 调用路径（Phase 2）：
#   ArenaLevel._physics_process() 检测越界
#     → boundary_warning_requested 信号
#     → main.gd 连接 → 调用 player_status.show_boundary_warning()
func show_boundary_warning() -> void:
	_boundary_warning.show()
	_boundary_warning_timer = 1.5


# ==============================================================================
# reset_kill_count() — 重置 HUD 击杀计数到 0（关卡重启时调用）
# ==============================================================================
# HUD 的击杀数有两个来源：
#   1. _kill_count —— HUD 自己维护的本地计数器
#   2. EnemyManager.total_kills —— 敌人管理器的全局统计
#
# 为什么需要两个独立的重置：
#   _kill_count 是 HUD 内部变量，通过 _on_enemy_killed() 信号递增。
#   EnemyManager.reset() 会把 total_kills 归零，但 HUD 的 _kill_count
#   不会自动同步——需要单独调用这个方法。
#
# 如果不重置会怎样：
#   上一局击杀了 5 个敌人，HUD 显示"击杀: 5"。
#   重启后 _kill_count 还是 5，新击杀会显示"击杀: 6"——明显不对。
#
# 方法做了什么：
#   - _kill_count = 0：归零本地计数
#   - _kills_label.text = "击杀: 0"：立即刷新标签显示
#     如果不手动刷新，标签要到下一次 _on_enemy_killed() 触发才会更新，
#     这期间的几秒内会显示旧数据。
#
# 调用时机（Phase 2+）：
#   - _start_level() 加载新关卡后
#   - 结算界面点击"重新开始"后
func reset_kill_count() -> void:
	_kill_count = 0
	_current_intensity = 1
	_kills_label.text = "击杀: 0"


# ==============================================================================
# update_intensity —— SpawnManager 调用，更新 HUD 强度显示
# ==============================================================================
func update_intensity(new_intensity: int) -> void:
	_current_intensity = new_intensity
	_intensity_label.text = "强度: %d" % _current_intensity


# 显示抓取状态（IronWhip 调用）
func show_grab_status(enemy_name: String) -> void:
	_grab_status_label.text = "抓取中: " + enemy_name + "  [R处决]"
	_grab_status_label.show()


# 隐藏抓取状态（IronWhip 调用）
func hide_grab_status() -> void:
	_grab_status_label.hide()


# 盾牌抵挡通知（敌人攻击被盾牌吸收时调用）
func show_shield_block() -> void:
	_shield_block_label.show()
	_shield_block_timer = 0.8


# ==============================================================================
# 信号回调
# ==============================================================================
func _on_enemy_killed(enemy_name: String, _score_value: int) -> void:
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
		_on_ammo_changed(_current_weapon.get_current_mag(), _current_weapon.get_current_reserve())


func _on_ammo_changed(current_mag: int, reserve: int) -> void:
	_ammo_label.text = "%d / %d" % [current_mag, reserve]


func _on_reload_started(_reload_time: float) -> void:
	_reload_label.text = "换弹中..."
	_reload_label.show()


func _on_reload_finished() -> void:
	_reload_label.hide()

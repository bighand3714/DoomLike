# ==============================================================================
# Main — 游戏主控制器
# ==============================================================================
# 挂在场景根节点（Main）上，负责：
#   1. 游戏状态机（BOOT → MAIN_MENU → LEVEL_SELECT → PLAYING / PAUSED / GAME_OVER）
#   2. 菜单创建与信号连接
#   3. 关卡初始化（CSG 碰撞 + 出生点）
#   4. 命中标记 + 受伤效果 + 拾取通知
# ==============================================================================

extends Node3D

const MainMenuClass = preload("res://scripts/ui/main_menu.gd")
const PauseMenuClass = preload("res://scripts/ui/pause_menu.gd")
const LevelSelectClass = preload("res://scripts/ui/level_select.gd")

@onready var _level_root: Node3D = %Level
@onready var _crosshair: ColorRect = %Crosshair
@onready var _damage_flash: ColorRect = %DamageFlash
@onready var _player: CharacterBody3D = %Player

var _main_menu: CanvasLayer
var _pause_menu: CanvasLayer
var _level_select: CanvasLayer
var _game_state: GameState.State = GameState.State.BOOT
var _current_level_id: String = ""
var _hit_marker_connected := false


# ==============================================================================
# _ready()
# ==============================================================================
func _ready() -> void:
	_setup_crosshair()

	# 菜单系统——挂在 UI 下
	var ui := get_node("UI")
	_main_menu = _create_main_menu()
	ui.add_child(_main_menu)
	_pause_menu = _create_pause_menu()
	ui.add_child(_pause_menu)
	_level_select = _create_level_select()
	ui.add_child(_level_select)

	# 信号连接
	_main_menu.start_requested.connect(_on_start_requested)
	_main_menu.quit_requested.connect(_on_quit_requested)
	_pause_menu.resumed.connect(_on_pause_resumed)
	_pause_menu.back_to_menu.connect(_on_back_to_menu)
	_level_select.level_selected.connect(_on_level_selected)
	_level_select.back_requested.connect(_on_level_select_back)

	# 启动流程：BOOT → MAIN_MENU
	_set_game_state(GameState.State.MAIN_MENU)


# ==============================================================================
# _set_game_state(next_state) — 游戏状态切换
# ==============================================================================
func _set_game_state(next_state: GameState.State) -> void:
	var prev := _game_state
	_game_state = next_state

	match _game_state:
		GameState.State.MAIN_MENU:
			_main_menu.show_menu()
			_level_select.hide()
			_pause_menu.hide()
			_hide_hud()
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		GameState.State.LEVEL_SELECT:
			_main_menu.hide()
			_level_select.show()
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		GameState.State.PLAYING:
			if prev != GameState.State.PAUSED:
				# 新游戏：初始化关卡
				_load_level()
				if not _hit_marker_connected:
					_connect_hit_marker()
			_main_menu.hide()
			_level_select.hide()
			_pause_menu.hide()
			_show_hud()
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

		GameState.State.PAUSED:
			_pause_menu.show_pause()
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		GameState.State.GAME_OVER:
			# 1.4 结算界面实现前，先回主菜单
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_hide_hud()
			_set_game_state(GameState.State.MAIN_MENU)


# ==============================================================================
# 菜单信号回调
# ==============================================================================

func _on_start_requested() -> void:
	_set_game_state(GameState.State.LEVEL_SELECT)

func _on_quit_requested() -> void:
	get_tree().quit()

func _on_pause_resumed() -> void:
	_set_game_state(GameState.State.PLAYING)

func _on_level_selected(level_id: String) -> void:
	_current_level_id = level_id
	_start_level(level_id)
	_set_game_state(GameState.State.PLAYING)

func _on_level_select_back() -> void:
	_set_game_state(GameState.State.MAIN_MENU)

func _on_back_to_menu() -> void:
	_set_game_state(GameState.State.MAIN_MENU)


# ==============================================================================
# _start_level(level_id) — 启动指定关卡
# ==============================================================================
# Phase 2 完成后替换为 ArenaLevel 加载流程。当前复用场景内已有关卡。
func _start_level(_level_id: String) -> void:
	# TODO: Phase 2 — 通过 LevelRegistry 加载对应 .tscn 并实例化到 CurrentLevelRoot
	# 目前使用场景中已搭建的 Level 节点
	pass


# ==============================================================================
# toggle_pause() — Esc 键切换暂停（由 player_controller 调用）
# ==============================================================================
func toggle_pause() -> void:
	match _game_state:
		GameState.State.PLAYING:
			_set_game_state(GameState.State.PAUSED)
		GameState.State.PAUSED:
			_set_game_state(GameState.State.PLAYING)


# ==============================================================================
# 菜单工厂方法
# ==============================================================================

func _create_main_menu() -> CanvasLayer:
	var menu := MainMenuClass.new()
	menu.name = "MainMenu"
	return menu

func _create_pause_menu() -> CanvasLayer:
	var menu := PauseMenuClass.new()
	menu.name = "PauseMenu"
	return menu

func _create_level_select() -> CanvasLayer:
	var menu := LevelSelectClass.new()
	menu.name = "LevelSelect"
	return menu


# ==============================================================================
# _show_hud() / _hide_hud() — HUD 显隐控制
# ==============================================================================

func _show_hud() -> void:
	var ps := get_node_or_null("UI/PlayerStatus")
	if ps != null:
		ps.visible = true
	_crosshair.visible = true
	var fps := get_node_or_null("UI/FPS")
	if fps != null:
		fps.visible = true

func _hide_hud() -> void:
	var ps := get_node_or_null("UI/PlayerStatus")
	if ps != null:
		ps.visible = false
	_crosshair.visible = false
	var fps := get_node_or_null("UI/FPS")
	if fps != null:
		fps.visible = false


# ==============================================================================
# _load_level() — 初始化关卡
# ==============================================================================
# 此方法只初始化场景内已有 Level 节点，不再视为 LevelData 加载管线。
# LevelData 加载管线（Phase 5）暂缓，新方向以 project_roadmap2.md 为准。
func _load_level() -> void:
	_enable_csg_collision(_level_root)

	for child in _level_root.get_children():
		if child.name == "PlayerStart" and child is Node3D:
			_player.global_position = child.global_position
			_player.rotation.y = child.global_rotation.y
			break

	var has_light := false
	for child in _level_root.get_children():
		if child is DirectionalLight3D or child is OmniLight3D:
			has_light = true
			break
	if not has_light:
		_add_global_lights()


# ==============================================================================
# _enable_csg_collision(node) — 只对 level_geometry group 或关卡几何命名前缀启用 CSG 碰撞
# ==============================================================================
func _enable_csg_collision(node: Node) -> void:
	for child in node.get_children():
		if child is CSGBox3D or child is CSGPolygon3D or child is CSGCombiner3D:
			if _is_level_geometry(child):
				child.use_collision = true
		_enable_csg_collision(child)


func _is_level_geometry(node: Node) -> bool:
	if node.is_in_group("level_geometry"):
		return true
	var n := node.name
	return n.begins_with("Ground_") or n.begins_with("Wall_") or n.begins_with("Boundary_")


# ==============================================================================
# _add_global_lights() — 添加默认灯光
# ==============================================================================
func _add_global_lights() -> void:
	var light := DirectionalLight3D.new()
	light.name = "GlobalDirectionalLight"
	light.position = Vector3(4, 6, 2)
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 0.8
	_level_root.add_child(light)

	var fill := OmniLight3D.new()
	fill.name = "GlobalFillLight"
	fill.position = Vector3(0, 3.5, 0)
	fill.light_energy = 0.3
	_level_root.add_child(fill)


# ==============================================================================
# 命中标记——射击打中敌人时准星短暂闪红
# ==============================================================================

func _connect_hit_marker() -> void:
	var wm: WeaponManager = _player.find_child("WeaponManager", true, false) as WeaponManager
	if wm == null:
		return
	if not wm.weapon_changed.is_connected(_on_weapon_changed_for_hitmarker):
		wm.weapon_changed.connect(_on_weapon_changed_for_hitmarker)
	var weapon := wm.get_current_weapon()
	if weapon != null and not weapon.hit_something.is_connected(_on_hit_something):
		weapon.hit_something.connect(_on_hit_something)
	_hit_marker_connected = true


func _on_weapon_changed_for_hitmarker(_name: String, _index: int) -> void:
	var wm := _player.find_child("WeaponManager", true, false) as WeaponManager
	if wm == null:
		return
	var weapon := wm.get_current_weapon()
	if weapon != null:
		if not weapon.hit_something.is_connected(_on_hit_something):
			weapon.hit_something.connect(_on_hit_something)


func _on_hit_something(_hit_point: Vector3, _hit_normal: Vector3, target: Node) -> void:
	var check: Node = target
	while check != null:
		if check is CharacterBody3D and check.has_method("take_damage"):
			_flash_crosshair()
			break
		check = check.get_parent()


func _flash_crosshair() -> void:
	_crosshair.color = Color(1.0, 0.0, 0.0, 0.9)
	get_tree().create_timer(0.08).timeout.connect(_restore_crosshair)


func _restore_crosshair() -> void:
	_crosshair.color = Color(0.0, 1.0, 0.0, 0.7)


# ==============================================================================
# 受伤效果——玩家受伤时全屏闪红
# ==============================================================================

func player_hit(_amount: float) -> void:
	_damage_flash.color = Color(1.0, 0.0, 0.0, 0.4)
	var tween := create_tween()
	tween.tween_property(_damage_flash, "color", Color(1.0, 0.0, 0.0, 0.0), 0.3)


# ==============================================================================
# show_pickup_notification() — 拾取通知（转发给 HUD）
# ==============================================================================
func show_pickup_notification(text: String, color: Color) -> void:
	var ps := get_node_or_null("UI/PlayerStatus")
	if ps != null and ps.has_method("show_notification"):
		ps.show_notification(text, color)


# ==============================================================================
# 准星
# ==============================================================================

func _setup_crosshair() -> void:
	_crosshair.color = Color(0.0, 1.0, 0.0, 0.7)
	_crosshair.size = Vector2(4, 4)
	_crosshair.position = Vector2(get_viewport().size) / 2.0 - _crosshair.size / 2.0
	get_tree().root.size_changed.connect(_on_window_resized)


func _on_window_resized() -> void:
	_crosshair.position = Vector2(get_viewport().size) / 2.0 - _crosshair.size / 2.0

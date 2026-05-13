# ==============================================================================
# Main — 游戏主控制器
# ==============================================================================
# 挂在场景根节点（Main）上，负责：
#   1. 初始化关卡 + 菜单系统
#   2. 命中标记 + 受伤效果 + 拾取通知
# ==============================================================================

extends Node3D

const MainMenuClass = preload("res://scripts/ui/main_menu.gd")
const PauseMenuClass = preload("res://scripts/ui/pause_menu.gd")

@onready var _level_root: Node3D = %Level
@onready var _crosshair: ColorRect = %Crosshair
@onready var _damage_flash: ColorRect = %DamageFlash
@onready var _player: CharacterBody3D = %Player

var _main_menu: CanvasLayer
var _pause_menu: CanvasLayer
var _game_running := false


# ==============================================================================
# _ready()
# ==============================================================================
func _ready() -> void:
	_setup_crosshair()
	_load_level()
	_connect_hit_marker()

	# 菜单系统——挂在 UI 下
	var ui := get_node("UI")
	_main_menu = _create_main_menu()
	ui.add_child(_main_menu)
	_pause_menu = _create_pause_menu()
	ui.add_child(_pause_menu)

	# 主菜单"开始"后初始化游戏
	_main_menu.game_started.connect(_on_game_started)
	_pause_menu.back_to_menu.connect(_on_back_to_menu)


# ==============================================================================
# 菜单系统
# ==============================================================================

func _create_main_menu() -> CanvasLayer:
	var menu := MainMenuClass.new()
	menu.name = "MainMenu"
	return menu

func _create_pause_menu() -> CanvasLayer:
	var menu := PauseMenuClass.new()
	menu.name = "PauseMenu"
	return menu

func _on_game_started() -> void:
	_game_running = true

func _on_back_to_menu() -> void:
	_game_running = false
	_main_menu.show_menu()


func toggle_pause() -> void:
	if not _game_running:
		return
	if get_tree().paused:
		# 已在暂停 → 不确定，但不应出现
		pass
	else:
		_pause_menu.show_pause()


# ==============================================================================
# _load_level() — 初始化关卡
# ==============================================================================
func _load_level() -> void:
	# 1. 开启所有 CSG 碰撞体
	_enable_csg_collision(_level_root)

	# 2. 找 PlayerStart 标记 → 设置出生点
	for child in _level_root.get_children():
		if child.name == "PlayerStart" and child is Node3D:
			_player.global_position = child.global_position
			_player.rotation.y = child.global_rotation.y
			break

	# 3. 编辑器里已有灯光就不加
	var has_light := false
	for child in _level_root.get_children():
		if child is DirectionalLight3D or child is OmniLight3D:
			has_light = true
			break
	if not has_light:
		_add_global_lights()


# ==============================================================================
# _enable_csg_collision(node) — 递归开启所有 CSG 节点的碰撞
# ==============================================================================
func _enable_csg_collision(node: Node) -> void:
	for child in node.get_children():
		if child is CSGBox3D or child is CSGPolygon3D or child is CSGCombiner3D:
			child.use_collision = true
		_enable_csg_collision(child)


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
	wm.weapon_changed.connect(_on_weapon_changed_for_hitmarker)
	var weapon := wm.get_current_weapon()
	if weapon != null:
		weapon.hit_something.connect(_on_hit_something)


func _on_weapon_changed_for_hitmarker(_name: String, _index: int) -> void:
	var wm := _player.find_child("WeaponManager", true, false) as WeaponManager
	if wm == null:
		return
	var weapon := wm.get_current_weapon()
	if weapon != null:
		if not weapon.hit_something.is_connected(_on_hit_something):
			weapon.hit_something.connect(_on_hit_something)


func _on_hit_something(_hit_point: Vector3, _hit_normal: Vector3, target: Node) -> void:
	# 检查是否击中了敌人
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

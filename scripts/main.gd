# ==============================================================================
# Main — 游戏主控制器
# ==============================================================================
# 挂在场景根节点（Main）上，负责游戏状态机、菜单信号、关卡加载管线、
# RunStats 驱动、存档读写、命中标记和受伤效果。
#
# Phase 2.9：用 ArenaLevel PackedScene 加载替代 Phase 1.7 的
# reload_current_scene()，实现真正的关卡切换。
# ==============================================================================

extends Node3D

const RunStatsClass = preload("res://scripts/core/run_stats.gd")
const SaveDataClass = preload("res://scripts/core/save_data.gd")
const MainMenuClass = preload("res://scripts/ui/main_menu.gd")
const PauseMenuClass = preload("res://scripts/ui/pause_menu.gd")
const LevelSelectClass = preload("res://scripts/ui/level_select.gd")
const GameOverClass = preload("res://scripts/ui/game_over_screen.gd")
const ArenaLevelClass = preload("res://scripts/level/arena_level.gd")
const LevelRegistryClass = preload("res://scripts/level/level_registry.gd")

@onready var _level_root: Node3D = %Level
@onready var _crosshair: ColorRect = %Crosshair
@onready var _damage_flash: ColorRect = %DamageFlash
@onready var _player: CharacterBody3D = %Player

var _main_menu: CanvasLayer
var _pause_menu: CanvasLayer
var _level_select: CanvasLayer
var _game_over_screen: CanvasLayer
var _game_state: GameState.State = GameState.State.BOOT
var _current_level_id: String = ""
var _current_level: Node3D = null
var _current_arena: ArenaLevel = null
var _hit_marker_connected := false

var _run_stats := RunStatsClass.new()
var _save_data := SaveDataClass.new()


# ==============================================================================
# _ready()
# ==============================================================================
func _ready() -> void:
	_setup_crosshair()

	var ui := get_node("UI")
	_main_menu = _create_main_menu()
	ui.add_child(_main_menu)
	_pause_menu = _create_pause_menu()
	ui.add_child(_pause_menu)
	_level_select = _create_level_select()
	ui.add_child(_level_select)
	_game_over_screen = _create_game_over_screen()
	ui.add_child(_game_over_screen)

	_main_menu.start_requested.connect(_on_start_requested)
	_main_menu.quit_requested.connect(_on_quit_requested)
	_pause_menu.resumed.connect(_on_pause_resumed)
	_pause_menu.back_to_menu.connect(_on_back_to_menu)
	_level_select.level_selected.connect(_on_level_selected)
	_level_select.back_requested.connect(_on_level_select_back)
	_game_over_screen.restart_requested.connect(_on_restart_requested)
	_game_over_screen.level_select_requested.connect(_on_game_over_level_select)
	_game_over_screen.main_menu_requested.connect(_on_game_over_main_menu)

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
			_game_over_screen.hide()
			_pause_menu.hide()
			_hide_hud()
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		GameState.State.LEVEL_SELECT:
			_main_menu.hide()
			_level_select.show_menu()
			_game_over_screen.hide()
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		GameState.State.PLAYING:
			# 从非 PAUSED 进入时连接信号（首次进入或重开）。
			# 关卡加载在 _start_level() 中已完成，这里只做信号连接。
			if prev != GameState.State.PAUSED:
				_reset_run_stats()
				_connect_player_death()
				if not _hit_marker_connected:
					_connect_hit_marker()
				_connect_enemy_killed()
			_main_menu.hide()
			_level_select.hide()
			_game_over_screen.hide()
			_pause_menu.hide()
			_show_hud()
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

		GameState.State.PAUSED:
			_pause_menu.show_pause()
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		GameState.State.GAME_OVER:
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_hide_hud()
			_end_run()


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
	_start_level(level_id)

func _on_level_select_back() -> void:
	_set_game_state(GameState.State.MAIN_MENU)

func _on_restart_requested() -> void:
	_start_level(_current_level_id)

func _on_game_over_level_select() -> void:
	_unload_current_level()
	_set_game_state(GameState.State.LEVEL_SELECT)

func _on_game_over_main_menu() -> void:
	_unload_current_level()
	_set_game_state(GameState.State.MAIN_MENU)

func _on_back_to_menu() -> void:
	_set_game_state(GameState.State.MAIN_MENU)


# ==============================================================================
# _start_level(level_id) — 启动指定关卡（Phase 2.9 重写）
# ==============================================================================
# 完整的关卡启动流程：
#   1. 卸载旧关卡（如果有）——清理节点树 + 重置引用
#   2. 加载新关卡 PackedScene → 实例化 → 挂到 _level_root 下
#   3. 设置出生点——把玩家传送到 ArenaLevel.get_player_spawn_transform()
#   4. 连接边界警告信号 → HUD 显示"已到达边界"
#   5. 重置玩家血量/护甲/弹药
#   6. 切换到 PLAYING 状态
func _start_level(level_id: String) -> void:
	_current_level_id = level_id

	# 1. 卸载旧关卡
	_unload_current_level()

	# 2. 加载新关卡
	_load_arena_level(level_id)

	# 3. 玩家出生
	_reset_player_for_level()

	# 4. 切换到战斗状态（PLAYING handler 中连接信号）
	_set_game_state(GameState.State.PLAYING)


# ==============================================================================
# _unload_current_level() — 卸载当前关卡
# ==============================================================================
func _unload_current_level() -> void:
	if _current_arena != null:
		if _current_arena.boundary_warning_requested.is_connected(_on_boundary_warning):
			_current_arena.boundary_warning_requested.disconnect(_on_boundary_warning)
		_current_arena = null
	if _current_level != null:
		_current_level.queue_free()
		_current_level = null


# ==============================================================================
# _load_arena_level(level_id) — 加载竞技场关卡 PackedScene
# ==============================================================================
func _load_arena_level(level_id: String) -> void:
	var scene_path := LevelRegistryClass.get_scene_path(level_id)
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Main: 无法加载关卡场景 '%s'" % scene_path)
		return

	_current_level = packed.instantiate()
	_level_root.add_child(_current_level)

	# 如果是 ArenaLevel，设置玩家引用并连接边界信号
	if _current_level is ArenaLevelClass:
		_current_arena = _current_level as ArenaLevel
		_current_arena.set_player(_player)
		if not _current_arena.boundary_warning_requested.is_connected(_on_boundary_warning):
			_current_arena.boundary_warning_requested.connect(_on_boundary_warning)


# ==============================================================================
# _reset_player_for_level() — 重置玩家状态到关卡初始值
# ==============================================================================
func _reset_player_for_level() -> void:
	# 传送到出生点
	if _current_arena != null:
		var spawn := _current_arena.get_player_spawn_transform()
		_player.global_position = spawn.origin
		_player.rotation.y = spawn.basis.get_euler().y

	# 重置速度
	_player.velocity = Vector3.ZERO

	# 重置血量/护甲
	var dmg := _player.get_node_or_null("Damageable") as Damageable
	if dmg != null:
		dmg.reset()

	# 重置武器弹药
	var wm := _player.find_child("WeaponManager", true, false) as WeaponManager
	if wm != null and wm.has_method("reset_all_weapons"):
		wm.reset_all_weapons()

	# 重置 HUD 击杀计数
	var ps := get_node_or_null("UI/PlayerStatus")
	if ps != null and ps.has_method("reset_kill_count"):
		ps.reset_kill_count()


# ==============================================================================
# _process(delta) — 每渲染帧更新 RunStats 计时器
# ==============================================================================
func _process(delta: float) -> void:
	if _game_state == GameState.State.PLAYING and _run_stats.is_running:
		_run_stats.update(delta)


# ==============================================================================
# RunStats 相关方法
# ==============================================================================

func _reset_run_stats() -> void:
	_run_stats.start(_current_level_id)

func _connect_player_death() -> void:
	var dmg := _player.get_node_or_null("Damageable") as Damageable
	if dmg != null and not dmg.died.is_connected(_on_player_died):
		dmg.died.connect(_on_player_died)

func _connect_enemy_killed() -> void:
	var em := _level_root.get_node_or_null("EnemyManager")
	if em != null and em.has_signal("enemy_killed"):
		if not em.enemy_killed.is_connected(_on_enemy_killed_for_score):
			em.enemy_killed.connect(_on_enemy_killed_for_score)

func _on_boundary_warning() -> void:
	var ps := get_node_or_null("UI/PlayerStatus")
	if ps != null and ps.has_method("show_boundary_warning"):
		ps.show_boundary_warning()

func _on_enemy_killed_for_score(_enemy_name: String) -> void:
	_run_stats.add_kill(10)

func _on_player_died() -> void:
	if _game_state == GameState.State.PLAYING:
		_run_stats.stop()
		_set_game_state(GameState.State.GAME_OVER)

func _end_run() -> void:
	var record := _save_data.submit_run(_run_stats.level_id, _run_stats.score, _run_stats.survival_time)
	var results := {
		level_id = _run_stats.level_id,
		score = _run_stats.score,
		kills = _run_stats.kills,
		survival_time = _run_stats.survival_time,
		best_score = record.best_score,
		best_time = record.best_time,
		is_new_record = record.is_new_record,
	}
	_game_over_screen.show()
	_game_over_screen.show_results(results)

func get_run_stats() -> RefCounted:
	return _run_stats

func get_save_data() -> RefCounted:
	return _save_data


# ==============================================================================
# toggle_pause() — Esc 键切换暂停
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

func _create_game_over_screen() -> CanvasLayer:
	var menu := GameOverClass.new()
	menu.name = "GameOverScreen"
	return menu


# ==============================================================================
# _show_hud() / _hide_hud()
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
# 命中标记
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
# 受伤效果
# ==============================================================================

func player_hit(_amount: float) -> void:
	_damage_flash.color = Color(1.0, 0.0, 0.0, 0.4)
	var tween := create_tween()
	tween.tween_property(_damage_flash, "color", Color(1.0, 0.0, 0.0, 0.0), 0.3)


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

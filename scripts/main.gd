# ==============================================================================
# Main — 游戏主控制器
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
const SpawnManagerClass = preload("res://scripts/enemy/spawn_manager.gd")
const DropManagerClass = preload("res://scripts/pickup/drop_manager.gd")
const IronWhipClass = preload("res://scripts/weapon/iron_whip.gd")
const WhipDataClass = preload("res://scripts/weapon/whip_data.gd")

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
var _spawn_manager: Node = null
var _drop_manager: Node = null
var _iron_whip: Node3D = null
var _hit_marker_connected := false
var _crosshair_x1: ColorRect = null
var _crosshair_x2: ColorRect = null

var _run_stats := RunStatsClass.new()
var _save_data := SaveDataClass.new()


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

	GameBus.pickup_notification.connect(show_pickup_notification)
	GameBus.player_hit.connect(player_hit)
	GameBus.pause_toggle.connect(toggle_pause)
	GameBus.shield_block.connect(_on_shield_block)
	GameBus.grab_status_show.connect(_on_grab_status_show)
	GameBus.grab_status_hide.connect(_on_grab_status_hide)
	GameBus.play_sfx.connect(_on_play_sfx)
	GameBus.counter_triggered.connect(_on_counter_triggered)
	GameBus.wave_started.connect(_on_wave_started)

	GameBus.save_data = _save_data

	# UI 增强组件
	var hit_indicator: Control = load("res://scripts/ui/hit_direction_indicator.gd").new()
	hit_indicator.name = "HitDirectionIndicator"
	ui.add_child(hit_indicator)
	var minimap: Control = load("res://scripts/ui/minimap.gd").new()
	minimap.name = "Minimap"
	ui.add_child(minimap)

	_set_game_state(GameState.State.MAIN_MENU)


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


func _start_level(level_id: String) -> void:
	_current_level_id = level_id
	_unload_current_level()
	_load_arena_level(level_id)
	_reset_player_for_level()
	_set_game_state(GameState.State.PLAYING)


func _unload_current_level() -> void:
	if _spawn_manager != null:
		_spawn_manager.stop()
		_spawn_manager = null
	if _drop_manager != null:
		_drop_manager.queue_free()
		_drop_manager = null
	if _iron_whip != null and _iron_whip.has_method("release_grab"):
		_iron_whip.release_grab()
	_player.set_speed_multiplier(1.0)
	_player.grabbed_enemy = null
	if _current_arena != null:
		if _current_arena.boundary_warning_requested.is_connected(_on_boundary_warning):
			_current_arena.boundary_warning_requested.disconnect(_on_boundary_warning)
		_current_arena = null
	if _current_level != null:
		_current_level.queue_free()
		_current_level = null

	for child in get_tree().root.get_children():
		if child is Area3D and child.has_method("_on_body_entered"):
			child.queue_free()


func _load_arena_level(level_id: String) -> void:
	var scene_path := LevelRegistryClass.get_scene_path(level_id)
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Main: 无法加载关卡场景 '%s'" % scene_path)
		return

	_current_level = packed.instantiate()
	_level_root.add_child(_current_level)

	if _current_level is ArenaLevelClass:
		_current_arena = _current_level as ArenaLevel
		_current_arena.set_player(_player)
		if not _current_arena.boundary_warning_requested.is_connected(_on_boundary_warning):
			_current_arena.boundary_warning_requested.connect(_on_boundary_warning)

	_setup_spawn_manager()


func _reset_player_for_level() -> void:
	if _current_arena != null:
		var spawn := _current_arena.get_player_spawn_transform()
		_player.global_position = spawn.origin
		_player.rotation.y = spawn.basis.get_euler().y

	_player.velocity = Vector3.ZERO

	var dmg := _player.get_node_or_null("Damageable") as Damageable
	if dmg != null:
		dmg.reset()

	var wm := _player.find_child("WeaponManager", true, false) as WeaponManager
	if wm != null and wm.has_method("reset_all_weapons"):
		wm.reset_all_weapons()

	var ps := get_node_or_null("UI/PlayerStatus")
	if ps != null and ps.has_method("reset_kill_count"):
		ps.reset_kill_count()

	_setup_iron_whip()

	if _spawn_manager != null:
		if _current_level_id != "test":
			_spawn_manager.start()

	if _drop_manager != null:
		_drop_manager.queue_free()
	_drop_manager = DropManagerClass.new()
	_drop_manager.name = "DropManager"
	add_child(_drop_manager)


func _setup_spawn_manager() -> void:
	if _spawn_manager != null:
		_spawn_manager.stop()
		_spawn_manager = null

	var em := _level_root.get_node_or_null("EnemyManager")
	if em == null:
		return

	var sm := SpawnManagerClass.new()
	sm.name = "SpawnManager"

	var profile := "default"
	if _current_level_id == "desert":
		profile = "desert"
	elif _current_level_id == "lava":
		profile = "lava"

	sm.setup(_current_arena, em, _run_stats, profile)

	if sm.intensity_changed.is_connected(_on_intensity_changed):
		sm.intensity_changed.disconnect(_on_intensity_changed)
	sm.intensity_changed.connect(_on_intensity_changed)

	_level_root.add_child(sm)
	_spawn_manager = sm


func _setup_iron_whip() -> void:
	var holder := _player.get_node_or_null("Camera3D/LeftHandHolder")
	if holder == null:
		return

	var camera := _player.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return

	if _iron_whip != null:
		if _iron_whip.has_method("release_grab"):
			_iron_whip.release_grab()
		_iron_whip.queue_free()
		_iron_whip = null

	var whip := IronWhipClass.new()
	whip.name = "IronWhip"

	var whip_data := load("res://assets/weapons/iron_whip.tres")
	whip.setup(whip_data, camera, _player)

	holder.add_child(whip)
	_iron_whip = whip


func _on_intensity_changed(new_intensity: int) -> void:
	var ps := get_node_or_null("UI/PlayerStatus")
	if ps != null and ps.has_method("update_intensity"):
		ps.update_intensity(new_intensity)


func _process(delta: float) -> void:
	if _game_state == GameState.State.PLAYING and _run_stats.is_running:
		_run_stats.update(delta)


func _reset_run_stats() -> void:
	_run_stats.start(_current_level_id)
	GameBus.run_stats = _run_stats

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

func _on_enemy_killed_for_score(_enemy_name: String, score_value: int) -> void:
	_run_stats.add_kill(score_value)

func _on_player_died() -> void:
	if _iron_whip != null and _iron_whip.has_method("release_grab"):
		_iron_whip.release_grab()
	_player.set_speed_multiplier(1.0)
	_player.grabbed_enemy = null

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


func toggle_pause() -> void:
	match _game_state:
		GameState.State.PLAYING:
			_set_game_state(GameState.State.PAUSED)
		GameState.State.PAUSED:
			_set_game_state(GameState.State.PLAYING)


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
# 命中标记 + X 字准星
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
			_show_x_crosshair()
			return
		check = check.get_parent()
	_flash_crosshair()

func _flash_crosshair() -> void:
	_crosshair.color = Color(1.0, 0.0, 0.0, 0.9)
	get_tree().create_timer(0.08).timeout.connect(_restore_crosshair)

func _restore_crosshair() -> void:
	_crosshair.color = Color(0.0, 1.0, 0.0, 0.7)

func _show_x_crosshair() -> void:
	_flash_crosshair()
	if _crosshair_x1:
		_crosshair_x1.visible = true
	if _crosshair_x2:
		_crosshair_x2.visible = true
	get_tree().create_timer(0.12).timeout.connect(_hide_x_crosshair)

func _hide_x_crosshair() -> void:
	if _crosshair_x1:
		_crosshair_x1.visible = false
	if _crosshair_x2:
		_crosshair_x2.visible = false


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
# GameBus 信号处理器
# ==============================================================================

func _on_shield_block() -> void:
	var ps := get_node_or_null("UI/PlayerStatus")
	if ps != null and ps.has_method("show_shield_block"):
		ps.show_shield_block()

func _on_grab_status_show(enemy_name: String) -> void:
	var ps := get_node_or_null("UI/PlayerStatus")
	if ps != null and ps.has_method("show_grab_status"):
		ps.show_grab_status(enemy_name)

func _on_grab_status_hide() -> void:
	var ps := get_node_or_null("UI/PlayerStatus")
	if ps != null and ps.has_method("hide_grab_status"):
		ps.hide_grab_status()

func _on_play_sfx(_sfx_name: String, _position: Vector3) -> void:
	pass  # SFX 占位：后续接入音频资源时替换

func _on_counter_triggered(_enemy: Enemy, _position: Vector3) -> void:
	_crosshair.color = Color(0.3, 0.8, 1.0, 1.0)
	get_tree().create_timer(0.15).timeout.connect(_restore_crosshair)
	var ps := get_node_or_null("UI/PlayerStatus")
	if ps != null and ps.has_method("show_notification"):
		ps.show_notification("Counter!", Color(0.3, 0.8, 1.0))

func _on_wave_started(wave_number: int) -> void:
	var ps := get_node_or_null("UI/PlayerStatus")
	if ps != null and ps.has_method("show_wave_notification"):
		ps.show_wave_notification(wave_number)


# ==============================================================================
# 准星
# ==============================================================================

func _setup_crosshair() -> void:
	_crosshair.color = Color(0.0, 1.0, 0.0, 0.7)
	_crosshair.size = Vector2(4, 4)
	_crosshair.position = Vector2(get_viewport().size) / 2.0 - _crosshair.size / 2.0

	# X 字准星
	var viewport_size: Vector2 = get_viewport().size
	var cx: float = viewport_size.x / 2.0
	var cy: float = viewport_size.y / 2.0
	var x_len: float = 12.0
	var x_thick: float = 3.0

	_crosshair_x1 = ColorRect.new()
	_crosshair_x1.color = Color(1.0, 0.0, 0.0, 0.9)
	_crosshair_x1.size = Vector2(x_len, x_thick)
	_crosshair_x1.pivot_offset = Vector2(x_len / 2.0, x_thick / 2.0)
	_crosshair_x1.position = Vector2(cx - x_len / 2.0, cy - x_thick / 2.0)
	_crosshair_x1.rotation = deg_to_rad(45.0)
	_crosshair_x1.visible = false
	_crosshair_x1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair_x1)

	_crosshair_x2 = ColorRect.new()
	_crosshair_x2.color = Color(1.0, 0.0, 0.0, 0.9)
	_crosshair_x2.size = Vector2(x_len, x_thick)
	_crosshair_x2.pivot_offset = Vector2(x_len / 2.0, x_thick / 2.0)
	_crosshair_x2.position = Vector2(cx - x_len / 2.0, cy - x_thick / 2.0)
	_crosshair_x2.rotation = deg_to_rad(-45.0)
	_crosshair_x2.visible = false
	_crosshair_x2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair_x2)

	get_tree().root.size_changed.connect(_on_window_resized)

func _on_window_resized() -> void:
	var viewport_size: Vector2 = get_viewport().size
	var cx: float = viewport_size.x / 2.0
	var cy: float = viewport_size.y / 2.0
	var x_len: float = 12.0
	var x_thick: float = 3.0
	_crosshair.position = Vector2(cx - _crosshair.size.x / 2.0, cy - _crosshair.size.y / 2.0)
	if _crosshair_x1:
		_crosshair_x1.position = Vector2(cx - x_len / 2.0, cy - x_thick / 2.0)
	if _crosshair_x2:
		_crosshair_x2.position = Vector2(cx - x_len / 2.0, cy - x_thick / 2.0)

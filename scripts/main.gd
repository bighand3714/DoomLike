# ==============================================================================
# Main — 游戏主控制器
# ==============================================================================
# 挂在场景根节点（Main）上，负责：
#   1. 游戏状态机（BOOT → MAIN_MENU → LEVEL_SELECT → PLAYING / PAUSED / GAME_OVER）
#   2. 菜单创建与信号连接
#   3. 关卡初始化（CSG 碰撞 + 出生点）
#   4. 命中标记 + 受伤效果 + 拾取通知
#   5. RunStats 驱动（_process 中更新生存时间）
#   6. 存档读写（SaveData，结算时提交记录）
#
# 完整游戏流程（Phase 1.7 闭环）：
#
#   启动 → _ready()
#     ├─ pending_level_start=false → MAIN_MENU（正常冷启动）
#     │    └─ 点击"开始游戏" → LEVEL_SELECT
#     │         └─ 选关 → _start_level("desert")
#     │              └─ 设 static var → reload_current_scene()
#     │                   └─ 再次 _ready()
#     │                        └─ pending_level_start=true → PLAYING（热启动）
#     │                             ├─ 战斗中 Esc → PAUSED → 继续 → PLAYING
#     │                             └─ 玩家死亡 → GAME_OVER
#     │                                  └─ 结算："重新开始" → _start_level()
#     │                                       └─ 再次回到"热启动"流程
#     │                                  └─ 结算："返回选关" → LEVEL_SELECT
#     │                                  └─ 结算："返回主菜单" → MAIN_MENU
#     └─ pending_level_start=true → PLAYING（热启动，跳过所有菜单）
#
# 类比：
#   这个脚本就像交响乐团的指挥——它自己不演奏任何乐器，
#   但负责在正确的时刻告诉各个声部（菜单/关卡/玩家/敌人/HUD）该做什么。
# ==============================================================================

extends Node3D

const RunStatsClass = preload("res://scripts/core/run_stats.gd")
const SaveDataClass = preload("res://scripts/core/save_data.gd")
const MainMenuClass = preload("res://scripts/ui/main_menu.gd")
const PauseMenuClass = preload("res://scripts/ui/pause_menu.gd")
const LevelSelectClass = preload("res://scripts/ui/level_select.gd")
const GameOverClass = preload("res://scripts/ui/game_over_screen.gd")

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
var _hit_marker_connected := false

var _run_stats := RunStatsClass.new()
var _save_data := SaveDataClass.new()


# ==============================================================================
# _ready() — 场景加载完成后自动调用，游戏的总入口
# ==============================================================================
# Godot 在场景树构建完毕后调用每个节点的 _ready()。Main 的 _ready() 负责：
#   1. 设置准星外观和位置
#   2. 创建四个菜单界面（主菜单/暂停/选关/结算）
#   3. 连接所有菜单按钮的信号
#   4. 决定进入哪个初始状态：
#        - 正常启动 → MAIN_MENU（看到标题画面）
#        - 热启动 → PLAYING（选关后场景重载，直接进入战斗）
#
# 关于"热启动"（Phase 1.7）：
#   选关或重新开始时，_start_level() 会调用 reload_current_scene() 销毁并
#   重建整个场景树。新场景的 _ready() 再次执行，此时 GameState.pending_level_start
#   为 true（它是在 _start_level() 中设置的 static var，跨场景重载保持）。
#   检测到这个标志后，跳过所有菜单显示，直接进入 PLAYING 状态。
#
#   这个设计避免了"重开后还要再看一遍主菜单"的糟糕体验。
#   Phase 2 会改用增量关卡加载，届时不再需要这个热启动机制。
func _ready() -> void:
	_setup_crosshair()

	# 菜单系统——全部挂在 UI 节点下，用 CanvasLayer 保证渲染在最上层
	var ui := get_node("UI")
	_main_menu = _create_main_menu()
	ui.add_child(_main_menu)
	_pause_menu = _create_pause_menu()
	ui.add_child(_pause_menu)
	_level_select = _create_level_select()
	ui.add_child(_level_select)
	_game_over_screen = _create_game_over_screen()
	ui.add_child(_game_over_screen)

	# 信号连接——菜单按钮事件 → Main 的回调函数
	_main_menu.start_requested.connect(_on_start_requested)
	_main_menu.quit_requested.connect(_on_quit_requested)
	_pause_menu.resumed.connect(_on_pause_resumed)
	_pause_menu.back_to_menu.connect(_on_back_to_menu)
	_level_select.level_selected.connect(_on_level_selected)
	_level_select.back_requested.connect(_on_level_select_back)
	_game_over_screen.restart_requested.connect(_on_restart_requested)
	_game_over_screen.level_select_requested.connect(_on_game_over_level_select)
	_game_over_screen.main_menu_requested.connect(_on_game_over_main_menu)

	# Phase 1.7：判断是"冷启动"还是"热启动"
	# 冷启动 = 正常打开游戏 → 显示主菜单
	# 热启动 = 选关/重开后场景重载 → 直接进入战斗
	if GameState.pending_level_start:
		# 热启动路径：消费 static var 中的"跳关密码"
		GameState.pending_level_start = false
		_current_level_id = GameState.pending_level_id
		_set_game_state(GameState.State.PLAYING)
	else:
		# 冷启动路径：正常显示主菜单
		_set_game_state(GameState.State.MAIN_MENU)


# ==============================================================================
# _set_game_state(next_state) — 游戏状态切换的总调度
# ==============================================================================
# 整个游戏只有一个地方可以改变状态，就是这里。这样做的好处：
#   所有状态切换都经过同一个"关卡"→ 容易加日志、容易排查 bug、
#   不会出现"某个地方偷偷改了状态导致另一个模块崩溃"的情况。
#
# 参数：
#   next_state —— 目标状态（GameState.State 枚举值）
#
# 每个状态做什么：
#   MAIN_MENU    —— 显示主菜单，隐藏其他界面，暂停物理，释放鼠标
#   LEVEL_SELECT —— 显示选关界面，隐藏主菜单
#   PLAYING      —— 隐藏所有菜单，显示 HUD，恢复物理，捕获鼠标
#                   （从非 PAUSED 进入时还会执行关卡初始化）
#   PAUSED       —— 覆盖暂停菜单，暂停物理，释放鼠标
#   GAME_OVER    —— 隐藏 HUD，结算并显示成绩
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
			# 关键判断：只有"第一次进入"或"重新开始"时才初始化关卡。
			# 从 PAUSED 回来时 prev==PAUSED → 跳过初始化，
			# 因为关卡/敌人/武器状态都还在，只需要恢复物理和隐藏菜单。
			#
			# 类比：暂停就像把书签夹在书里——回来时翻到同一页继续读，
			# 不需要从第一页重新开始。
			if prev != GameState.State.PAUSED:
				_load_level()
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
			# 暂停物理防止玩家死后还能移动/敌人继续攻击
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_hide_hud()
			# _end_run() 负责：停止计时 → 提交成绩到存档 → 弹出结算界面
			_end_run()


# ==============================================================================
# 菜单信号回调
# ==============================================================================
# 这些函数是菜单按钮的"接线员"——按钮被点击 → 信号发出 → 回调执行。
# 每个回调通常只做一件事：调用 _set_game_state() 切换状态。

func _on_start_requested() -> void:
	_set_game_state(GameState.State.LEVEL_SELECT)

func _on_quit_requested() -> void:
	get_tree().quit()

func _on_pause_resumed() -> void:
	_set_game_state(GameState.State.PLAYING)

# 选关后直接调用 _start_level()，它会触发场景重载。
# 不需要再手动调用 _set_game_state(PLAYING)，因为重载后的 _ready()
# 会自动通过"热启动"路径进入 PLAYING。
func _on_level_selected(level_id: String) -> void:
	_start_level(level_id)

func _on_level_select_back() -> void:
	_set_game_state(GameState.State.MAIN_MENU)

# 重新开始 = 用同一个 level_id 再跑一次 _start_level()
func _on_restart_requested() -> void:
	_start_level(_current_level_id)

func _on_game_over_level_select() -> void:
	_set_game_state(GameState.State.LEVEL_SELECT)

func _on_game_over_main_menu() -> void:
	_set_game_state(GameState.State.MAIN_MENU)

func _on_back_to_menu() -> void:
	_set_game_state(GameState.State.MAIN_MENU)


# ==============================================================================
# _start_level(level_id) — 启动指定关卡（Phase 1.7 核心）
# ==============================================================================
# 这个方法做的事情很简单：把"我要启动哪个关卡"的信息写入 static var，
# 然后调用 reload_current_scene() 重置整个游戏。
#
# 为什么用场景重载而不是增量重置：
#   完全重置一个复杂游戏的状态非常困难——玩家位置、血量、护甲、弹药、
#   武器栏位、敌人列表、投射物、HUD……逐个重置容易漏掉，导致"幽灵状态"
#   （比如上一局的子弹还在飞、旧敌人引用没清干净）。
#
#   reload_current_scene() 相当于"关掉游戏再打开"——Godot 负责销毁
#   所有节点、释放所有引用、重置所有物理状态，不会有残留。
#   代价是有一瞬间的黑屏（实际上很快，几乎感觉不到）。
#
# 关于 get_tree().paused = false：
#   如果玩家在结算界面（GAME_OVER 状态，树是暂停的）点"重新开始"，
#   需要先取消暂停，否则 reload_current_scene() 后新场景也会处于暂停状态。
#   在已取消暂停的树中调用这行没有副作用（paused=false 再设一次还是 false）。
#
# 关于 static var 为什么能跨重载保持：
#   见 game_state.gd 中 pending_level_start / pending_level_id 的详细注释。
#
# Phase 2 计划：
#   改用 ArenaLevel 场景的增量加载/卸载，不再 reload 整个 main.tscn。
#   届时这个方法会变成：_unload_current_level() → 加载新关卡 .tscn →
#   实例化到 CurrentLevelRoot → 调 reset() 系列方法。
func _start_level(level_id: String) -> void:
	GameState.pending_level_id = level_id
	GameState.pending_level_start = true
	get_tree().paused = false
	get_tree().reload_current_scene()


# ==============================================================================
# _process(delta) — 每渲染帧更新 RunStats 计时器
# ==============================================================================
# RunStats 的 survival_time 需要每帧累加，才能实现"坚持了多久"的计时。
# 只在 PLAYING 状态且 RunStats 正在计时（is_running=true）时才更新。
#
# is_running 在玩家死亡时会被 _on_player_died() → _run_stats.stop() 设为 false，
# 所以死亡后计时就停了——结算界面显示的是最终存活时间。
func _process(delta: float) -> void:
	if _game_state == GameState.State.PLAYING and _run_stats.is_running:
		_run_stats.update(delta)


# ==============================================================================
# RunStats 相关方法
# ==============================================================================

# 每次进入新关卡时调用，重置统计并开始计时。
# _current_level_id 在 _ready() 的热启动路径中已经从 static var 读取。
func _reset_run_stats() -> void:
	_run_stats.start(_current_level_id)

# 连接玩家的"死亡"信号到 _on_player_died()。
# 需要每次都检查 is_connected，因为场景重载后是新的 Damageable 实例。
func _connect_player_death() -> void:
	var dmg := _player.get_node_or_null("Damageable") as Damageable
	if dmg != null and not dmg.died.is_connected(_on_player_died):
		dmg.died.connect(_on_player_died)

# 连接 EnemyManager 的击杀信号到分数统计。
# 每杀一个敌人 → enemy_killed 信号 → _on_enemy_killed_for_score() → RunStats.add_kill()
func _connect_enemy_killed() -> void:
	var em := _level_root.get_node_or_null("EnemyManager")
	if em != null and em.has_signal("enemy_killed"):
		if not em.enemy_killed.is_connected(_on_enemy_killed_for_score):
			em.enemy_killed.connect(_on_enemy_killed_for_score)

# 敌人击杀 → 加分数。目前固定 10 分/个，Phase 5 会改为从 EnemyData.score_value 读取。
func _on_enemy_killed_for_score(_enemy_name: String) -> void:
	_run_stats.add_kill(10)

# 玩家死亡时的处理流程：
#   1. 停止 RunStats 计时（结算界面需要显示最终存活时间）
#   2. 切换到 GAME_OVER 状态（GAME_OVER handler 会调用 _end_run()）
#
# 注意：先 stop 再切换状态——如果反过来，_end_run() 在 stop 之前执行，
# survival_time 会比实际多出切换状态这一帧的时间（大约 0.016 秒，影响不大，
# 但逻辑上先停表再结算是更正确的顺序）。
func _on_player_died() -> void:
	if _game_state == GameState.State.PLAYING:
		_run_stats.stop()
		_set_game_state(GameState.State.GAME_OVER)

# _end_run() — 本局结束，提交成绩并显示结算界面
# ==============================================================================
# 做了三件事：
#   1. 调用 SaveData.submit_run() 把本局成绩和存档里的历史记录比较，
#      返回是否刷新了最高分/最长时间（record 字典）。
#   2. 把所有数据打包成 results 字典传给结算 UI。
#   3. 显示结算界面（GameOverScreen）。
#
# results 字典包含的字段：
#   level_id      —— "desert" 或 "lava"
#   score         —— 本局分数
#   kills         —— 本局击杀数
#   survival_time —— 本局存活秒数
#   best_score    —— 该关历史最高分（已更新）
#   best_time     —— 该关历史最长时间（已更新）
#   is_new_record —— 是否刷新了纪录（控制"★ 新纪录 ★"显示）
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
# toggle_pause() — Esc 键切换暂停（由 player_controller 调用）
# ==============================================================================
# 暂停逻辑很简单：PLAYING ↔ PAUSED 双向切换。
# 在其他状态（如 MAIN_MENU、GAME_OVER）按 Esc 不会触发这个函数，
# 因为 player_controller 的 _input() 中检查了 get_tree().paused，
# 非 PLAYING 时树是暂停的，_input 直接 return 了。
func toggle_pause() -> void:
	match _game_state:
		GameState.State.PLAYING:
			_set_game_state(GameState.State.PAUSED)
		GameState.State.PAUSED:
			_set_game_state(GameState.State.PLAYING)


# ==============================================================================
# 菜单工厂方法
# ==============================================================================
# 四个菜单都是纯代码创建的（没有 .tscn 场景文件）。
# 这样做的原因：这几个菜单的结构比较简单（几个 Label + Button），
# 用代码创建比维护 .tscn 文件更灵活——改颜色/位置/文字直接改代码即可。

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
#
# 当前做了三件事：
#   1. 递归启用所有 level_geometry 节点的 CSG 碰撞（让子弹能打到墙壁/地面）
#   2. 找到 PlayerStart 节点，把玩家传送到出生点
#   3. 如果关卡没有自带灯光，添加默认的方向光 + 补光
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

# ==============================================================================
# Main — 游戏主控制器
# ==============================================================================
# 挂在场景的根节点（Main）上，负责：
#   1. 搭建测试房间
#   2. 生成敌人和靶子
#   3. 设置准星
#   4. 命中标记（准星闪红）
#   5. 受伤效果（屏幕闪红）
# ==============================================================================

extends Node3D

# 预加载依赖的类——解决 Godot 跨文件 class_name 解析顺序问题
const EnemyConst = preload("res://scripts/enemy/enemy.gd")
const EnemyDataConst = preload("res://scripts/enemy/enemy_data.gd")
const EnemyManagerConst = preload("res://scripts/enemy/enemy_manager.gd")
const ImpConst = preload("res://scripts/enemy/imp.gd")
const DemonSoldierConst = preload("res://scripts/enemy/demon_soldier.gd")


# ==============================================================================
# 节点引用
# ==============================================================================

@onready var _level_root: Node3D = %Level
@onready var _crosshair: ColorRect = %Crosshair
@onready var _damage_flash: ColorRect = %DamageFlash
@onready var _enemy_manager: Node = %EnemyManager
@onready var _player: CharacterBody3D = %Player


# ==============================================================================
# _ready() — 游戏启动
# ==============================================================================
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_test_room()
	_setup_crosshair()
	_spawn_enemies()
	_connect_hit_marker()


# ==============================================================================
# _build_test_room() — 搭建测试房间
# ==============================================================================
func _build_test_room() -> void:
	const ROOM_W := 12.0
	const ROOM_D := 12.0
	const ROOM_H := 4.0
	const WALL_T := 0.3

	var floor_mat := _make_color_material(Color(0.3, 0.28, 0.25))
	var wall_mat := _make_color_material(Color(0.45, 0.42, 0.38))
	var ceiling_mat := _make_color_material(Color(0.35, 0.33, 0.3))

	_floor(ROOM_W, ROOM_D, WALL_T, floor_mat)
	_ceiling(ROOM_W, ROOM_D, ROOM_H, WALL_T, ceiling_mat)

	_wall(Vector3(0, ROOM_H / 2.0, -ROOM_D / 2.0), Vector3(ROOM_W, ROOM_H, WALL_T), wall_mat)
	_wall(Vector3(0, ROOM_H / 2.0, ROOM_D / 2.0), Vector3(ROOM_W, ROOM_H, WALL_T), wall_mat)
	_wall(Vector3(-ROOM_W / 2.0, ROOM_H / 2.0, 0), Vector3(WALL_T, ROOM_H, ROOM_D), wall_mat)
	_wall(Vector3(ROOM_W / 2.0, ROOM_H / 2.0, 0), Vector3(WALL_T, ROOM_H, ROOM_D), wall_mat)

	var pillar_mat := _make_color_material(Color(0.5, 0.35, 0.3))
	_csg_box(Vector3(0, ROOM_H / 2.0, 0), Vector3(1.2, ROOM_H, 1.2), pillar_mat)

	_spawn_target(Vector3(-2, ROOM_H / 2.0, 2), Vector3(1.0, 1.5, 1.0))
	_spawn_target(Vector3(3, ROOM_H / 2.0, -2), Vector3(0.8, 2.0, 0.8))

	# 灯光
	var light := DirectionalLight3D.new()
	light.position = Vector3(4, ROOM_H + 2, 2)
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 0.8
	_level_root.add_child(light)

	var fill := OmniLight3D.new()
	fill.position = Vector3(0, ROOM_H - 0.5, 0)
	fill.light_energy = 0.3
	_level_root.add_child(fill)


# ==============================================================================
# _spawn_enemies() — 在测试房间中放置敌人
# ==============================================================================
func _spawn_enemies() -> void:
	# 加载配置数据
	var imp_data := load("res://assets/enemies/imp.tres")
	var soldier_data := load("res://assets/enemies/demon_soldier.tres")

	if imp_data == null or soldier_data == null:
		push_error("Main: 无法加载敌人配置文件（.tres）")
		return

	# 2 只 Imp，分散在房间角落
	_enemy_manager.spawn_enemy(ImpConst, Vector3(-4, 0, -3), imp_data)
	_enemy_manager.spawn_enemy(ImpConst, Vector3(4, 0, 3), imp_data)

	# 1 只 Demon Soldier，在房间一侧
	_enemy_manager.spawn_enemy(DemonSoldierConst, Vector3(-3, 0, 3), soldier_data)

	print("[Main] 敌人已生成：2 Imp + 1 Demon Soldier")


# ==============================================================================
# _connect_hit_marker() — 连接射击命中信号，实现准星闪红
# ==============================================================================
func _connect_hit_marker() -> void:
	var wm := _player.get_node_or_null("WeaponHolder/WeaponManager") as WeaponManager
	if wm == null:
		return

	wm.weapon_changed.connect(_on_weapon_changed_for_hitmarker)

	var weapon := wm.get_current_weapon()
	if weapon != null:
		weapon.hit_something.connect(_on_hit_something)


func _on_weapon_changed_for_hitmarker(_name: String, _index: int) -> void:
	var wm := _player.get_node_or_null("WeaponHolder/WeaponManager") as WeaponManager
	if wm == null:
		return
	var weapon := wm.get_current_weapon()
	if weapon != null:
		if not weapon.hit_something.is_connected(_on_hit_something):
			weapon.hit_something.connect(_on_hit_something)


# ==============================================================================
# _on_hit_something() — 命中标记：打中敌人时准星变红
# ==============================================================================
func _on_hit_something(_hit_point: Vector3, _hit_normal: Vector3, target: Node) -> void:
	# 向上查找，检查是否命中敌人
	var is_enemy := false
	var check: Node = target
	while check != null:
		if check is EnemyConst:
			is_enemy = true
			break
		check = check.get_parent()

	if is_enemy:
		_flash_crosshair()


# ==============================================================================
# 准星闪红
# ==============================================================================

func _flash_crosshair() -> void:
	_crosshair.color = Color(1.0, 0.0, 0.0, 0.9)
	var timer := get_tree().create_timer(0.08)
	timer.timeout.connect(_restore_crosshair)


func _restore_crosshair() -> void:
	_crosshair.color = Color(0.0, 1.0, 0.0, 0.7)


# ==============================================================================
# player_hit() — 屏幕闪红（由 player_controller.gd 调用）
# ==============================================================================
func player_hit(_amount: float) -> void:
	_damage_flash.color = Color(1.0, 0.0, 0.0, 0.4)

	var tween := create_tween()
	tween.tween_property(_damage_flash, "color", Color(1.0, 0.0, 0.0, 0.0), 0.3)


# ==============================================================================
# 辅助函数
# ==============================================================================

func _floor(w: float, d: float, t: float, mat: Material) -> CSGBox3D:
	var box := _csg_box(Vector3(0, -t / 2.0, 0), Vector3(w, t, d), mat)
	box.name = "Floor"
	return box

func _ceiling(w: float, d: float, h: float, t: float, mat: Material) -> CSGBox3D:
	var box := _csg_box(Vector3(0, h + t / 2.0, 0), Vector3(w, t, d), mat)
	box.name = "Ceiling"
	return box

func _wall(pos: Vector3, size: Vector3, mat: Material) -> CSGBox3D:
	return _csg_box(pos, size, mat)

func _csg_box(pos: Vector3, size: Vector3, mat: Material) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.position = pos
	box.size = size
	box.material_override = mat
	box.use_collision = true
	_level_root.add_child(box)
	return box

func _make_color_material(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.9
	return mat

func _setup_crosshair() -> void:
	_crosshair.color = Color(0.0, 1.0, 0.0, 0.7)
	_crosshair.size = Vector2(4, 4)
	_crosshair.position = Vector2(get_viewport().size) / 2.0 - _crosshair.size / 2.0
	get_tree().root.size_changed.connect(_on_window_resized)

func _on_window_resized() -> void:
	_crosshair.position = Vector2(get_viewport().size) / 2.0 - _crosshair.size / 2.0

func _spawn_target(pos: Vector3, size: Vector3) -> ShootingTarget:
	var target := ShootingTarget.new()
	target.position = pos
	target.size = size
	_level_root.add_child(target)
	return target

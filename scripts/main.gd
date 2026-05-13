# ==============================================================================
# Main — 游戏主控制器
# ==============================================================================
# 挂在场景根节点（Main）上，负责：
#   1. 初始化关卡（CSG 碰撞 + PlayerStart 出生点 + 灯光）
#   2. 命中标记（准星闪红）
#   3. 受伤效果（全屏闪红）
# ==============================================================================

extends Node3D


# ==============================================================================
# 节点引用
# ==============================================================================

@onready var _level_root: Node3D = %Level
@onready var _crosshair: ColorRect = %Crosshair
@onready var _damage_flash: ColorRect = %DamageFlash
@onready var _player: CharacterBody3D = %Player


# ==============================================================================
# _ready() — 游戏启动
# ==============================================================================
func _ready() -> void:
	_setup_crosshair()
	_load_level()
	_connect_hit_marker()


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
# 准星
# ==============================================================================

func _setup_crosshair() -> void:
	_crosshair.color = Color(0.0, 1.0, 0.0, 0.7)
	_crosshair.size = Vector2(4, 4)
	_crosshair.position = Vector2(get_viewport().size) / 2.0 - _crosshair.size / 2.0
	get_tree().root.size_changed.connect(_on_window_resized)


func _on_window_resized() -> void:
	_crosshair.position = Vector2(get_viewport().size) / 2.0 - _crosshair.size / 2.0

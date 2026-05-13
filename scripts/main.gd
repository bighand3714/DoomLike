# ==============================================================================
# Main — 游戏主控制器
# ==============================================================================
# 挂在场景的根节点（Main）上，负责：
#   1. 创建测试关卡数据 + 调用 LevelBuilder 生成 3D 场景
#   2. 设置准星
#   3. 命中标记（准星闪红）
#   4. 受伤效果（屏幕闪红）
# ==============================================================================

extends Node3D

# 预加载依赖的类
const EnemyConst = preload("res://scripts/enemy/enemy.gd")
const ImpConst = preload("res://scripts/enemy/imp.gd")
const DemonSoldierConst = preload("res://scripts/enemy/demon_soldier.gd")
const SectorClass = preload("res://scripts/level/data/sector.gd")
const WallDefClass = preload("res://scripts/level/data/wall_def.gd")
const ThingDefClass = preload("res://scripts/level/data/thing_def.gd")


# ==============================================================================
# 节点引用
# ==============================================================================

@onready var _level_root: Node3D = %Level
@onready var _crosshair: ColorRect = %Crosshair
@onready var _damage_flash: ColorRect = %DamageFlash
@onready var _enemy_manager: Node = %EnemyManager
@onready var _player: CharacterBody3D = %Player

var _level_builder: LevelBuilder = null

## 当前关卡的文件路径（导出时自动更新）
var _current_level_path: String = "res://assets/levels/test_room.tres"

# ==============================================================================
# _ready() — 游戏启动
# ==============================================================================
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_crosshair()
	_load_level()
	_connect_hit_marker()


# ==============================================================================
# _load_level() — 加载关卡（优先 .tres，回退到代码构建）
# ==============================================================================
func _load_level() -> void:
	# === 如果 Level 下有 CSG 节点 → 直接模式（所见即所得）===
	# 编辑器里放的 CSG 几何体就是关卡，PlayerStart 标记出生点，
	# Imp/DemonSoldier 等真实敌人节点直接存在于场景中。
	# === 如果 Level 下无 CSG → 加载 .tres 模式 ===
	if _has_csg_in_children(_level_root):
		_load_direct_mode()
	else:
		_load_tres_mode()


func _has_csg_in_children(node: Node) -> bool:
	for child in node.get_children():
		if child is CSGBox3D or child is CSGPolygon3D or child is CSGCombiner3D:
			return true
		if _has_csg_in_children(child):
			return true
	return false


func _load_direct_mode() -> void:
	print("[main] 直接模式：编辑器 CSG + 真实敌人节点")

	# 1. 开启所有 CSG 碰撞
	_enable_csg_collision(_level_root)

	# 2. 找 PlayerStart 标记 → 设置出生点
	var spawn_set := false
	for child in _level_root.get_children():
		if child.name == "PlayerStart" and child is Node3D:
			_player.global_position = child.global_position
			_player.rotation.y = child.global_rotation.y
			spawn_set = true
			print("[main] 出生点: (%.1f, %.1f, %.1f)" % [child.global_position.x, child.global_position.y, child.global_position.z])
			break
	if not spawn_set:
		print("[main] 未找到 PlayerStart，使用默认 (0, 2, 0)")

	# 3. 编辑器里已有灯光就不加
	var has_light := false
	for child in _level_root.get_children():
		if child is DirectionalLight3D or child is OmniLight3D:
			has_light = true
			break
	if not has_light:
		_add_global_lights()


func _enable_csg_collision(node: Node) -> void:
	for child in node.get_children():
		if child is CSGBox3D or child is CSGPolygon3D or child is CSGCombiner3D:
			child.use_collision = true
		_enable_csg_collision(child)


func _load_tres_mode() -> void:
	print("[main] 加载 .tres 模式")

	var level_data: LevelData = null
	if ResourceLoader.exists(_current_level_path):
		level_data = load(_current_level_path) as LevelData

	if level_data == null:
		print("[main] 无 .tres，使用代码构建测试关卡")
		level_data = _create_test_level()

	_level_builder = LevelBuilder.new()
	_level_builder.level_data = level_data
	_level_builder.enemy_manager = _enemy_manager
	_level_root.add_child(_level_builder)
	_level_builder.build()

	var spawn := _level_builder.player_spawn
	_player.global_position = spawn.origin
	_player.rotation = Vector3(0, spawn.basis.get_euler().y, 0)

	_add_global_lights()


# ==============================================================================
# _create_test_level() — 用代码构建测试关卡数据
# ==============================================================================
# 3扇区连通空间：大堂 + 北室 + 东翼，全部可自由穿行
func _create_test_level() -> LevelData:
	var data := LevelData.new()
	data.metadata["name"] = "测试关卡"
	data.metadata["author"] = "Developer"

	# ======================================================================
	# Sector 0 — 主大堂  10×8m, 高4m, 亮度160
	# 范围: X:-5~5, Z:-4~4
	# 北墙中间开口(3m宽)通往 Sector 1
	# 东墙中间开口(3m宽)通往 Sector 2
	# ======================================================================
	var s0 := SectorClass.new()
	s0.floor_height = 0.0
	s0.ceiling_height = 4.0
	s0.light_level = 160

	# 北墙——分三段，中间是门洞(Portal)通往Sector1
	s0.walls.append(_wd(5, -4, 1.5, -4))       # 右段实墙
	s0.walls.append(_wd(1.5, -4, -1.5, -4, 1))  # 中段门洞 →S1
	s0.walls.append(_wd(-1.5, -4, -5, -4))       # 左段实墙
	# 西墙——整面实墙
	s0.walls.append(_wd(-5, -4, -5, 4))
	# 南墙——整面实墙
	s0.walls.append(_wd(-5, 4, 5, 4))
	# 东墙——分三段，中间门洞通往Sector2
	s0.walls.append(_wd(5, 4, 5, 1.5))
	s0.walls.append(_wd(5, 1.5, 5, -1.5, 2))    # 中段门洞 →S2
	s0.walls.append(_wd(5, -1.5, 5, -4))

	data.sectors.append(s0)

	# ======================================================================
	# Sector 1 — 北室  6×6m, 高3m(天花板更低), 亮度120(偏暗)
	# 范围: X:-3~3, Z:-9~-3
	# 南墙中间开口通往 Sector 0
	# ======================================================================
	var s1 := SectorClass.new()
	s1.floor_height = 0.0
	s1.ceiling_height = 3.0
	s1.light_level = 120

	s1.walls.append(_wd(-3, -9, 3, -9))          # 北墙
	s1.walls.append(_wd(3, -9, 3, -3))           # 东墙
	s1.walls.append(_wd(3, -3, 1.5, -3))         # 南墙右段
	s1.walls.append(_wd(1.5, -3, -1.5, -3, 0))   # 南墙中段门洞 →S0
	s1.walls.append(_wd(-1.5, -3, -3, -3))       # 南墙左段
	s1.walls.append(_wd(-3, -3, -3, -9))          # 西墙

	data.sectors.append(s1)

	# ======================================================================
	# Sector 2 — 东翼  5×10m, 高5m(天花板更高), 亮度200(偏亮)
	# 范围: X:5~10, Z:-5~5
	# 西墙中间开口通往 Sector 0
	# ======================================================================
	var s2 := SectorClass.new()
	s2.floor_height = 0.0
	s2.ceiling_height = 5.0
	s2.light_level = 200

	s2.walls.append(_wd(5, -5, 10, -5))           # 北墙
	s2.walls.append(_wd(10, -5, 10, 5))           # 东墙
	s2.walls.append(_wd(10, 5, 5, 5))             # 南墙
	s2.walls.append(_wd(5, 5, 5, 1.5))            # 西墙上段
	s2.walls.append(_wd(5, 1.5, 5, -1.5, 0))      # 西墙中段门洞 →S0
	s2.walls.append(_wd(5, -1.5, 5, -5))          # 西墙下段

	data.sectors.append(s2)

	# ======================================================================
	# 实体放置
	# ======================================================================

	# 玩家出生点——Sector 0 南侧，面朝北（看向门洞方向）
	var ps := _thing(ThingDefClass.Type.PLAYER_START, &"", Vector3(0, 1.6, 3), 0)
	data.things.append(ps)

	# Sector 0 敌人：2只Imp 守在门洞附近
	data.things.append(_thing(ThingDefClass.Type.ENEMY, &"imp", Vector3(-3.5, 0, -2), 0))
	data.things.append(_thing(ThingDefClass.Type.ENEMY, &"imp", Vector3(3.5, 0, 1), 0))

	# Sector 1 敌人：1只Demon Soldier 守在北室
	data.things.append(_thing(ThingDefClass.Type.ENEMY, &"demon_soldier", Vector3(0, 0, -6), 0))

	# Sector 2 敌人：1只Imp 守在东翼
	data.things.append(_thing(ThingDefClass.Type.ENEMY, &"imp", Vector3(8, 0, 3), 0))

	# 装饰柱子——分散在各扇区
	data.things.append(_thing(ThingDefClass.Type.DECORATION, &"pillar", Vector3(-2.5, 2, 0), 0))
	data.things.append(_thing(ThingDefClass.Type.DECORATION, &"pillar", Vector3(2.5, 2, 0), 0))
	data.things.append(_thing(ThingDefClass.Type.DECORATION, &"pillar", Vector3(0, 1.5, -6), 0))
	data.things.append(_thing(ThingDefClass.Type.DECORATION, &"pillar", Vector3(7.5, 2.5, 0), 0))

	return data


# ==============================================================================
# _wd() — 快捷创建 WallDef（减少重复代码）
# ==============================================================================
# sx,sz = 起点XZ,  ex,ez = 终点XZ,  portal = 通向的扇区(-1=实墙)
func _wd(sx: float, sz: float, ex: float, ez: float, portal: int = -1) -> WallDef:
	var w := WallDefClass.new()
	w.start = Vector2(sx, sz)
	w.end = Vector2(ex, ez)
	w.portal_to = portal
	return w


# ==============================================================================
# _thing() — 快捷创建 ThingDef
# ==============================================================================
func _thing(type: int, subtype: StringName, pos: Vector3, angle: float) -> ThingDef:
	var t := ThingDefClass.new()
	t.type = type
	t.subtype = subtype
	t.position = pos
	t.angle = angle
	return t


# ==============================================================================
# _add_global_lights() — 添加主光源和补光
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
# 命中标记
# ==============================================================================

func _connect_hit_marker() -> void:
	var wm := _player.find_child("WeaponManager", true, false) as WeaponManager
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
	var is_enemy := false
	var check: Node = target
	while check != null:
		if check is EnemyConst:
			is_enemy = true
			break
		check = check.get_parent()
	if is_enemy:
		_flash_crosshair()


func _flash_crosshair() -> void:
	_crosshair.color = Color(1.0, 0.0, 0.0, 0.9)
	var timer := get_tree().create_timer(0.08)
	timer.timeout.connect(_restore_crosshair)


func _restore_crosshair() -> void:
	_crosshair.color = Color(0.0, 1.0, 0.0, 0.7)


# ==============================================================================
# 受伤效果
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

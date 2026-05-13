# ==============================================================================
# LevelBuilder — 关卡数据 → 3D 场景的"施工队"
# ==============================================================================
# 把 LevelData（Sector/Wall/Thing 数据）转换成真实的 3D 节点。
# 支持双向转换：build() 生成场景，serialize() 反向提取数据。
# ==============================================================================

class_name LevelBuilder extends Node3D

# 预加载敌人相关类
const ImpClass = preload("res://scripts/enemy/imp.gd")
const SoldierClass = preload("res://scripts/enemy/demon_soldier.gd")
const SectorClass = preload("res://scripts/level/data/sector.gd")
const WallDefClass = preload("res://scripts/level/data/wall_def.gd")
const ThingDefClass = preload("res://scripts/level/data/thing_def.gd")


# ==============================================================================
# 属性
# ==============================================================================

@export var level_data: LevelData

## 玩家出生点——build() 后从这里读取 spawn 位置
var player_spawn: Transform3D = Transform3D.IDENTITY

## EnemyManager 引用——生成敌人时用
var enemy_manager: Node = null

## 内部——扇区索引到 AABB 的映射（供后续可见性剔除使用）
var _sector_bounds: Dictionary = {}


# ==============================================================================
# build() — 主流程：清空旧场景 → 建造扇区 → 放置实体
# ==============================================================================
func build() -> void:
	# 清空旧几何体
	for child in get_children():
		child.queue_free()
	_sector_bounds.clear()

	if level_data == null:
		push_warning("LevelBuilder: 没有 LevelData，无法建造")
		return

	# 建造所有扇区
	for i in range(level_data.sectors.size()):
		_build_sector(level_data.sectors[i], i)

	# 放置所有实体
	for thing in level_data.things:
		_place_thing(thing)


# ==============================================================================
# _build_sector(sector, index) — 建造一个扇区
# ==============================================================================
func _build_sector(sector: SectorClass, index: int) -> void:
	# 扇区容器节点
	var container := Node3D.new()
	container.name = "Sector_%d" % index
	add_child(container)

	# 计算包围盒
	var bounds := _calc_aabb(sector.walls, sector.floor_height, sector.ceiling_height)
	_sector_bounds[index] = bounds

	# 生成地板
	_build_floor(sector, bounds, container)

	# 生成天花板
	_build_ceiling(sector, bounds, container)

	# 生成墙壁
	for wall in sector.walls:
		_build_wall(wall, sector.floor_height, sector.ceiling_height, container)

	# 生成灯光
	_build_light(sector, bounds, container)


# ==============================================================================
# _calc_aabb(walls, floor_h, ceiling_h) — 计算墙顶点的包围盒
# ==============================================================================
func _calc_aabb(walls: Array, floor_h: float, ceiling_h: float) -> AABB:
	if walls.is_empty():
		return AABB(Vector3.ZERO, Vector3(1, ceiling_h - floor_h, 1))

	var min_x := INF
	var min_z := INF
	var max_x := -INF
	var max_z := -INF

	for wall in walls:
		var w: WallDefClass = wall
		min_x = min(min_x, w.start.x, w.end.x)
		min_z = min(min_z, w.start.y, w.end.y)  # WallDef 中 Vector2.y = Z轴
		max_x = max(max_x, w.start.x, w.end.x)
		max_z = max(max_z, w.start.y, w.end.y)

	var center := Vector3(
		(min_x + max_x) / 2.0,
		(floor_h + ceiling_h) / 2.0,
		(min_z + max_z) / 2.0
	)
	var size := Vector3(max_x - min_x, ceiling_h - floor_h, max_z - min_z)
	return AABB(center, size)


# ==============================================================================
# _build_floor(sector, bounds, parent) — 生成地板
# ==============================================================================
func _build_floor(sector: SectorClass, bounds: AABB, parent: Node3D) -> void:
	var thickness := 0.2
	var box := CSGBox3D.new()
	box.name = "Floor"
	box.position = Vector3(bounds.position.x, sector.floor_height - thickness / 2.0, bounds.position.z)
	box.size = Vector3(bounds.size.x, thickness, bounds.size.z)
	box.material_override = _make_material(Color(0.3, 0.28, 0.25))
	box.use_collision = true
	parent.add_child(box)


# ==============================================================================
# _build_ceiling(sector, bounds, parent) — 生成天花板
# ==============================================================================
func _build_ceiling(sector: SectorClass, bounds: AABB, parent: Node3D) -> void:
	var thickness := 0.2
	var box := CSGBox3D.new()
	box.name = "Ceiling"
	box.position = Vector3(bounds.position.x, sector.ceiling_height + thickness / 2.0, bounds.position.z)
	box.size = Vector3(bounds.size.x, thickness, bounds.size.z)
	box.material_override = _make_material(Color(0.35, 0.33, 0.3))
	box.use_collision = true
	parent.add_child(box)


# ==============================================================================
# _build_wall(wall, floor_h, ceiling_h, parent) — 生成一面墙壁
# ==============================================================================
# 把 WallDef 的 2D 线段（start→end）转成 3D 的薄 CSGBox3D。
#
# WallDef 坐标：Vector2(start.x, start.y) 中，x=X轴位置，y=Z轴位置
# 墙壁从 floor_h 延伸到 ceiling_h
func _build_wall(wall: WallDefClass, floor_h: float, ceiling_h: float, parent: Node3D) -> void:
	var thickness := 0.3  # 墙壁厚度

	# 线段的中点（XZ 平面）
	var mid_x: float = (wall.start.x + wall.end.x) / 2.0
	var mid_z: float = (wall.start.y + wall.end.y) / 2.0  # Vector2.y = Z轴

	# 线段长度和方向
	var dx: float = wall.end.x - wall.start.x
	var dz: float = wall.end.y - wall.start.y  # Vector2.y = Z轴
	var length := sqrt(dx * dx + dz * dz)

	if length < 0.01:
		return  # 太短，跳过

	var height := ceiling_h - floor_h
	var y := (floor_h + ceiling_h) / 2.0

	var box := CSGBox3D.new()
	box.name = "Wall"
	box.position = Vector3(mid_x, y, mid_z)
	box.size = Vector3(length, height, thickness)

	# 旋转墙壁使盒子的 X 轴（长边）与线段方向对齐
	# Vector2(dx, -dz).angle() 算出 Godot Y 轴旋转所需的弧度
	box.rotation.y = Vector2(dx, -dz).angle()

	# 材质——Portal 墙壁用半透明颜色示意
	if wall.portal_to >= 0:
		box.material_override = _make_material(Color(0.3, 0.6, 0.3, 0.5))
	else:
		box.material_override = _make_material(Color(0.45, 0.42, 0.38))

	# 碰撞——实墙有碰撞，Portal 无碰撞（玩家可穿过）
	box.use_collision = (wall.portal_to < 0)

	parent.add_child(box)


# ==============================================================================
# _build_light(sector, bounds, parent) — 根据 light_level 建灯光
# ==============================================================================
func _build_light(sector: SectorClass, bounds: AABB, parent: Node3D) -> void:
	# 在扇区中心上方放置点光源
	var light := OmniLight3D.new()
	light.name = "SectorLight"
	light.position = Vector3(bounds.position.x, sector.ceiling_height - 0.5, bounds.position.z)
	light.light_energy = sector.light_level / 255.0 * 1.5
	# 使用默认光照范围，由 light_energy 控制亮度
	parent.add_child(light)


# ==============================================================================
# _place_thing(thing) — 放置实体
# ==============================================================================
func _place_thing(thing: ThingDefClass) -> void:
	match thing.type:
		ThingDef.Type.PLAYER_START:
			_place_player_start(thing)
		ThingDef.Type.ENEMY:
			_place_enemy(thing)
		ThingDef.Type.PICKUP:
			_place_pickup(thing)
		ThingDef.Type.DECORATION:
			_place_decoration(thing)


# ==============================================================================
# _place_player_start(thing) — 记录玩家出生点
# ==============================================================================
func _place_player_start(thing: ThingDefClass) -> void:
	var pos: Vector3 = thing.position
	player_spawn = Transform3D(
		Basis.from_euler(Vector3(0, deg_to_rad(thing.angle), 0)),
		pos
	)


# ==============================================================================
# _place_enemy(thing) — 生成敌人
# ==============================================================================
func _place_enemy(thing: ThingDefClass) -> void:
	if enemy_manager == null:
		push_warning("LevelBuilder: 没有 EnemyManager 引用，跳过敌人生成")
		return

	var subtype: String = thing.subtype
	var enemy_class: GDScript
	var data_path: String

	match subtype:
		"imp":
			enemy_class = ImpClass
			data_path = "res://assets/enemies/imp.tres"
		"demon_soldier":
			enemy_class = SoldierClass
			data_path = "res://assets/enemies/demon_soldier.tres"
		_:
			push_warning("LevelBuilder: 未知敌人类型 '%s'" % subtype)
			return

	var enemy_data := load(data_path)
	if enemy_data == null:
		push_warning("LevelBuilder: 无法加载敌人数据 '%s'" % data_path)
		return

	enemy_manager.spawn_enemy(enemy_class, thing.position, enemy_data)


# ==============================================================================
# _place_pickup(thing) — 放置拾取物占位
# ==============================================================================
func _place_pickup(thing: ThingDefClass) -> void:
	var color: Color
	match thing.subtype:
		"health_bonus":
			color = Color(0.2, 0.4, 1.0)
		"armor_bonus":
			color = Color(0.2, 0.9, 0.3)
		_:
			color = Color(1.0, 0.85, 0.2)  # weapon 等，黄色

	var box := CSGBox3D.new()
	box.name = "Pickup_" + thing.subtype
	box.position = thing.position + Vector3(0, 0.3, 0)
	box.size = Vector3(0.3, 0.3, 0.3)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.5
	box.material_override = mat
	box.use_collision = false
	add_child(box)


# ==============================================================================
# _place_decoration(thing) — 放置装饰物占位
# ==============================================================================
func _place_decoration(thing: ThingDefClass) -> void:
	match thing.subtype:
		"pillar":
			var box := CSGBox3D.new()
			box.name = "Decoration_Pillar"
			box.position = thing.position
			box.size = Vector3(0.8, 4.0, 0.8)
			box.material_override = _make_material(Color(0.5, 0.35, 0.3))
			box.use_collision = true
			add_child(box)
		"torch":
			# 火把——小方块 + 发光
			var body := CSGBox3D.new()
			body.name = "Decoration_Torch"
			body.position = thing.position + Vector3(0, 1.5, 0)
			body.size = Vector3(0.2, 1.0, 0.2)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.6, 0.3, 0.1)
			body.material_override = mat
			body.use_collision = false
			add_child(body)
		_:
			# 未知装饰——小方块
			var box := CSGBox3D.new()
			box.name = "Decoration_" + thing.subtype
			box.position = thing.position
			box.size = Vector3(0.4, 0.4, 0.4)
			box.material_override = _make_material(Color(0.5, 0.5, 0.5))
			box.use_collision = false
			add_child(box)


# ==============================================================================
# _make_material(color) — 创建纯色标准材质
# ==============================================================================
func _make_material(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.9
	return mat


# ==============================================================================
# serialize(scene_root) — 从 3D 场景反向提取 LevelData
# ==============================================================================
static func serialize(scene_root: Node3D) -> LevelData:
	var data := LevelData.new()

	# 遍历所有子节点，找到 Sector_N 容器
	for child in scene_root.get_children():
		if child.name.begins_with("Sector_"):
			var sector := _extract_sector(child)
			if sector != null:
				data.sectors.append(sector)
		# ThingDef 是数据类（非 Node），不会出现在场景树中，跳过

	# 元数据保留默认值
	data.metadata["name"] = "从场景序列化"

	return data


# ==============================================================================
# _extract_sector(container) — 从场景节点提取扇区数据
# ==============================================================================
static func _extract_sector(container: Node) -> Sector:
	var sector := SectorClass.new()

	var floor_h := 0.0
	var ceiling_h := 4.0
	var walls: Array = []

	for child in container.get_children():
		if child is CSGBox3D:
			var box: CSGBox3D = child
			match child.name:
				"Floor":
					floor_h = box.position.y + box.size.y / 2.0
				"Ceiling":
					ceiling_h = box.position.y - box.size.y / 2.0
				"Wall":
					var wall := _extract_wall(box, floor_h, ceiling_h)
					if wall != null:
						walls.append(wall)
		elif child is OmniLight3D:
			var light: OmniLight3D = child
			sector.light_level = clamp(light.light_energy / 1.5 * 255.0, 0, 255)

	sector.floor_height = floor_h
	sector.ceiling_height = ceiling_h
	sector.walls = walls
	return sector


# ==============================================================================
# _extract_wall(box, floor_h, ceiling_h) — 从 CSGBox3D 提取 WallDef
# ==============================================================================
static func _extract_wall(box: CSGBox3D, _floor_h: float, _ceiling_h: float) -> WallDef:
	var wall := WallDefClass.new()

	# 墙壁盒子的中心在 XZ 平面上，size.x = 沿墙长度，size.z = 厚度
	var half_length := box.size.x / 2.0
	var angle_rad := deg_to_rad(box.rotation_degrees.y)

	# 线段方向 = 沿墙壁的方向（perpendicular to Z-axis in box space）
	var dir_x := sin(angle_rad)
	var dir_z := cos(angle_rad)

	wall.start = Vector2(
		box.position.x - dir_x * half_length,
		box.position.z - dir_z * half_length
	)
	wall.end = Vector2(
		box.position.x + dir_x * half_length,
		box.position.z + dir_z * half_length
	)

	wall.portal_to = -1 if box.use_collision else 0
	return wall

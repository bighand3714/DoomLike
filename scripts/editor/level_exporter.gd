# ==============================================================================
# LevelExporter — 关卡导出工具
# ==============================================================================
# 把 Godot 3D 编辑器中搭建的 CSG 关卡导出为 LevelData（.tres 文件）。
#
# 命名约定（在 Godot 编辑器中给节点起的名字）：
#   墙壁     Wall_xxx     → CSGBox3D，薄长方体，有碰撞。xxx 可自定义。
#   门洞     Portal_N_xxx → CSGBox3D，通向扇区 N 的开口，无碰撞。
#   地板     Floor_xxx    → CSGBox3D，水平面板，Y 位置 = 地板高度。
#   天花板   Ceiling_xxx  → CSGBox3D，水平面板，Y 位置 = 天花板底部。
#   出生点   PlayerStart  → Node3D，玩家出现位置。
#   敌人     Enemy_xxx    → Node3D，xxx=子类型（imp / demon_soldier）。
#   拾取物   Pickup_xxx   → Node3D，xxx=子类型（暂未实现）。
#   装饰物   Deco_xxx     → Node3D，xxx=子类型（pillar / torch）。
#
# 使用方式：
#   1. 在 Godot 编辑器中往 Level 节点下放 CSGBox3D + Node3D，按约定命名
#   2. 运行游戏 → main.gd 检测到 CSG 几何体 → 调用 LevelExporter
#   3. 生成 LevelData → 保存为 .tres → 后续正常加载 .tres
# ==============================================================================

class_name LevelExporter extends RefCounted

const SectorClass = preload("res://scripts/level/data/sector.gd")
const WallDefClass = preload("res://scripts/level/data/wall_def.gd")
const ThingDefClass = preload("res://scripts/level/data/thing_def.gd")


# ==============================================================================
# export_from_scene(scene_root) — 主入口：扫描场景树 → 生成 LevelData
# ==============================================================================
# 参数：
#   scene_root —— Level 节点，关卡几何体的根节点
#   save_path  —— .tres 文件的保存路径（如 "res://assets/levels/my_level.tres"）
#
# 返回：
#   生成的 LevelData 对象（同时也保存到了磁盘）
static func export_from_scene(scene_root: Node3D, save_path: String = "") -> LevelData:
	print("[LevelExporter] 开始扫描关卡...")

	var data := LevelData.new()
	# 检测 LevelName_xxx 节点——用节点名作为关卡文件名
	var level_name := "编辑器关卡"
	for child in scene_root.get_children():
		if child.name.begins_with("LevelName_"):
			level_name = child.name.substr(10)  # 去掉 "LevelName_" 前缀
			break
	data.metadata["name"] = level_name
	data.metadata["author"] = ""

	# === 第一步：按父节点分组，识别扇区 ===
	# 如果 Level 下有名为 Sector_N 的 Node3D 子节点，则每个 Sector_N 对应一个扇区
	# 否则所有墙壁归入同一个默认扇区
	var sector_groups: Array[Node3D] = []
	for child in scene_root.get_children():
		if child is Node3D and child.name.begins_with("Sector_"):
			sector_groups.append(child)

	# 没有显式扇区分组 → 所有墙壁归入一个默认扇区
	var use_default_sector := sector_groups.is_empty()
	if use_default_sector:
		sector_groups.append(scene_root)  # 直接在 Level 根下找墙壁

	# === 第二步：遍历每个扇区组，提取墙壁和尺寸信息 ===
	for group in sector_groups:
		var sector := SectorClass.new()
		sector.light_level = 160  # 默认亮度

		# 收集该组下所有 Wall_ / Portal_ / Floor_ / Ceiling_ 节点
		_scan_group(group, sector)

		if sector.walls.is_empty():
			print("[LevelExporter] 警告：扇区无墙壁，跳过")
			continue

		data.sectors.append(sector)

	# === 第三步：扫描实体标记节点 ===
	_scan_entities(scene_root, data)

	# === 第四步：输出统计信息 ===
	print("[LevelExporter] 导出完成：%d 扇区, %d 实体" % [data.sectors.size(), data.things.size()])
	for i in range(data.sectors.size()):
		var s: SectorClass = data.sectors[i]
		print("[LevelExporter]   扇区 %d：%d 面墙, 地板 %.1f, 天花板 %.1f, 亮度 %d" % [
			i, s.walls.size(), s.floor_height, s.ceiling_height, s.light_level
		])

	# === 第五步：保存为 .tres 文件 ===
	if not save_path.is_empty():
		var err := ResourceSaver.save(data, save_path)
		if err == OK:
			print("[LevelExporter] 关卡已保存: " + save_path)
		else:
			printerr("[LevelExporter] 保存失败！错误码: " + str(err))

	return data


# ==============================================================================
# _scan_group(parent, sector) — 扫描一个节点组，提取墙壁/地板/天花板信息
# ==============================================================================
static func _scan_group(parent: Node, sector: SectorClass) -> void:
	for child in parent.get_children():
		var name: String = child.name

		# --- 墙壁：Wall_xxx（只处理 CSGBox3D）---
		if name.begins_with("Wall_") and child is CSGBox3D:
			_add_wall_from_box(child as CSGBox3D, sector, -1)

		# --- 门洞：Portal_N_xxx（N = 通向的扇区编号）---
		elif name.begins_with("Portal_") and child is CSGBox3D:
			var portal_to: int = _extract_portal_index(name)
			_add_wall_from_box(child as CSGBox3D, sector, portal_to)

		# --- 地板：Floor_xxx（取最高的那个作为地板）---
		elif name.begins_with("Floor_") and child is Node3D:
			var y: float = child.global_position.y
			if child is CSGBox3D:
				y += (child as CSGBox3D).size.y / 2.0  # CSG 盒子顶部 = 地板表面
			if y > sector.floor_height:
				sector.floor_height = y

		# --- 天花板：Ceiling_xxx（取最低的那个作为天花板）---
		elif name.begins_with("Ceiling_") and child is Node3D:
			var y: float = child.global_position.y
			if child is CSGBox3D:
				y -= (child as CSGBox3D).size.y / 2.0  # CSG 盒子底部 = 天花板下沿
			# 第一个天花板节点设定高度，后续取更低的
			if sector.ceiling_height == 4.0 or y < sector.ceiling_height:
				sector.ceiling_height = y

		# 递归扫描子节点（支持嵌套结构）
		if child.get_child_count() > 0:
			_scan_group(child, sector)


# ==============================================================================
# _add_wall_from_box(box, sector, portal_to) — 从 CSGBox3D 创建 WallDef
# ==============================================================================
# CSGBox3D 的墙壁：
#   - size.x = 墙壁长度（沿墙方向）
#   - size.y = 墙壁高度
#   - size.z = 墙壁厚度
#   - 墙壁沿盒子的局部 X 轴方向延伸
#
# 转换思路：
#   1. 取盒子局部坐标下的左右端点：(-size.x/2, 0, 0) 和 (+size.x/2, 0, 0)
#   2. 用盒子的全局变换 matrix 转换到世界坐标
#   3. 提取 XZ 分量作为 WallDef 的 start 和 end
static func _add_wall_from_box(box: CSGBox3D, sector: SectorClass, portal_to: int) -> void:
	# 获取全局变换矩阵
	var t := box.global_transform

	# 墙壁的两个端点（在盒子的局部空间中）
	var half_length := box.size.x / 2.0
	var local_start := Vector3(-half_length, 0.0, 0.0)
	var local_end := Vector3(half_length, 0.0, 0.0)

	# 转换到世界空间
	var world_start := t * local_start
	var world_end := t * local_end

	# 创建墙壁定义（2D 线段）
	var wall := WallDefClass.new()
	wall.start = Vector2(world_start.x, world_start.z)
	wall.end = Vector2(world_end.x, world_end.z)
	wall.portal_to = portal_to

	sector.walls.append(wall)


# ==============================================================================
# _scan_entities(root, data) — 扫描实体标记节点 → 生成 ThingDef
# ==============================================================================
# 实体用普通 Node3D 节点标记，靠节点名识别类型。
# 位置和朝向直接从节点的 global_transform 提取。
static func _scan_entities(root: Node, data: LevelData) -> void:
	_scan_entities_recursive(root, data)


static func _scan_entities_recursive(node: Node, data: LevelData) -> void:
	for child in node.get_children():
		var name: String = child.name

		# 只处理 Node3D 类型的标记节点
		if not child is Node3D:
			if child.get_child_count() > 0:
				_scan_entities_recursive(child, data)
			continue

		var child_3d: Node3D = child as Node3D

		# --- 玩家出生点 ---
		if name == "PlayerStart":
			var thing := _make_thing(ThingDefClass.Type.PLAYER_START, &"", child_3d)
			data.things.append(thing)
			print("[LevelExporter]   找到出生点: (%.1f, %.1f, %.1f)" % [
				thing.position.x, thing.position.y, thing.position.z
			])

		# --- 敌人：Enemy_子类型 ---
		elif name.begins_with("Enemy_"):
			var subtype: String = name.substr(6)  # 去掉 "Enemy_" 前缀
			var thing := _make_thing(ThingDefClass.Type.ENEMY, subtype, child_3d)
			data.things.append(thing)
			print("[LevelExporter]   找到敌人 %s: (%.1f, %.1f, %.1f)" % [
				subtype, thing.position.x, thing.position.y, thing.position.z
			])

		# --- 拾取物：Pickup_子类型 ---
		elif name.begins_with("Pickup_"):
			var subtype: String = name.substr(7)
			var thing := _make_thing(ThingDefClass.Type.PICKUP, subtype, child_3d)
			data.things.append(thing)

		# --- 装饰物：Deco_子类型 ---
		elif name.begins_with("Deco_"):
			var subtype: String = name.substr(5)
			var thing := _make_thing(ThingDefClass.Type.DECORATION, subtype, child_3d)
			data.things.append(thing)

		# 递归子节点
		if child.get_child_count() > 0:
			_scan_entities_recursive(child, data)


# ==============================================================================
# _make_thing(type, subtype, node) — 从标记节点创建 ThingDef
# ==============================================================================
static func _make_thing(type: int, subtype: StringName, node: Node3D) -> ThingDef:
	var thing := ThingDefClass.new()
	thing.type = type as ThingDef.Type
	thing.subtype = subtype
	thing.position = node.global_position
	thing.angle = node.global_rotation.y   # 取绕 Y 轴的旋转角度
	return thing


# ==============================================================================
# _extract_portal_index(name) — 从 "Portal_N_xxx" 提取扇区编号 N
# ==============================================================================
# 例如 "Portal_0_door" → 0，"Portal_1_gate" → 1
# 格式：Portal_<数字>_<描述>
static func _extract_portal_index(name: String) -> int:
	var parts := name.split("_")
	# parts = ["Portal", "N", "xxx"]
	if parts.size() >= 2:
		return int(parts[1])  # parts[1] 是扇区编号
	return -1


# ==============================================================================
# has_editor_geometry(root) — 检查场景中是否存在编辑器搭建的关卡几何体
# ==============================================================================
# main.gd 用这个函数判断是否需要导出。
static func has_editor_geometry(root: Node3D) -> bool:
	# 检测 Level 下是否有人工放置的关卡内容
	# 三种情况都算"编辑器关卡"：
	#   1. CSGBox3D 子节点（墙壁/地板/天花板）
	#   2. LevelName_ 开头的节点（关卡元数据）
	#   3. PlayerStart 或 Enemy_ 开头的标记节点
	for child in root.get_children():
		if child is CSGBox3D:
			return true
		if child.name.begins_with("LevelName_"):
			return true
		if child.name == "PlayerStart" or child.name.begins_with("Enemy_"):
			return true
	return false

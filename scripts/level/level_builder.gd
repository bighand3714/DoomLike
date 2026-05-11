# ==============================================================================
# LevelBuilder — 关卡数据 → 3D 场景的"施工队"
# ==============================================================================
# 这个类负责把 LevelData（数据蓝图）转换成真实的 3D 节点（墙壁、地板、灯光）。
# 它理解 Sector/Wall/Thing 数据，并生成对应的 3D 模型。
#
# 另一个方向也重要：serialize() 方法可以把 3D 场景反向提取回 LevelData——
# 这是地图编辑器的核心功能（编完场景 → 导出关卡文件）。
#
# ⚠ 第一阶段：只定义接口（API），实际生成逻辑在后续阶段实现。
#    目前用 CSGBox3D 直接搭测试关卡，不走这个管线。
# ==============================================================================

# extends Node3D 意味着它是一个 3D 节点，可以挂在场景里作为子节点
class_name LevelBuilder extends Node3D


# ==============================================================================
# 属性
# ==============================================================================

## 要建造的关卡数据。在编辑器中拖入一个 LevelData 资源文件（.tres）即可。
@export var level_data: LevelData


# ==============================================================================
# build() — 根据 LevelData 创建所有 3D 几何体
# ==============================================================================
# 调用流程：
#   1. 清空之前建造的旧几何体（防止重复建造）
#   2. 遍历所有扇区，为每个扇区创建地板、天花板、墙壁
#   3. 遍历所有"东西"，放置实体（玩家出生点、怪物等）
func build() -> void:
	# 第一步：清掉旧节点
	# get_children() 返回这个节点的所有直接子节点
	# queue_free() 把节点标记为"待删除"——会在当前帧末尾安全删除
	for child in get_children():
		child.queue_free()

	# 安全检查：如果没设置 level_data，打印警告并退出
	if level_data == null:
		push_warning("LevelBuilder: no LevelData assigned")
		return

	# 第二步：建造所有扇区
	for sector in level_data.sectors:
		_build_sector(sector)

	# 第三步：放置所有东西
	for thing in level_data.things:
		_place_thing(thing)


# ==============================================================================
# _build_sector() — 根据一个扇区数据建造其 3D 几何体
# ==============================================================================
# 这是最核心的方法——把 Sector 数据变成看得见的 3D 模型。
# 要做的事情：
#   1. 生成地板面（给定高度和纹理）
#   2. 生成天花板面（给定高度和纹理）
#   3. 遍历墙壁列表，为每段墙生成一个四边形面片
#   4. 设置光照（light_level → 灯光/环境光）
#
# TODO: Phase 2+ 实现具体生成逻辑。
# pass 意思是"什么都不做"——占位符，防止空函数报错。
func _build_sector(sector: LevelData.Sector) -> void:
	pass


# ==============================================================================
# _place_thing() — 在场景中放置一个"东西"
# ==============================================================================
# match 是 GDScript 的"多路分支"语句（类似其他语言的 switch）。
# 不同类型的东西处理方式不同：
#   PLAYER_START → 设置玩家出生点
#   ENEMY → 生成敌人
#   PICKUP → 放置拾取物
#   DECORATION → 放置装饰模型
#
# TODO: Phase 2+ 实现各类实体的生成。
func _place_thing(thing: LevelData.ThingDef) -> void:
	match thing.type:
		LevelData.ThingDef.Type.PLAYER_START:
			pass  # TODO: 发射信号 / 设置出生点
		LevelData.ThingDef.Type.ENEMY:
			pass  # TODO: 生成敌人实例
		LevelData.ThingDef.Type.PICKUP:
			pass  # TODO: 生成拾取物实例
		LevelData.ThingDef.Type.DECORATION:
			pass  # TODO: 生成装饰物实例


# ==============================================================================
# serialize() — 把 3D 场景"逆向提取"回 LevelData
# ==============================================================================
# 这是地图编辑器的核心导出功能。
# 编辑器里用户搭好场景后，调用这个静态方法把场景解析成 LevelData，
# 然后可以保存为 .tres 文件，下次加载就能重现。
#
# static 关键字表示这个方法属于"类本身"而不是"某个实例"。
# 可以这样调用：LevelBuilder.serialize(some_scene_root)
# 不需要先创建 LevelBuilder 对象。
#
# TODO: Phase 4 实现具体提取逻辑。
static func serialize(_scene_root: Node3D) -> LevelData:
	var data := LevelData.new()
	# 这里将来会遍历场景中的所有节点，
	# 把符合 Sector/Wall/Thing 结构的几何体提取成数据
	return data

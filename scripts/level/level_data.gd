# ==============================================================================
# LevelData — 关卡数据容器
# ==============================================================================
# 包含扇区(Sector)、墙壁(WallDef)、实体(ThingDef)等数据。
# 这些子类型已拆分为独立文件：scripts/level/data/ 下
# ==============================================================================

class_name LevelData extends Resource

const WallDefClass = preload("res://scripts/level/data/wall_def.gd")


## 扇区列表——关卡里所有房间
@export var sectors: Array = []

## 实体列表——关卡里所有可交互的东西
@export var things: Array = []

## 元数据——关卡描述信息
@export var metadata := {
	name = "Untitled",
	author = "",
	bgm = ""
}

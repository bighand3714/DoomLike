# ==============================================================================
# ThingDef — 实体放置点的数据定义
# ==============================================================================
class_name ThingDef extends Resource

## 实体类别
enum Type {
	PLAYER_START,   # 玩家出生点
	ENEMY,          # 敌人/怪物
	PICKUP,         # 可拾取物品
	DECORATION      # 纯装饰
}

## 实体类型
@export var type: Type = Type.PLAYER_START

## 3D 位置
@export var position := Vector3.ZERO

## 朝向角度（度数）
@export var angle := 0.0

## 子类型（如 "imp"、"demon_soldier"、"pillar"）
@export var subtype: StringName = &""

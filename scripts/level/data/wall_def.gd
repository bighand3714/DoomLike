# ==============================================================================
# WallDef — 一面墙壁的数据定义
# ==============================================================================
class_name WallDef extends Resource

## 墙壁起点（2D 坐标，DOOM 地图本质是 2D 平面）
@export var start := Vector2.ZERO

## 墙壁终点
@export var end := Vector2.ZERO

## 上方纹理（当天花板比邻居高时可见）
@export var texture_upper: StringName = &""

## 中间纹理（门洞/窗口区域）
@export var texture_middle: StringName = &""

## 下方纹理（当地板比邻居低时可见）
@export var texture_lower: StringName = &""

## -1 = 实心墙（撞上去会挡住），>=0 = 通向第 N 号扇区的门洞
@export var portal_to := -1

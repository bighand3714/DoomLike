# ==============================================================================
# Sector — 关卡的扇区（房间/区域）数据定义
# ==============================================================================
class_name Sector extends Resource

## 地板距地高度（0 = 地面）
@export var floor_height := 0.0

## 天花板高度
@export var ceiling_height := 4.0

## 地板纹理路径
@export var floor_texture: StringName = &""

## 天花板纹理路径
@export var ceiling_texture: StringName = &""

## 亮度（0=全黑, 255=最亮）
@export var light_level := 160

## 围成这个扇区的所有墙壁
@export var walls: Array[WallDef] = []

# ==============================================================================
# WaveData — 波次刷怪配置资源
# ==============================================================================
class_name WaveData extends Resource

## 波次编号（从 1 开始）
@export var wave_number: int = 1

## 敌人条目列表 [{enemy_id: "orc_melee", count: 5}, ...]
@export var enemy_entries: Array[Dictionary] = []

## 波内生成间隔（秒）
@export var spawn_interval: float = 2.0

## 波间休息时间（秒）
@export var rest_time: float = 8.0

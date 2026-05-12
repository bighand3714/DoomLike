# ==============================================================================
# EnemyManager — 敌人生成与管理
# ==============================================================================
# 挂在 Level 节点下，负责：
#   1. 实例化敌人到场景中
#   2. 追踪存活敌人列表
#   3. 检测是否所有敌人已死亡（all_clear）
#   4. 统计总击杀数
# ==============================================================================

class_name EnemyManager extends Node

# 预加载依赖的类——解决 Godot 跨文件 class_name 解析顺序问题
const EnemyClass = preload("res://scripts/enemy/enemy.gd")
const EnemyDataClass = preload("res://scripts/enemy/enemy_data.gd")


# ==============================================================================
# 信号
# ==============================================================================

## 所有敌人都死亡时发射
signal all_cleared()

## 每次击杀敌人时发射（供 HUD 更新击杀计数）
signal enemy_killed(enemy_name: String)


# ==============================================================================
# 属性
# ==============================================================================

## 当前存活的敌人列表
var active_enemies: Array = []

## 总击杀数
var total_kills: int = 0


# ==============================================================================
# spawn_enemy(enemy_class, position, enemy_data) — 生成一个敌人
# ==============================================================================
# 参数：
#   enemy_class — GDScript 类引用（如 preload("res://scripts/enemy/imp.gd")）
#   position    — 出生位置（世界坐标）
#   enemy_data  — 敌人配置数据（Resource，实际是 EnemyData）
func spawn_enemy(enemy_class: GDScript, position: Vector3, enemy_data: Resource) -> Node:
	var enemy: Node = enemy_class.new()
	if enemy == null:
		push_error("EnemyManager: 无法创建敌人实例")
		return null

	# 先加入场景树（才能设置 global_position）
	add_child(enemy)

	# 注入配置数据（EnemyData Resource）
	enemy.set("enemy_data", enemy_data)
	enemy.set("global_position", position)
	enemy.connect("enemy_died", _on_enemy_died)

	active_enemies.append(enemy)

	return enemy


# ==============================================================================
# _on_enemy_died(enemy) — 敌人死亡回调
# ==============================================================================
func _on_enemy_died(enemy: Node) -> void:
	active_enemies.erase(enemy)
	total_kills += 1

	var enemy_name: String = enemy.get("enemy_data").get("enemy_name") if enemy.get("enemy_data") != null else "未知敌人"
	enemy_killed.emit(enemy_name)

	# 检查是否清场
	if active_enemies.is_empty():
		print("[EnemyManager] 所有敌人已被消灭！")
		all_cleared.emit()


# ==============================================================================
# is_all_cleared() — 查询是否已清场
# ==============================================================================
func is_all_cleared() -> bool:
	return active_enemies.is_empty()

# ==============================================================================
# EnemyManager — 敌人生成与管理
# ==============================================================================
# 挂在 Level 节点下，负责实例化、追踪、统计。
#
# Phase 5.11：enemy_killed 信号携带 score_value，
# main.gd 直接读取分数而非硬编码 10 分。
# ==============================================================================

class_name EnemyManager extends Node

const EnemyClass = preload("res://scripts/enemy/enemy.gd")
const EnemyDataClass = preload("res://scripts/enemy/enemy_data.gd")


# ==============================================================================
# 信号
# ==============================================================================

signal all_cleared()

## 每次击杀敌人时发射（Phase 5.11：新增加 score_value 参数）
signal enemy_killed(enemy_name: String, score_value: int)


# ==============================================================================
# 属性
# ==============================================================================

var active_enemies: Array = []
var total_kills: int = 0


# ==============================================================================
# _ready()
# ==============================================================================
func _ready() -> void:
	for child in get_parent().get_children():
		if child is EnemyClass:
			register_enemy(child)


# ==============================================================================
# register_enemy / unregister_enemy
# ==============================================================================
func register_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	if active_enemies.has(enemy):
		return
	if not enemy.enemy_died.is_connected(_on_enemy_died):
		enemy.enemy_died.connect(_on_enemy_died)
	active_enemies.append(enemy)

func unregister_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	if enemy.enemy_died.is_connected(_on_enemy_died):
		enemy.enemy_died.disconnect(_on_enemy_died)
	active_enemies.erase(enemy)


# ==============================================================================
# spawn_enemy
# ==============================================================================
func spawn_enemy(enemy_class: GDScript, position: Vector3, enemy_data: Resource) -> Node:
	var enemy: Node = enemy_class.new()
	if enemy == null:
		push_error("EnemyManager: 无法创建敌人实例")
		return null
	enemy.set("enemy_data", enemy_data)
	enemy.set("global_position", position)
	add_child(enemy)
	register_enemy(enemy)
	return enemy


# ==============================================================================
# _on_enemy_died — 敌人死亡回调（Phase 5.11：读取 score_value）
# ==============================================================================
func _on_enemy_died(enemy: Node) -> void:
	unregister_enemy(enemy)
	total_kills += 1

	var ed = enemy.get("enemy_data")
	var enemy_name: String = ed.get("enemy_name") if ed != null else "未知敌人"
	var score_value: int = ed.get("score_value") if ed != null else 10
	enemy_killed.emit(enemy_name, score_value)

	if active_enemies.is_empty():
		print("[EnemyManager] 所有敌人已被消灭！")
		all_cleared.emit()


func is_all_cleared() -> bool:
	return active_enemies.is_empty()


func reset() -> void:
	for enemy in active_enemies:
		if enemy.enemy_died.is_connected(_on_enemy_died):
			enemy.enemy_died.disconnect(_on_enemy_died)
	active_enemies.clear()
	total_kills = 0

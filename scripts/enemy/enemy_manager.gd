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
# _ready() — 扫描关卡中已存在的敌人并注册
# ==============================================================================
func _ready() -> void:
	# 0.6：扫描父节点下已有 Enemy 实例并注册（支持手动摆放和动态生成）
	for child in get_parent().get_children():
		if child is EnemyClass:
			register_enemy(child)


# ==============================================================================
# register_enemy(enemy) — 注册敌人到追踪列表
# ==============================================================================
# 0.6：统一的注册入口，避免重复注册和重复连接信号
func register_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	if active_enemies.has(enemy):
		return
	# 连接前先检查是否已连接，避免重复
	if not enemy.enemy_died.is_connected(_on_enemy_died):
		enemy.enemy_died.connect(_on_enemy_died)
	active_enemies.append(enemy)


# ==============================================================================
# unregister_enemy(enemy) — 从追踪列表移除敌人
# ==============================================================================
# 0.6：用于敌人死亡或关卡卸载时清理
func unregister_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	if enemy.enemy_died.is_connected(_on_enemy_died):
		enemy.enemy_died.disconnect(_on_enemy_died)
	active_enemies.erase(enemy)


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

	# 0.6：先设置数据，再 add_child，最后 register
	enemy.set("enemy_data", enemy_data)
	enemy.set("global_position", position)
	add_child(enemy)
	register_enemy(enemy)

	return enemy


# ==============================================================================
# _on_enemy_died(enemy) — 敌人死亡回调
# ==============================================================================
func _on_enemy_died(enemy: Node) -> void:
	# 0.6：使用 unregister_enemy 统一清理
	unregister_enemy(enemy)
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


# ==============================================================================
# reset() — 重置管理器状态（关卡重启/卸载时调用）
# ==============================================================================
# 重置分为三步，顺序很重要：
#
#   1. 断开所有存活敌人的 died 信号连接
#      如果不先断开，后续这些敌人死亡时会触发 _on_enemy_died()，
#      但 EnemyManager 可能已经在新关卡中管理不同的敌人了，
#      导致"旧敌人的死亡事件"污染新关卡的统计数据。
#
#   2. 清空 active_enemies 列表
#      列表清空后，is_all_cleared() 会返回 true。
#      这很重要——如果不清理，上一局残留的敌人引用会
#      让新关卡误判"还有敌人存活"。
#
#   3. 重置 total_kills 为 0
#      击杀计数需要从零开始，否则 HUD 会显示上一局的击杀数。
#      HUD 的 _kill_count 由 PlayerStatus.reset_kill_count() 单独重置。
#
# 为什么不需要删除敌人节点本身：
#   Phase 2 中，关卡卸载时会通过 queue_free() 或 remove_child()
#   统一清理关卡节点树，所有敌人实例会随关卡节点一起被销毁。
#   这里只需要清理 EnemyManager 自己维护的引用列表。
#
# 调用时机（Phase 2+）：
#   - _unload_current_level() 卸载旧关卡时
#   - _start_level() 加载新关卡之前
func reset() -> void:
	# 第一步：断开所有旧信号连接，防止"幽灵敌人"的回调污染新关卡
	for enemy in active_enemies:
		if enemy.enemy_died.is_connected(_on_enemy_died):
			enemy.enemy_died.disconnect(_on_enemy_died)
	# 第二步：清空追踪列表
	active_enemies.clear()
	# 第三步：重置击杀计数
	total_kills = 0

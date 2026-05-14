# ==============================================================================
# LavaRiver — 熔岩河流危险区（Phase 4.3+4.4）
# ==============================================================================
# 挂在 Node3D 根节点下，自动创建：
#   1. 红橙色扁平 CSGBox3D 视觉（发光材质模拟熔岩）
#   2. Area3D + CollisionShape3D 检测玩家进入/离开
#   3. _process() 中按 tick_interval 对区域内玩家造成持续伤害
#
# 伤害机制：
#   不是每帧扣血（那样太快了），而是按 tick_interval（默认 0.25 秒）
#   为周期，每次 tick 造成 damage_per_second × tick_interval 点伤害。
#   例如 18 dps × 0.25s = 4.5 点/次。
# ==============================================================================

class_name LavaRiver extends Node3D


# ==============================================================================
# 导出属性
# ==============================================================================

## 河流长度（米）——沿 Z 轴延伸
@export var river_length: float = 28.0

## 河流宽度（米）——沿 X 轴延伸
@export var river_width: float = 4.0

## 每秒伤害值
@export var damage_per_second: float = 18.0

## 伤害结算间隔（秒）——值越小扣血越平滑但计算量越大
@export var tick_interval: float = 0.25

## 视觉厚度（米）
@export var visual_height: float = 0.15


# ==============================================================================
# 内部状态
# ==============================================================================

## 当前在熔岩区域内的节点列表
var _bodies_in_lava: Array[Node] = []

## tick 累计计时器
var _tick_timer: float = 0.0


# ==============================================================================
# _ready()
# ==============================================================================
func _ready() -> void:
	_build_visual()
	_build_damage_area()
	add_to_group("hazard")


# ==============================================================================
# _build_visual() — 红橙色熔岩视觉
# ==============================================================================
func _build_visual() -> void:
	var visual := CSGBox3D.new()
	visual.name = "LavaVisual"
	visual.size = Vector3(river_width, visual_height, river_length)
	# 熔岩视觉略高于地面，防止被地面遮挡
	visual.position = Vector3(0.0, visual_height / 2.0 + 0.02, 0.0)
	visual.use_collision = false  # 视觉不参与碰撞（伤害由 Area3D 处理）

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.25, 0.05)  # 红橙色
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.05)
	mat.emission_energy_multiplier = 2.0  # 发光强度——让熔岩在暗场景中醒目
	mat.roughness = 0.3  # 低粗糙度 = 有点像光滑的岩浆表面
	visual.material = mat
	add_child(visual)


# ==============================================================================
# _build_damage_area() — 伤害检测区域
# ==============================================================================
func _build_damage_area() -> void:
	var area := Area3D.new()
	area.name = "DamageArea"

	var col := CollisionShape3D.new()
	col.name = "CollisionShape"
	var box := BoxShape3D.new()
	box.size = Vector3(river_width, 1.5, river_length)  # 高度 1.5m 覆盖玩家胶囊体
	col.shape = box
	col.position = Vector3(0.0, 0.75, 0.0)  # 碰撞体中心在玩家腰线附近
	area.add_child(col)

	# collision_layer=2 让熔岩区域本身不在默认碰撞层上，子弹射线不会撞到。
	# collision_mask=1 让 Area3D 能检测到在层 1 上的物体（玩家和敌人都在层 1）。
	area.collision_layer = 2
	area.collision_mask = 1

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)


# ==============================================================================
# _process(delta) — 持续伤害结算
# ==============================================================================
func _process(delta: float) -> void:
	if _bodies_in_lava.is_empty():
		return

	_tick_timer += delta
	if _tick_timer < tick_interval:
		return
	_tick_timer = 0.0

	var dmg_amount := damage_per_second * tick_interval
	for body in _bodies_in_lava:
		if body == null or not is_instance_valid(body):
			continue
		# 查找 Damageable 节点（可能在 body 本身或其子节点中）
		var dmg := _find_damageable(body)
		if dmg != null and not dmg.is_dead():
			dmg.take_damage(dmg_amount, WeaponData.DamageType.EXPLOSION)


# 递归查找 Damageable（先查自身，再查子节点）
func _find_damageable(node: Node) -> Damageable:
	if node is Damageable:
		return node
	for child in node.get_children():
		var found := _find_damageable(child)
		if found != null:
			return found
	return null


# ==============================================================================
# 信号回调
# ==============================================================================

func _on_body_entered(body: Node) -> void:
	if not _bodies_in_lava.has(body):
		_bodies_in_lava.append(body)

func _on_body_exited(body: Node) -> void:
	_bodies_in_lava.erase(body)

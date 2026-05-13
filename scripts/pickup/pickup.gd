# ==============================================================================
# Pickup — 拾取物基类
# ==============================================================================
# 玩家走进 Area3D 范围时自动拾取。子类覆写 _on_pickup() 决定效果。
# ==============================================================================

class_name Pickup extends Area3D

signal picked_up(by: Node3D)

@export var pickup_name: String = "物品"
@export var respawn_time: float = 0.0  # 0=不重生

var _hover_base_y: float = 0.0
var _hover_timer: float = 0.0


func _ready() -> void:
	_hover_base_y = position.y
	body_entered.connect(_on_body_entered)
	_setup_visual()


func _process(delta: float) -> void:
	# 悬浮旋转动画
	_hover_timer += delta
	position.y = _hover_base_y + sin(_hover_timer * 3.0) * 0.1
	rotation.y += delta * 2.0


func _on_body_entered(body: Node3D) -> void:
	if body.name != "Player":
		return
	_on_pickup(body)
	picked_up.emit(body)

	if respawn_time > 0.0:
		visible = false
		$CollisionShape3D.disabled = true
		await get_tree().create_timer(respawn_time).timeout
		visible = true
		$CollisionShape3D.disabled = false
	else:
		queue_free()


## 子类覆写：拾取时做什么
func _on_pickup(_player: Node3D) -> void:
	pass


## 子类覆写：创建外观
func _setup_visual() -> void:
	# 默认：白色小发光球体
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	col.shape = sphere
	col.name = "CollisionShape3D"
	add_child(col)

	var mesh := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.25
	sphere_mesh.height = 0.5
	mesh.mesh = sphere_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.emission_enabled = true
	mat.emission = Color.WHITE * 0.4
	mesh.material_override = mat
	add_child(mesh)

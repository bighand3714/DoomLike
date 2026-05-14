# ==============================================================================
# DeadTreeProp — 荒漠枯树道具（Phase 3.4）
# ==============================================================================
# 荒漠竞技场中的掩体道具，用 CSGBox3D 拼出棕色树干 + 深棕色枝干。
# 自带碰撞（CSG 的 use_collision=true），能阻挡玩家移动和子弹射线。
# 每个实例的枝干角度/长度略有随机变化，避免所有树看起来完全一样。
#
# 结构（_build_model 自动生成）：
#   DeadTreeProp (Node3D)
#   ├── Trunk (CSGBox3D)     —— 主树干，垂直
#   ├── Branch_1 (CSGBox3D)  —— 斜向上左前
#   ├── Branch_2 (CSGBox3D)  —— 斜向上右前
#   └── Branch_3 (CSGBox3D)  —— 斜向上后方
# ==============================================================================

class_name DeadTreeProp extends Node3D


# ==============================================================================
# 导出属性
# ==============================================================================

## 树干高度（米）
@export var trunk_height: float = 3.0

## 树干宽度/深度（米）——正方形截面
@export var trunk_width: float = 0.3

## 枝干数量（建议 2~4）
@export var branch_count: int = 3

## 枝干长度范围（随机在此范围内选取）
@export var branch_length_min: float = 0.6
@export var branch_length_max: float = 1.2


# ==============================================================================
# _ready()
# ==============================================================================
func _ready() -> void:
	_build_model()


# ==============================================================================
# _build_model() — 用 CSGBox3D 拼出枯树外观
# ==============================================================================
# 树干 —— 棕色粗方柱，垂直立在地面上
# 枝干 —— 深棕色细方柱，从树干中上部向外倾斜伸出
#
# 每根枝干的角度在 base_angle + 随机偏移的基础上计算，
# 这样同一关里的多棵树不会全部朝向相同。
func _build_model() -> void:
	# 随机种子基于节点实例 id，让每棵树的枝干朝向不同
	var rng := RandomNumberGenerator.new()
	rng.seed = get_instance_id()

	# --- 树干 ---
	var trunk := CSGBox3D.new()
	trunk.name = "Trunk"
	trunk.size = Vector3(trunk_width, trunk_height, trunk_width)
	trunk.position = Vector3(0.0, trunk_height / 2.0, 0.0)
	trunk.use_collision = true
	trunk.add_to_group("level_geometry")
	trunk.add_to_group("cover_prop")
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.4, 0.25, 0.1)  # 棕色
	trunk_mat.roughness = 0.95
	trunk.material = trunk_mat
	add_child(trunk)

	# --- 枝干 ---
	for i in range(branch_count):
		var branch := CSGBox3D.new()
		branch.name = "Branch_%d" % (i + 1)

		# 枝干长宽：长条状，比树干细
		var length := rng.randf_range(branch_length_min, branch_length_max)
		branch.size = Vector3(0.12, 0.12, length)

		# 枝干起始位置：树干中上部（0.5~0.8 倍树干高度）
		var attach_y := trunk_height * rng.randf_range(0.5, 0.8)
		branch.position = Vector3(0.0, attach_y, 0.0)

		# 枝干角度：从垂直方向向外倾斜 30~60 度，水平方向均匀分布
		var tilt_angle := deg_to_rad(rng.randf_range(30.0, 60.0))  # 偏离垂直的角度
		var base_h_angle := TAU * float(i) / float(branch_count)  # 水平均匀分布
		var h_angle := base_h_angle + rng.randf_range(-0.3, 0.3)  # 加一点随机偏移

		# 构建旋转：先绕 Y 轴转水平角度，再绕局部 X 轴倾斜
		var y_rot := Basis(Vector3.UP, h_angle)
		var tilt_axis := y_rot * Vector3.RIGHT
		var tilt_rot := Basis(tilt_axis, tilt_angle)
		branch.transform.basis = y_rot * tilt_rot

		# 枝干位置补偿：从附着点沿枝干方向偏移一半长度
		var branch_dir := branch.transform.basis * Vector3.FORWARD
		branch.position += branch_dir * (length / 2.0)

		branch.use_collision = true
		branch.add_to_group("level_geometry")
		branch.add_to_group("cover_prop")
		var branch_mat := StandardMaterial3D.new()
		branch_mat.albedo_color = Color(0.25, 0.15, 0.05)  # 深棕色
		branch_mat.roughness = 0.95
		branch.material = branch_mat
		add_child(branch)

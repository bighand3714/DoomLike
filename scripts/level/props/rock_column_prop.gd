# ==============================================================================
# RockColumnProp — 柱状岩石道具（Phase 4.6）
# ==============================================================================
# 熔岩地狱中的掩体道具，用 CSGBox3D 堆叠成粗糙石柱。
# 自带碰撞（level_geometry group），能阻挡玩家移动和子弹射线。
#
# 结构（_build_model 自动生成）：
#   RockColumnProp (Node3D)
#   ├── Segment_1 (CSGBox3D) —— 底部宽大
#   ├── Segment_2 (CSGBox3D) —— 中间
#   └── Segment_3 (CSGBox3D) —— 顶部略窄
#
# 每段略微旋转/缩放，模拟天然岩石的不规则外观。
# ==============================================================================

class_name RockColumnProp extends Node3D


# ==============================================================================
# 导出属性
# ==============================================================================

## 石柱总高度（米）
@export var column_height: float = 3.5

## 石柱基础宽度/深度（米）
@export var column_width: float = 0.8

## 段数——堆叠的方块数量（建议 3~5）
@export var segment_count: int = 3


# ==============================================================================
# _ready()
# ==============================================================================
func _ready() -> void:
	_build_model()


# ==============================================================================
# _build_model() — 堆叠 CSGBox3D 段形成岩石柱
# ==============================================================================
func _build_model() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = get_instance_id()

	var seg_height := column_height / float(segment_count)

	for i in range(segment_count):
		var seg := CSGBox3D.new()
		seg.name = "Segment_%d" % (i + 1)

		# 每段宽度随机偏移 ±15%，越高越窄（模拟自然岩柱上细下粗）
		var width_factor := rng.randf_range(0.85, 1.15) * (1.0 - float(i) * 0.12)
		seg.size = Vector3(column_width * width_factor, seg_height, column_width * width_factor)

		# Y 位置：从底部逐段堆叠
		seg.position = Vector3(0.0, seg_height * (float(i) + 0.5), 0.0)

		# 每段轻微旋转（模拟岩石不规则纹理）
		seg.rotation_degrees = Vector3(
			rng.randf_range(-3.0, 3.0),
			rng.randf_range(0.0, 360.0),
			rng.randf_range(-3.0, 3.0)
		)

		seg.use_collision = true
		seg.add_to_group("level_geometry")
		seg.add_to_group("cover_prop")

		var mat := StandardMaterial3D.new()
		# 深灰到黑色，每段颜色微有差异
		var gray := rng.randf_range(0.12, 0.25)
		mat.albedo_color = Color(gray, gray, gray * 0.9)
		mat.roughness = 0.95
		seg.material = mat
		add_child(seg)

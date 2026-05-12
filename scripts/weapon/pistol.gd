# ==============================================================================
# Pistol — 手枪武器
# ==============================================================================
# 继承 WeaponNode，只覆写 _setup_model() 创建手枪外观。
# 射击、弹药、换弹逻辑全部在父类 WeaponNode 中处理。
#
# 外观：几个 CSGBox3D 拼成一个简陋的手枪形状
#   - 枪管：细长的盒子向前伸出
#   - 握把：偏下的方块
#   - 弹匣井：握把前方的小方块
# ==============================================================================

class_name Pistol extends WeaponNode


func _setup_model() -> void:
	# 枪管的材质——暗灰色金属
	var mat := _gun_material()

	# --- 枪管（Barrel）---
	# 一根细长的方棍，从枪身向前伸出
	var barrel := CSGBox3D.new()
	barrel.name = "Barrel"
	barrel.size = Vector3(0.04, 0.04, 0.25)       # 4cm × 4cm × 25cm 的长条
	barrel.position = Vector3(0.0, 0.0, -0.18)     # 向前偏移
	barrel.material_override = mat
	add_child(barrel)

	# --- 枪身（Body）---
	# 手枪中间的主方块
	var body := CSGBox3D.new()
	body.name = "Body"
	body.size = Vector3(0.05, 0.08, 0.12)
	body.position = Vector3(0.0, 0.01, 0.0)
	body.material_override = mat
	add_child(body)

	# --- 握把（Grip）---
	# 向下延伸的方块，模拟手枪握把
	var grip := CSGBox3D.new()
	grip.name = "Grip"
	grip.size = Vector3(0.04, 0.12, 0.06)
	grip.position = Vector3(0.0, -0.09, 0.03)
	# 握把稍微倾斜——绕 X 轴旋转让握把底部向后
	grip.rotation_degrees = Vector3(15.0, 0.0, 0.0)
	grip.material_override = mat
	add_child(grip)

	# --- 调整枪口位置 ---
	# 枪口闪光标记移到枪管末端
	_muzzle.position = Vector3(0.0, 0.0, -0.32)


# ==============================================================================
# _gun_material() — 创建武器的暗灰色金属材质
# ==============================================================================
func _gun_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.18, 0.2)   # 暗灰偏蓝，模拟钢铁
	mat.roughness = 0.4                            # 有点反光，金属感
	mat.metallic = 0.8                             # 金属度 0.8，有高光反射
	return mat

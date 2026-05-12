# ==============================================================================
# Shotgun — 霰弹枪武器
# ==============================================================================
# 继承 WeaponNode，只覆写 _setup_model() 创建霰弹枪外观。
# 射击（多弹丸散射）、泵动、换弹逻辑全部在父类 WeaponNode 中处理。
#
# 外观特点（比手枪更大更长）：
#   - 长枪管：比手枪长一倍
#   - 弹仓管：枪管下方的平行管子
#   - 枪托：向后的方块
# ==============================================================================

class_name Shotgun extends WeaponNode


func _setup_model() -> void:
	var mat := _gun_material()

	# --- 枪管（Long barrel）---
	# 霰弹枪的枪管比手枪长得多
	var barrel := CSGBox3D.new()
	barrel.name = "Barrel"
	barrel.size = Vector3(0.06, 0.06, 0.5)         # 6cm × 6cm × 50cm
	barrel.position = Vector3(0.0, 0.0, -0.3)       # 向前大幅度伸出
	barrel.material_override = mat
	add_child(barrel)

	# --- 弹仓管（Magazine tube）---
	# 枪管下方平行的一根管子，存放霰弹
	var tube := CSGBox3D.new()
	tube.name = "Tube"
	tube.size = Vector3(0.04, 0.04, 0.4)
	tube.position = Vector3(0.0, -0.05, -0.25)
	tube.material_override = mat
	add_child(tube)

	# --- 机匣（Receiver）---
	# 枪身主体
	var body := CSGBox3D.new()
	body.name = "Body"
	body.size = Vector3(0.06, 0.1, 0.18)
	body.position = Vector3(0.0, -0.01, 0.0)
	body.material_override = mat
	add_child(body)

	# --- 枪托（Stock）---
	# 向后延伸的枪托
	var stock := CSGBox3D.new()
	stock.name = "Stock"
	stock.size = Vector3(0.04, 0.08, 0.22)
	stock.position = Vector3(0.0, -0.02, 0.2)       # 向后
	stock.material_override = mat
	add_child(stock)

	# --- 握把（Grip）---
	var grip := CSGBox3D.new()
	grip.name = "Grip"
	grip.size = Vector3(0.04, 0.12, 0.05)
	grip.position = Vector3(0.0, -0.09, 0.08)
	grip.rotation_degrees = Vector3(10.0, 0.0, 0.0)
	grip.material_override = mat
	add_child(grip)

	# --- 调整枪口位置到长枪管末端 ---
	_muzzle.position = Vector3(0.0, 0.0, -0.57)


func _gun_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.16, 0.18)
	mat.roughness = 0.35
	mat.metallic = 0.85
	return mat

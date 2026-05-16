# ==============================================================================
# Rifle — 步枪武器（全自动、主力远程）
# ==============================================================================
class_name Rifle extends WeaponNode


func _setup_model() -> void:
	var mat := _gun_material()

	# 枪管（长）
	var barrel := CSGBox3D.new()
	barrel.name = "Barrel"
	barrel.size = Vector3(0.05, 0.05, 0.6)
	barrel.position = Vector3(0.0, 0.0, -0.35)
	barrel.material_override = mat
	add_child(barrel)

	# 枪身
	var body := CSGBox3D.new()
	body.name = "Body"
	body.size = Vector3(0.06, 0.1, 0.2)
	body.position = Vector3(0.0, 0.0, 0.0)
	body.material_override = mat
	add_child(body)

	# 枪托
	var stock := CSGBox3D.new()
	stock.name = "Stock"
	stock.size = Vector3(0.04, 0.07, 0.25)
	stock.position = Vector3(0.0, -0.02, 0.22)
	stock.material_override = mat
	add_child(stock)

	# 弹匣
	var mag := CSGBox3D.new()
	mag.name = "Magazine"
	mag.size = Vector3(0.035, 0.1, 0.04)
	mag.position = Vector3(0.0, -0.08, 0.02)
	mag.material_override = mat
	add_child(mag)

	# 握把
	var grip := CSGBox3D.new()
	grip.name = "Grip"
	grip.size = Vector3(0.035, 0.1, 0.05)
	grip.position = Vector3(0.0, -0.08, 0.1)
	grip.rotation_degrees = Vector3(12.0, 0.0, 0.0)
	grip.material_override = mat
	add_child(grip)

	_muzzle.position = Vector3(0.0, 0.0, -0.67)


func _gun_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.14)
	mat.roughness = 0.35
	mat.metallic = 0.85
	return mat

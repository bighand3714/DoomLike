# ==============================================================================
# Shotgun — 双管猎枪
# ==============================================================================
class_name Shotgun extends WeaponNode


func _setup_model() -> void:
	var metal_mat := _gun_material()
	var wood_mat := _wood_material()

	# 两根并排枪管（双管猎枪标志特征）
	var barrel_l := CSGBox3D.new()
	barrel_l.name = "Barrel_L"
	barrel_l.size = Vector3(0.04, 0.04, 0.5)
	barrel_l.position = Vector3(-0.025, 0.02, -0.3)
	barrel_l.material_override = metal_mat
	add_child(barrel_l)

	var barrel_r := CSGBox3D.new()
	barrel_r.name = "Barrel_R"
	barrel_r.size = Vector3(0.04, 0.04, 0.5)
	barrel_r.position = Vector3(0.025, 0.02, -0.3)
	barrel_r.material_override = metal_mat
	add_child(barrel_r)

	# 机匣
	var body := CSGBox3D.new()
	body.name = "Body"
	body.size = Vector3(0.07, 0.1, 0.18)
	body.position = Vector3(0.0, 0.0, 0.0)
	body.material_override = metal_mat
	add_child(body)

	# 木质枪身（猎枪风格）
	var wood_body := CSGBox3D.new()
	wood_body.name = "WoodBody"
	wood_body.size = Vector3(0.05, 0.04, 0.18)
	wood_body.position = Vector3(0.0, -0.04, 0.0)
	wood_body.material_override = wood_mat
	add_child(wood_body)

	# 枪托（木质）
	var stock := CSGBox3D.new()
	stock.name = "Stock"
	stock.size = Vector3(0.04, 0.07, 0.22)
	stock.position = Vector3(0.0, -0.03, 0.2)
	stock.material_override = wood_mat
	add_child(stock)

	# 握把（木质）
	var grip := CSGBox3D.new()
	grip.name = "Grip"
	grip.size = Vector3(0.04, 0.1, 0.05)
	grip.position = Vector3(0.0, -0.08, 0.1)
	grip.rotation_degrees = Vector3(10.0, 0.0, 0.0)
	grip.material_override = wood_mat
	add_child(grip)

	_muzzle.position = Vector3(0.0, 0.02, -0.57)


func _gun_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.16, 0.18)
	mat.roughness = 0.35
	mat.metallic = 0.85
	return mat


func _wood_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.2, 0.1)
	mat.roughness = 0.75
	mat.metallic = 0.0
	return mat

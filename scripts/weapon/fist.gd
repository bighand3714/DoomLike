# ==============================================================================
# Fist — 拳头武器（近战、无限）
# ==============================================================================
class_name Fist extends WeaponNode


func _setup_model() -> void:
	# 肉色拳套方块
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.65, 0.5)
	mat.roughness = 0.8
	mat.metallic = 0.0

	var fist_box := CSGBox3D.new()
	fist_box.name = "FistModel"
	fist_box.size = Vector3(0.06, 0.06, 0.08)
	fist_box.position = Vector3(0.0, 0.0, -0.15)
	fist_box.material_override = mat
	add_child(fist_box)

	_muzzle.position = Vector3(0.0, 0.0, -0.2)


# 拳头覆写后坐力——前冲而非后座
func _apply_recoil() -> void:
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()
	var original_pos := position
	_recoil_tween = create_tween()
	_recoil_tween.tween_property(self, "position", original_pos + Vector3(0.0, 0.0, -0.08), 0.04)
	_recoil_tween.tween_property(self, "position", original_pos, 0.12)

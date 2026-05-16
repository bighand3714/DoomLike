# ==============================================================================
# AmmoPickup — 弹药补充（智能：跳过无限弹药武器）
# ==============================================================================

class_name AmmoPickup extends Pickup

@export var ammo_amount: int = 10


func _on_pickup(player: Node3D) -> void:
	var wm: WeaponManager = player.find_child("WeaponManager", true, false) as WeaponManager
	if wm == null:
		return

	var weapon := wm.get_current_weapon()
	if weapon == null:
		return

	# 如果当前武器无限弹药，找一个有限弹药的武器
	if weapon.weapon_data.infinite_ammo:
		for i in range(wm.get_weapon_count()):
			var w := wm.get_weapon_at(i)
			if w != null and w.weapon_data != null and not w.weapon_data.infinite_ammo:
				# 检查是否已满
				if w.get_current_reserve() < w.weapon_data.reserve_ammo:
					weapon = w
					break

	# 如果还是无限弹药武器（全部无限），不拾取
	if weapon.weapon_data.infinite_ammo:
		return

	weapon.add_reserve_ammo(ammo_amount)

	GameBus.pickup_notification.emit("+%d 弹药" % ammo_amount, Color.GOLD)


func _setup_visual() -> void:
	super()

	for child in get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color.GOLD
			mat.emission_enabled = true
			mat.emission = Color.GOLD * 0.5
			child.material_override = mat

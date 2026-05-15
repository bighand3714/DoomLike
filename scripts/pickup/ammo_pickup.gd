# ==============================================================================
# AmmoPickup — 弹药补充
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

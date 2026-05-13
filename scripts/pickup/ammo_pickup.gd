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
	weapon._current_reserve += ammo_amount
	weapon.ammo_changed.emit(weapon._current_mag, weapon._current_reserve)

	var main := player.get_tree().root.get_node_or_null("Main")
	if main != null and main.has_method("show_pickup_notification"):
		main.show_pickup_notification("+%d 弹药" % ammo_amount, Color.GOLD)


func _setup_visual() -> void:
	super()

	for child in get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color.GOLD
			mat.emission_enabled = true
			mat.emission = Color.GOLD * 0.5
			child.material_override = mat

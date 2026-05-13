# ==============================================================================
# ArmorPickup — 护甲
# ==============================================================================

class_name ArmorPickup extends Pickup

@export var armor_amount: float = 100.0


func _on_pickup(player: Node3D) -> void:
	var dmg := player.get_node_or_null("Damageable") as Damageable
	if dmg == null:
		return
	if dmg.armor >= dmg.max_armor:
		return
	dmg.add_armor(armor_amount)

	var main := player.get_tree().root.get_node_or_null("Main")
	if main != null and main.has_method("show_pickup_notification"):
		main.show_pickup_notification("护甲 +%.0f" % armor_amount, Color.CORNFLOWER_BLUE)


func _setup_visual() -> void:
	super()

	for child in get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color.CORNFLOWER_BLUE
			mat.emission_enabled = true
			mat.emission = Color.CORNFLOWER_BLUE * 0.5
			child.material_override = mat

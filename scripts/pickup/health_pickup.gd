# ==============================================================================
# HealthPickup — 血包
# ==============================================================================

class_name HealthPickup extends Pickup

@export var heal_amount: float = 25.0


func _on_pickup(player: Node3D) -> void:
	var dmg := player.get_node_or_null("Damageable") as Damageable
	if dmg == null:
		return
	if dmg.health >= dmg.max_health:
		return  # 满血不捡
	dmg.add_health(heal_amount)

	# 拾取通知
	var main := player.get_tree().root.get_node_or_null("Main")
	if main != null and main.has_method("show_pickup_notification"):
		main.show_pickup_notification("+%.0f 生命" % heal_amount, Color.GREEN)


func _setup_visual() -> void:
	super()

	# 红色发光
	for child in get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color.RED
			mat.emission_enabled = true
			mat.emission = Color.RED * 0.6
			child.material_override = mat

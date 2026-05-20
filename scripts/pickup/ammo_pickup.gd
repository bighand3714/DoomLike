# ==============================================================================
# AmmoPickup — 弹药补充（智能：跳过无限弹药武器）
# ==============================================================================

class_name AmmoPickup extends Pickup

@export var ammo_amount: int = 10


func _on_pickup(player: Node3D) -> void:
	var wm: WeaponManager = player.find_child("WeaponManager", true, false) as WeaponManager
	if wm == null:
		return

	# 为所有有限弹药武器补充备弹
	var any_filled := false
	for i in range(wm.get_weapon_count()):
		var w := wm.get_weapon_at(i)
		if w == null or w.weapon_data == null:
			continue
		if w.weapon_data.infinite_ammo:
			continue
		w.add_reserve_ammo(ammo_amount)
		any_filled = true

	if not any_filled:
		return

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

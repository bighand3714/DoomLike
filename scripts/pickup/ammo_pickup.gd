# ==============================================================================
# AmmoPickup — 弹药补充（每种武器按弹匣量分别补给）
# ==============================================================================

class_name AmmoPickup extends Pickup
# 弹药倍率（DropManager.apply_drop_upgrade 修改）
var ammo_mult: float = 1.0


func _on_pickup(player: Node3D) -> void:
	var wm: WeaponManager = player.find_child("WeaponManager", true, false) as WeaponManager
	if wm == null:
		return

	var total := 0
	for i in range(wm.get_weapon_count()):
		var w := wm.get_weapon_at(i)
		if w == null or w.weapon_data == null:
			continue
		if w.weapon_data.infinite_ammo:
			continue
		var mag := maxi(w.weapon_data.mag_size, 1)
		var amount := randi_range(mag - floori(mag / 3.0), mag + floori(mag / 3.0))
		amount = int(ceil(float(amount) * ammo_mult))
		w.add_reserve_ammo(amount)
		total += amount

	if total <= 0:
		return

	GameBus.pickup_notification.emit("+弹药", Color.GOLD)


func _setup_visual() -> void:
	super()

	for child in get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color.GOLD
			mat.emission_enabled = true
			mat.emission = Color.GOLD * 0.5
			child.material_override = mat

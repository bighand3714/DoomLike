class_name LevelBuilder extends Node3D

## Converts LevelData into a 3D scene node tree.
## Phase 1: only contains the API contract. Full geometry generation
## will be implemented once we have real level data to build from.

@export var level_data: LevelData


func build() -> void:
	## Clear any existing geometry
	for child in get_children():
		child.queue_free()

	if level_data == null:
		push_warning("LevelBuilder: no LevelData assigned")
		return

	for sector in level_data.sectors:
		_build_sector(sector)

	for thing in level_data.things:
		_place_thing(thing)


func _build_sector(sector: LevelData.Sector) -> void:
	pass  ## TODO: Phase 2+ — generate 3D mesh from sector walls


func _place_thing(thing: LevelData.ThingDef) -> void:
	match thing.type:
		LevelData.ThingDef.Type.PLAYER_START:
			pass  ## TODO: emit signal / set spawn point


## Serialize the current scene back into LevelData (for map editor use)
static func serialize(_scene_root: Node3D) -> LevelData:
	var data := LevelData.new()
	## TODO: Phase 4 — extract sectors from scene geometry
	return data

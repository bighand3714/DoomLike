class_name LevelData extends Resource

## Floor/ceiling texture definitions
class SurfaceDef:
	var texture: StringName
	var height: float

## Wall segment between two vertices
class WallDef:
	var start := Vector2.ZERO
	var end := Vector2.ZERO
	var texture_upper: StringName
	var texture_middle: StringName
	var texture_lower: StringName
	var portal_to := -1  ## adjacent sector index, -1 = solid wall


## A sector is a convex polygon defining a room/area
class Sector:
	var floor_height := 0.0
	var ceiling_height := 4.0
	var floor_texture: StringName
	var ceiling_texture: StringName
	var light_level := 160
	var walls: Array[WallDef] = []


## Entity placement (player starts, enemies, pickups, etc.)
class ThingDef:
	enum Type { PLAYER_START, ENEMY, PICKUP, DECORATION }
	var type: Type
	var position := Vector3.ZERO
	var angle := 0.0
	var subtype: StringName  ## e.g. "imp", "shotgun", "health_bonus"


var sectors: Array = []
var things: Array = []
@export var metadata := {
	name = "Untitled",
	author = "",
	bgm = ""
}

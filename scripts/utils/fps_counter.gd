extends Label

var _elapsed := 0.0
var _frames := 0


func _process(delta: float) -> void:
	_elapsed += delta
	_frames += 1
	if _elapsed >= 0.5:
		text = "FPS: %d" % roundi(_frames / _elapsed)
		_elapsed = 0.0
		_frames = 0

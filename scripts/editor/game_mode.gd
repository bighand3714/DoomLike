class_name GameModeManager extends Node

enum Mode {
	PLAY,
	EDIT
}

var current_mode := Mode.PLAY :
	set(value):
		current_mode = value
		mode_changed.emit(value)

signal mode_changed(mode: Mode)


func toggle() -> void:
	current_mode = Mode.EDIT if current_mode == Mode.PLAY else Mode.PLAY

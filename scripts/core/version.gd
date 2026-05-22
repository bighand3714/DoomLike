class_name GameVersion extends RefCounted

static func get_version_string() -> String:
	return ProjectSettings.get_setting("application/config/version", "0.0.0")

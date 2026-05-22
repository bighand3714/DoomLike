class_name PlatformDetector extends RefCounted

enum Platform {
	PC_WINDOWS,
	PC_LINUX,
	PC_MACOS,
	ANDROID,
	WEB,
	UNKNOWN,
}

static func get_current() -> int:
	var os_name := OS.get_name()
	match os_name:
		"Windows":
			return Platform.PC_WINDOWS
		"Linux", "FreeBSD", "NetBSD", "OpenBSD":
			return Platform.PC_LINUX
		"macOS":
			return Platform.PC_MACOS
		"Android":
			return Platform.ANDROID
		"Web":
			return Platform.WEB
		_:
			return Platform.UNKNOWN

static func is_pc() -> bool:
	var p := get_current()
	return p == Platform.PC_WINDOWS or p == Platform.PC_LINUX or p == Platform.PC_MACOS

static func is_mobile() -> bool:
	return get_current() == Platform.ANDROID

static func is_web() -> bool:
	return get_current() == Platform.WEB

static func is_touch_primary() -> bool:
	return OS.get_name() == "Android"

static func get_renderer() -> String:
	return RenderingServer.get_current_rendering_method()

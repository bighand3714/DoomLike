# ==============================================================================
# TestArena — 测试关卡（灰色地面，手动放置敌人）
# ==============================================================================
class_name TestArena extends ArenaLevel


func _get_ground_color() -> Color:
	return Color(0.35, 0.35, 0.38)


func _get_boundary_color() -> Color:
	return Color(0.6, 0.6, 0.65)

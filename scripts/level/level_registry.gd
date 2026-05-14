# ==============================================================================
# LevelRegistry — 关卡注册表（Phase 2.1）
# ==============================================================================
# 整个项目中关于"有哪些关卡、关卡叫什么、关卡场景在哪"的唯一权威来源。
# 所有 static 方法，无需实例化——直接用 LevelRegistry.get_display_name() 调用。
#
# 为什么需要注册表：
#   之前选关界面（level_select.gd）和结算界面（game_over_screen.gd）各自
#   硬编码了一份关卡名映射 {"desert": "第一关：荒漠", ...}。
#   如果后续加了第三关，需要改两个文件，容易漏掉。
#   集中在这里管理后，UI 只需要调用 LevelRegistry 的方法即可，
#   新增关卡只要改这一个文件。
#
# 设计原则：
#   - 所有数据存在一个 _data 字典里，key 是关卡 id（"desert"/"lava"）
#   - 所有查询方法都是 static func，不依赖实例
#   - 未知 level_id 返回安全默认值（不崩溃），方便调试
# ==============================================================================

class_name LevelRegistry extends RefCounted


# ==============================================================================
# 关卡 id 常量——用常量代替裸字符串，避免拼写错误
# ==============================================================================
# 类比：与其到处写 "desert"（万一写错成 "desret" 查不出 bug），
# 不如统一写 LevelRegistry.DESERT（写错了编译器会报错）。
const DESERT := "desert"
const LAVA := "lava"


# ==============================================================================
# 关卡数据内部表（私有——外部通过 get_* 方法访问）
# ==============================================================================
# 每个关卡包含：
#   display_name —— 在选关界面和结算界面中显示的关卡名
#   description  —— 选关面板中的描述文字（\n 换行）
#   scene_path   —— 关卡 .tscn 场景文件的路径
#   color        —— 主题色（选关面板背景/边框/标题颜色）
static var _data := {
	DESERT: {
		display_name = "第一关：荒漠",
		description = "枯树作为掩体\n视野开阔，适合入门",
		scene_path = "res://scenes/levels/desert_arena.tscn",
		color = Color(0.76, 0.66, 0.4),
	},
	LAVA: {
		display_name = "第二关：熔岩地狱",
		description = "熔岩河流持续伤害\n柱状岩石提供掩体",
		scene_path = "res://scenes/levels/lava_arena.tscn",
		color = Color(0.7, 0.2, 0.1),
	},
}


# ==============================================================================
# get_level_ids() — 返回所有关卡的 id 列表
# ==============================================================================
# 返回 ["desert", "lava"]，UI 遍历这个数组来生成关卡面板。
# 如果以后加第三关，只需在 _data 中新增一条，这个方法自动包含新 id。
static func get_level_ids() -> Array:
	return _data.keys()


# ==============================================================================
# get_display_name(level_id) — 返回关卡的中文显示名
# ==============================================================================
# 例：get_display_name("desert") → "第一关：荒漠"
# 未知 id 返回原值（至少让用户看到点什么，也好排查问题）
static func get_display_name(level_id: String) -> String:
	var entry: Dictionary = _data.get(level_id, {})
	return entry.get("display_name", level_id)


# ==============================================================================
# get_description(level_id) — 返回关卡的文字描述
# ==============================================================================
# 例：get_description("lava") → "熔岩河流持续伤害\n柱状岩石提供掩体"
# 未知 id 返回空字符串
static func get_description(level_id: String) -> String:
	var entry: Dictionary = _data.get(level_id, {})
	return entry.get("description", "")


# ==============================================================================
# get_scene_path(level_id) — 返回关卡 .tscn 场景文件路径
# ==============================================================================
# 例：get_scene_path("desert") → "res://scenes/levels/desert_arena.tscn"
# Phase 2.2+ 由 main.gd 的 _load_arena_level() 使用。
# 未知 id 返回空字符串，加载时会检测并报错。
static func get_scene_path(level_id: String) -> String:
	var entry: Dictionary = _data.get(level_id, {})
	return entry.get("scene_path", "")


# ==============================================================================
# get_color(level_id) — 返回关卡主题色
# ==============================================================================
# 用于选关面板的背景、边框、标题颜色。
# 荒漠 = 沙黄色，熔岩 = 暗红色。
# 未知 id 返回白色（至少能看清，不至于透明）
static func get_color(level_id: String) -> Color:
	var entry: Dictionary = _data.get(level_id, {})
	return entry.get("color", Color.WHITE)

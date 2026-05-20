# ==============================================================================
# PlayerProgression — 玩家局内成长控制器
# ==============================================================================
# 挂在 Player 或 Main 下，负责等级、经验、连续升级和待选项队列。
# 击杀时通过 add_xp() 获得经验，满经验后触发 level_up 信号。
# ==============================================================================

class_name PlayerProgression extends Node


# ==============================================================================
# 信号
# ==============================================================================

signal xp_changed(level: int, xp: int, xp_to_next: int)
signal level_up(new_level: int, options: Array)
signal upgrade_applied(upgrade_id: String, upgrade_level: int)
signal player_power_changed(power_score: float)


# ==============================================================================
# 状态
# ==============================================================================

## 当前等级（从 1 开始）
var level: int = 1

## 当前经验值
var xp: int = 0

## 升到下一级所需经验
var xp_to_next: int = 20

## 已选升级等级 —— upgrade_id → 当前等级（1 = 刚获得）
var selected_levels: Dictionary = {}

## 待处理升级次数（连续升级时累积）
var pending_level_ups: int = 0

## 当前三选一选项
var current_options: Array = []

## 经验倍率（可通过升级或关卡调整）
var xp_mult: float = 1.0

## 战力评分
var power_score: float = 0.0


# ==============================================================================
# 内部引用
# ==============================================================================

var _upgrade_catalog: UpgradeCatalog = null


# ==============================================================================
# reset() — 重置到开局状态
# ==============================================================================
func reset(p_catalog: UpgradeCatalog = null) -> void:
	if p_catalog != null:
		_upgrade_catalog = p_catalog
	elif _upgrade_catalog == null:
		_load_mvp_upgrades()
	level = 1
	xp = 0
	xp_to_next = _calc_xp_to_next(1)
	selected_levels.clear()
	pending_level_ups = 0
	current_options.clear()
	xp_mult = 1.0
	power_score = 0.0
	xp_changed.emit(level, xp, xp_to_next)
	player_power_changed.emit(power_score)


# ==============================================================================
# get_xp_to_next(p_level) — 计算指定等级所需的升级经验
# ==============================================================================
# 公式: round(12 + 6 * level + 1.5 * pow(level, 1.5))
static func get_xp_to_next(p_level: int) -> int:
	return roundi(12.0 + 6.0 * float(p_level) + 1.5 * pow(float(p_level), 1.5))


func _calc_xp_to_next(p_level: int) -> int:
	return get_xp_to_next(p_level)


# ==============================================================================
# add_xp(amount) — 增加经验，处理升级
# ==============================================================================
func add_xp(amount: int) -> void:
	if amount <= 0:
		return

	var gained := int(round(float(amount) * xp_mult))
	if gained <= 0:
		gained = 1

	xp += gained

	# 循环处理连续升级
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		pending_level_ups += 1
		xp_to_next = _calc_xp_to_next(level)

	xp_changed.emit(level, xp, xp_to_next)

	# 触发生成升级选项
	if pending_level_ups > 0:
		_generate_options()


# ==============================================================================
# select_upgrade(index) — 选择一项升级
# ==============================================================================
func select_upgrade(index: int) -> void:
	if index < 0 or index >= current_options.size():
		return

	var upg: UpgradeData = current_options[index]
	if upg == null:
		return

	var upg_id := upg.upgrade_id
	var current_lv: int = selected_levels.get(upg_id, 0)
	var new_lv := current_lv + 1

	if not upg.is_valid_for_level(new_lv):
		return

	selected_levels[upg_id] = new_lv

	# 更新战力分
	power_score += upg.get_power_for_level(new_lv)

	upgrade_applied.emit(upg_id, new_lv)
	player_power_changed.emit(power_score)

	# 处理下一个待升级
	pending_level_ups -= 1
	current_options.clear()

	if pending_level_ups > 0:
		_generate_options()


# ==============================================================================
# 内部方法
# ==============================================================================

func _generate_options() -> void:
	if _upgrade_catalog == null:
		# 暂无目录：发空选项，不卡死
		current_options = []
		level_up.emit(level, current_options)
func _load_mvp_upgrades() -> void:
	var upgrades: Array[UpgradeData] = []
	var paths := [
		"res://assets/upgrades/rifle_damage.tres",
		"res://assets/upgrades/shotgun_damage.tres",
		"res://assets/upgrades/reload_speed.tres",
		"res://assets/upgrades/whip_range.tres",
		"res://assets/upgrades/whip_cooldown.tres",
		"res://assets/upgrades/whip_stun.tres",
		"res://assets/upgrades/max_health.tres",
		"res://assets/upgrades/max_armor.tres",
		"res://assets/upgrades/move_speed.tres",
		"res://assets/upgrades/ammo_loot.tres",
		"res://assets/upgrades/health_loot.tres",
		"res://assets/upgrades/drop_abundance.tres",
	]
	for p in paths:
		if ResourceLoader.exists(p):
			var upg := load(p) as UpgradeData
			if upg != null:
				upgrades.append(upg)
	_upgrade_catalog = UpgradeCatalog.new()
	_upgrade_catalog.setup(upgrades)

		return

	current_options = _upgrade_catalog.get_choices(selected_levels, 3)
	level_up.emit(level, current_options)

# ==============================================================================
# UpgradeCatalog — 三选一升级池抽取逻辑
# ==============================================================================
# 维护升级列表，根据玩家已选等级过滤满级/互斥/前置，
# 按权重随机抽取 3 个不重复候选，供三选一 UI 显示。
# ==============================================================================

class_name UpgradeCatalog extends RefCounted


# ==============================================================================
# 内部状态
# ==============================================================================

var _upgrades: Array[UpgradeData] = []
var _rng := RandomNumberGenerator.new()


# ==============================================================================
# setup(p_upgrades) — 初始化升级池
# ==============================================================================
func setup(p_upgrades: Array[UpgradeData]) -> void:
	_upgrades = p_upgrades.duplicate()
	_rng.randomize()


# ==============================================================================
# get_choices(selected_levels, count) — 返回加权随机的 N 个升级候选
# ==============================================================================
# selected_levels: Dictionary[String, int] — upgrade_id → 当前等级
# count: int — 需要返回的候选数量（默认 3）
# ==============================================================================
func get_choices(selected_levels: Dictionary, count: int = 3) -> Array[UpgradeData]:
	var available: Array[UpgradeData] = []

	for upg in _upgrades:
		if upg == null:
			continue

		var current_level: int = selected_levels.get(upg.upgrade_id, 0)

		# 已达最高等级 → 不出现
		if not upg.is_valid_for_level(current_level + 1):
			continue

		# 有未满足的前置 → 不出现
		if not _check_prerequisites(upg, selected_levels):
			continue

		# 有互斥升级已选 → 不出现
		if _has_exclusions(upg, selected_levels):
			continue

		available.append(upg)

	# 按稀有度权重随机抽取，尽量不同类别
	return _weighted_pick(available, count)


# ==============================================================================
# 辅助方法
# ==============================================================================

func _check_prerequisites(upg: UpgradeData, selected_levels: Dictionary) -> bool:
	for pre_id in upg.prerequisites:
		var lv: int = selected_levels.get(pre_id, 0)
		if lv <= 0:
			return false
	return true


func _has_exclusions(upg: UpgradeData, selected_levels: Dictionary) -> bool:
	for ex_id in upg.exclusions:
		var lv: int = selected_levels.get(ex_id, 0)
		if lv > 0:
			return true
	return false


## 加权随机抽取，尽量让候选类别不重复
func _weighted_pick(available: Array[UpgradeData], count: int) -> Array[UpgradeData]:
	if available.is_empty():
		return []

	var result: Array[UpgradeData] = []
	var pool := available.duplicate()

	# 最多尝试 count 次，每次选一个加入结果
	for _round in range(count):
		if pool.is_empty():
			break

		# 优先选与已有结果不同类别的
		var priority: Array[UpgradeData] = []
		var fallback: Array[UpgradeData] = []

		for upg in pool:
			var same_cat := false
			for chosen in result:
				if upg.category == chosen.category:
					same_cat = true
					break
			if same_cat:
				fallback.append(upg)
			else:
				priority.append(upg)

		var pick_pool := priority if not priority.is_empty() else fallback
		var chosen := _rng_weighted_select(pick_pool)
		if chosen != null:
			result.append(chosen)
			pool.erase(chosen)

	return result


## 从数组中按 rarity_weight 加权随机选一个
func _rng_weighted_select(pool: Array[UpgradeData]) -> UpgradeData:
	if pool.is_empty():
		return null

	var total_weight: float = 0.0
	for upg in pool:
		total_weight += maxf(upg.rarity_weight, 0.01)

	if total_weight <= 0.0:
		return pool[0]

	var roll := _rng.randf() * total_weight
	var accumulated: float = 0.0
	for upg in pool:
		accumulated += maxf(upg.rarity_weight, 0.01)
		if roll <= accumulated:
			return upg

	return pool[pool.size() - 1]


## 根据 upgrade_id 查找升级信息（供 UI 使用）
## 返回 {id, name, max_level, category}，未找到则返回空字典
func get_upgrade_info(upgrade_id: String) -> Dictionary:
	for upg in _upgrades:
		if upg != null and upg.upgrade_id == upgrade_id:
			return {id = upg.upgrade_id, name = upg.display_name, max_level = upg.max_level, category = upg.category}
	return {}

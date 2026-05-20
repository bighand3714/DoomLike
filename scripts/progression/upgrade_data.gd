# ==============================================================================
# UpgradeData — 升级能力资源
# ==============================================================================
# Resource 文件（.tres），定义一种可升级能力的所有属性。
# 每种升级为一个 .tres 实例，放入 assets/upgrades/ 中。
# PlayerProgression 读取这些资源来生成升级选项。
# ==============================================================================

class_name UpgradeData extends Resource


# ==============================================================================
# 枚举
# ==============================================================================

enum Category {
	WEAPON,    # 武器类升级（步枪/霰弹枪/手枪/拳头伤害、射速、换弹）
	WHIP,      # 铁鞭类升级（范围、冷却、眩晕、冲刺处决、甩出）
	SURVIVAL,  # 生存类升级（生命上限、护甲上限、移速）
	ECONOMY,   # 经济类升级（弹药掉落、血包、护甲包、总掉落概率）
	UTILITY,   # 工具类升级（经验倍率、拾取范围等）
}

enum Operation {
	ADD,       # 加法：value = base + values_by_level[level-1]
	MULTIPLY,  # 乘法：value = base * values_by_level[level-1]
	SET,       # 直接设置：value = values_by_level[level-1]
}


# ==============================================================================
# 基础标识
# ==============================================================================

## 升级唯一 ID，如 "rifle_damage"
@export var upgrade_id: String = ""

## 升级显示名称，如 "步枪膛线"
@export var display_name: String = ""

## 升级描述，如 "步枪伤害 +10%"
@export var description: String = ""

## 升级类别
@export var category: Category = Category.WEAPON

## 最高等级（1 级 = 刚选到，此后每选一次升一级）
@export var max_level: int = 5


# ==============================================================================
# 抽取控制
# ==============================================================================

## 稀有度权重——数值越高越容易出现
@export var rarity_weight: float = 1.0

## 标签——用于分类和筛选（如 "fire", "ice", "melee"）
@export var tags: Array[String] = []

## 前置条件——需要这些 upgrade_id 至少获得 1 级后才出现
@export var prerequisites: Array[String] = []

## 互斥——如果这些 upgrade_id 中任一已获得，则不出现
@export var exclusions: Array[String] = []


# ==============================================================================
# 数值配置
# ==============================================================================

## 目标 ID——对应武器/铁鞭/属性的标识
##   武器: "rifle" / "shotgun" / "pistol" / "fist" / "all_weapons"
##   铁鞭: "iron_whip"
##   生存: "max_health" / "max_armor" / "move_speed"
##   经济: "ammo_loot" / "health_loot" / "armor_loot" / "drop_abundance" / "xp_mult"
@export var target_id: String = ""

## 属性键——目标体上的具体属性名
##   武器: "damage_mult" / "fire_rate_mult" / "reload_time_mult" / "spread_mult" / "pellet_bonus"
##   铁鞭: "whip_range" / "cooldown" / "stun_damage" / "dash_distance" / "dash_damage" / "throw_damage"
##   生存: "max_health" / "max_armor" / "move_speed_mult"
##   经济: "ammo_amount_mult" / "health_amount_mult" / "armor_amount_mult" / "drop_chance_bonus" / "xp_mult"
@export var stat_key: String = ""

## 操作类型（ADD / MULTIPLY / SET）
@export var operation: Operation = Operation.MULTIPLY

## 每级效果值——values_by_level[N-1] 表示升级到 N 级时的值
##   例：ADD 模式，[10, 20, 30] 表示 Lv1 +10, Lv2 +20, Lv3 +30
##   例：MULTIPLY 模式，[1.1, 1.2, 1.3] 表示 Lv1 ×1.1, Lv2 ×1.2, Lv3 ×1.3
@export var values_by_level: Array[float] = []

## 每级战力评分——用于 player_power_changed 信号
##   power_value_by_level[N-1] 表示升级到 N 级时贡献的战力分
@export var power_value_by_level: Array[float] = []


# ==============================================================================
# 方法
# ==============================================================================

## 返回指定等级的效果值（1 级 = 刚获得）
func get_value_for_level(next_level: int) -> float:
	if next_level <= 0:
		return 0.0
	var idx := next_level - 1
	if idx < values_by_level.size():
		return values_by_level[idx]
	if values_by_level.is_empty():
		return 0.0
	return values_by_level[values_by_level.size() - 1]


## 返回指定等级的战力评分
func get_power_for_level(next_level: int) -> float:
	if next_level <= 0:
		return 0.0
	var idx := next_level - 1
	if idx < power_value_by_level.size():
		return power_value_by_level[idx]
	return 0.0


## 检查是否还能升级（未达最高等级）
func is_valid_for_level(next_level: int) -> bool:
	return next_level <= max_level

# ==============================================================================
# WhipData — 铁鞭数据资源
# ==============================================================================
class_name WhipData extends Resource

## 每次挥鞭造成的基础伤害
@export var damage: float = 8.0

## 每次命中造成的眩晕值（远高于枪械，铁鞭主打控制）
@export var stun_damage: float = 40.0

## 击退力度
@export var knockback_force: float = 15.0

## 鞭子最大攻击距离（米），近战范围
@export var whip_range: float = 3.0

## 挥鞭冷却时间（秒）
@export var cooldown: float = 0.8

## 拉取眩晕敌人的速度（米/秒）
@export var pull_speed: float = 12.0

## 拉取到多近时自动转为抓取（米）
@export var grab_distance: float = 1.5

## 处决伤害（通常一击必杀）
@export var execution_damage: float = 999.0

## 处决额外分数
@export var execution_score_bonus: int = 25

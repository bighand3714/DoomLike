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

## 铁链最大有效长度（米）
@export var whip_length: float = 2.0

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

## 冲刺距离（米）
@export var dash_distance: float = 5.0

## 冲刺速度（米/秒）
@export var dash_speed: float = 25.0

## 对被撞敌人的伤害
@export var dash_damage: float = 60.0

## 路径上对其他敌人的伤害
@export var dash_aoe_damage: float = 30.0

## 冲刺击退力度
@export var dash_knockback: float = 25.0

## 对被抓起敌人的大伤害
@export var dash_grabbed_damage: float = 150.0

## 投掷落地爆炸判定半径（米）
@export var explosion_radius: float = 3.0

## 投掷基准初速（米/秒），60kg标准敌人@45°=20m
@export var throw_speed_base: float = 20.0

## 投掷基准体重（kg），用于速度缩放
@export var throw_reference_weight: float = 60.0

## 投掷落地溅射击退力度
@export var throw_impact_knockback: float = 10.0

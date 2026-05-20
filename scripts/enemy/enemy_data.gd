# ==============================================================================
# EnemyData — 敌人配置数据蓝图
# ==============================================================================
# Resource 文件（.tres），把敌人参数从代码中抽离。
# 不同敌人类型 = 不同的 .tres 文件，可在编辑器中直接调参。
#
# Phase 5 扩展：新增眩晕/重量/飞行/AI行为/模型颜色等字段。
# 旧 .tres 文件向后兼容——新字段有默认值。
# ==============================================================================

class_name EnemyData extends Resource


# ==============================================================================
# 基础信息
# ==============================================================================

## 敌人唯一标识，如 "imp"、"demon_soldier"
@export var enemy_id: String = ""

## 敌人显示名称
@export var enemy_name: String = "未命名敌人"

## 敌人角色标签，如 "ground_melee"、"flying_ranged"
@export var enemy_role: String = ""


# ==============================================================================
# 战斗属性
# ==============================================================================

@export var max_health: float = 100.0
@export var attack_damage: float = 10.0
@export var damage_type: WeaponData.DamageType = WeaponData.DamageType.HITSCAN

## 击杀分数
@export var score_value: int = 10

## 击杀经验值
@export var xp_value: int = 5

## 刷怪消耗（用于 SpawnManager 波次预算）
@export var spawn_cost: int = 1


# ==============================================================================
# 物理属性（Phase 5 新增）
# ==============================================================================

## 重量（kg）——影响被击退距离和被铁鞭拉取后玩家的减速程度
@export var weight: float = 1.0

## 击退抗性（0.0~0.9）——值越大击退效果越弱
@export var knockback_resistance: float = 0.0

## 护甲值（1 护甲 = 吸收 1 伤害）——仅敌人使用
@export var armor: float = 0.0

## 身高（米）——影响碰撞体尺寸
@export var height: float = 1.8

## 防御时举盾格挡概率（0.0~1.0）
@export var shield_block_chance: float = 0.0

## 是否具备防御技能
@export var can_defend: bool = false

## AI 检测间隔（秒）——每 N 秒检测一次而非每帧
@export var detection_interval: float = 0.5


# ==============================================================================
# 眩晕系统（Phase 5 新增）
# ==============================================================================

## 最大眩晕值——累积满后进入可抓取状态
@export var max_stun: float = 100.0

## 眩晕恢复速率（每秒）——未满时自动恢复
@export var stun_recovery_rate: float = 12.0

## 眩晕抗性（0.0~0.9）——减免受到的眩晕值
@export var stun_resistance: float = 0.0


# ==============================================================================
# AI 行为参数
# ==============================================================================

@export var move_speed: float = 4.0
@export var attack_range: float = 15.0
@export var sight_range: float = 30.0
@export var attack_cooldown: float = 1.0

## 偏好距离——远程敌人尝试保持在此距离射击
@export var preferred_range: float = 12.0

## 最小距离——远程敌人被逼近到此距离开始后退
@export var min_range: float = 4.0

## 五档距离阈值（米，XZ平面）
@export var bracket_melee_max: float = 1.0
@export var bracket_close_max: float = 3.0
@export var bracket_medium_max: float = 8.0
@export var bracket_far_max: float = 25.0

## 攻击前摇（秒）——举刀/举枪动作时间
@export var attack_windup: float = 0.2

## 攻击判定窗口（秒）——此时间段内能造成伤害
@export var attack_duration: float = 0.1

## 攻击后摇（秒）——收刀/收枪恢复时间
@export var attack_recovery: float = 0.3


# ==============================================================================
# 飞行属性（Phase 5 新增）
# ==============================================================================

## 是否飞行敌人
@export var is_flying: bool = false

## 悬浮高度（米）——飞行时保持在玩家上方的高度
@export var hover_height: float = 3.0

## 垂直移动速度（m/s）
@export var vertical_move_speed: float = 4.0


# ==============================================================================
# 反应参数
# ==============================================================================

@export var pain_duration: float = 0.3
@export var knockback_force: float = 3.0
@export var death_duration: float = 2.0

## 眩晕满后的可抓取窗口（秒）——被眩晕满后保持可抓取状态的时间
@export var stun_full_duration: float = 2.0


# ==============================================================================
# 视觉（Phase 5 新增）
# ==============================================================================

## 模型主色——Phase 6 立方体占位模型的颜色
@export var model_color: Color = Color(1.0, 0.2, 0.2)

# ==============================================================================
# ShootingTarget — 射击靶子（测试用）
# ==============================================================================
# 一个"被打会闪"的方块，用来验证射击系统是否正常工作。
# 继承 CSGBox3D（构造实体几何方块）——可以直接用来做碰撞检测和渲染。
#
# 靶子行为：
#   1. 初始是红色方块
#   2. 被击中时短暂闪白（反馈玩家"你打中了"）
#   3. 生命值归零时变灰 + 关闭碰撞（标记死亡）
#
# 这个类只是 Phase 2 的测试工具。Phase 3 会用它验证敌人受伤逻辑。
# ==============================================================================

class_name ShootingTarget extends CSGBox3D


# ==============================================================================
# 导出参数
# ==============================================================================

## 靶子的生命值，默认 100（手枪 15 伤害 ≈ 7 枪打碎）
@export var target_health: float = 100.0


# ==============================================================================
# 内部引用
# ==============================================================================

## 引用 Damageable 子节点——如果不存在则自动创建一个
@onready var _damageable: Damageable = _get_or_create_damageable()

## 自动创建 Damageable 子节点（如果手动挂了一个则优先使用已存在的）
func _get_or_create_damageable() -> Damageable:
	if has_node("Damageable"):
		return $Damageable
	var d := Damageable.new()
	d.name = "Damageable"
	add_child(d)
	return d


# ==============================================================================
# 运行时变量
# ==============================================================================

## 记录原始颜色，用于"闪白后恢复"
var _original_color: Color


# ==============================================================================
# _ready() — 初始化靶子外观和行为
# ==============================================================================
func _ready() -> void:
	# --- 设置材质 ---
	# use_collision = true 是 CSGBox3D 的属性，确保子弹射线能撞到它
	use_collision = true

	# CSG 节点需要用 material_override 覆盖默认材质。
	# 如果没有 material_override，CSG 会显示为白色无光表面。
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.2, 0.2)   # 暗红色——DOOM 风格
	mat.roughness = 0.9                          # 粗糙表面，不反光
	material_override = mat
	_original_color = mat.albedo_color

	# --- 配置伤害接收 ---
	_damageable.max_health = target_health

	# --- 连接信号 ---
	# connect() 的第一个参数是信号名（字符串），第二个参数是回调函数。
	# 写法等价于：_damageable.damaged.connect(_on_damaged)
	# 意思是：每当 _damageable 发出 damaged 信号，就自动调用本节点的 _on_damaged()
	_damageable.damaged.connect(_on_damaged)
	_damageable.died.connect(_on_died)


# ==============================================================================
# _on_damaged() — 受伤反馈：短暂闪白
# ==============================================================================
# Tween 是 Godot 的"动画插值器"——让值在一段时间内平滑变化。
# 这里把材质颜色瞬间变白，然后在 0.15 秒内渐变回原来的红色。
# 效果：靶子被击中时短暂闪过一道白光。
func _on_damaged(_amount: float, _damage_type: WeaponData.DamageType) -> void:
	# 设置材质为纯白色（瞬间反应——"我被打中了"）
	material_override.albedo_color = Color.WHITE

	# create_tween() 创建一个新的 Tween 并自动绑定到当前节点。
	# tween_property() 对某个对象的某个属性做渐变动画：
	#   参数1 = 要动画的对象（这里就是材质）
	#   参数2 = 属性名（字符串）
	#   参数3 = 目标值
	#   参数4 = 动画时长（秒）
	# 具体效果：albedo_color 从 Color.WHITE 在 0.15 秒内平滑变成 _original_color
	var tween := create_tween()
	tween.tween_property(material_override, "albedo_color", _original_color, 0.15)


# ==============================================================================
# _on_died() — 死亡反馈：变灰 + 关闭碰撞
# ==============================================================================
func _on_died() -> void:
	# 变成深灰色——表示"我已经死了"
	material_override.albedo_color = Color(0.3, 0.3, 0.3)

	# 关闭碰撞——死了的靶子不应该挡子弹，子弹穿过去打后面才对
	use_collision = false

	# 可选：加一小段缩小动画，模拟"被打碎"的视觉效果
	var tween := create_tween()
	tween.tween_property(self, "size", size * 0.6, 0.2)

# ==============================================================================
# CycleSun — 昼夜循环太阳（第二关地狱专用）
# ==============================================================================
# 挂载到 DirectionalLight3D 上。太阳东升西落，白天2分钟/夜晚40秒循环。
# ==============================================================================

class_name CycleSun extends DirectionalLight3D

@export var day_duration: float = 120.0
@export var night_duration: float = 40.0
@export var dawn_dusk_elevation: float = 10.0
@export var sun_energy_max: float = 1.2
@export var night_energy: float = 0.05
@export var dawn_color: Color = Color(1.0, 0.6, 0.3)
@export var noon_color: Color = Color(1.0, 0.95, 0.8)

var _cycle_time: float = 0.0

func _ready() -> void:
	shadow_enabled = true
	light_energy = 0.0


func _process(delta: float) -> void:
	_cycle_time += delta
	var total: float = day_duration + night_duration
	if _cycle_time >= total:
		_cycle_time = fmod(_cycle_time, total)

	if _cycle_time < day_duration:
		_update_day(_cycle_time / day_duration)
	else:
		_update_night()


func _update_day(progress: float) -> void:
	# Y轴：东(+X, 90°) → 西(-X, -90°)
	rotation_degrees.y = lerpf(90.0, -90.0, progress)

	# X轴仰角：黎明近地平线 → 正午高挂 → 黄昏近地平线
	var elevation: float = sin(progress * PI) * (90.0 - dawn_dusk_elevation)
	rotation_degrees.x = -(dawn_dusk_elevation + elevation)

	# 光照强度：黎明渐亮 → 正午最亮 → 黄昏渐暗
	var energy: float = sin(progress * PI)
	light_energy = lerpf(0.3, sun_energy_max, energy)

	# 光色：橙红 → 白黄 → 橙红
	light_color = dawn_color.lerp(noon_color, energy).lerp(dawn_color, 1.0 - energy)


func _update_night() -> void:
	light_energy = night_energy
	light_color = Color(0.3, 0.3, 0.5)  # 暗蓝环境光

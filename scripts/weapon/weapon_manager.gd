# ==============================================================================
# WeaponManager — 武器栏位管理器
# ==============================================================================
# 挂在 Player 节点的 WeaponHolder 下面，负责管理玩家身上所有武器。
# 工作内容：
#   1. 根据 WeaponData 数组创建对应的武器节点实例
#   2. 响应数字键/滚轮切换武器
#   3. 把射击输入转发给当前武器
#   4. 追踪当前装备的是哪把武器
#
# 场景位置：Player → WeaponHolder → WeaponManager
# WeaponManager 的每个子节点都是一把武器（Pistol、Shotgun 等）
# ==============================================================================

class_name WeaponManager extends Node3D


# ==============================================================================
# 信号
# ==============================================================================

## 武器切换成功时发射——HUD 用它更新当前武器显示
## @param weapon_name 新武器的名字（"手枪"、"霰弹枪"）
## @param slot_index 新武器在栏位中的位置（0, 1, 2...）
signal weapon_changed(weapon_name: String, slot_index: int)


# ==============================================================================
# 导出属性
# ==============================================================================

## 武器配置列表——在编辑器中填入 WeaponData 资源文件（.tres）
## 每个元素 = 一个武器栏位（例如 [手枪.tres, 霰弹枪.tres]）
@export var weapon_datas: Array[WeaponData] = []


# ==============================================================================
# 内部状态
# ==============================================================================

## 已经实例化的武器节点——和 weapon_datas 一一对应
var _weapons: Array[WeaponNode] = []

## 当前使用的武器索引（-1 = 没有任何武器）
var _current_index: int = -1

## 摄像机引用——从父节点路径获取，然后传给每把武器
var _camera: Camera3D


# ==============================================================================
# _ready() — 初始化所有武器
# ==============================================================================
func _ready() -> void:
	# WeaponManager → WeaponHolder → Camera3D
	_camera = get_parent().get_parent() as Camera3D

	# 如果编辑器中没配置武器数据，自动加载默认武器
	if weapon_datas.is_empty():
		weapon_datas = _load_default_weapons()

	# 为每个 WeaponData 创建一个武器节点实例
	for data in weapon_datas:
		var weapon := _create_weapon(data)
		weapon.visible = false
		add_child(weapon)
		_weapons.append(weapon)

	# 默认装备第一把武器
	if _weapons.size() > 0:
		_equip(0)


## 加载默认武器配置——步枪 + 霰弹枪 + 手枪 + 拳头
func _load_default_weapons() -> Array[WeaponData]:
	var defaults: Array[WeaponData] = []
	var rifle := load("res://assets/weapons/rifle.tres") as WeaponData
	var shotgun := load("res://assets/weapons/shotgun.tres") as WeaponData
	var pistol := load("res://assets/weapons/pistol.tres") as WeaponData
	var fist := load("res://assets/weapons/fist.tres") as WeaponData
	if rifle:
		defaults.append(rifle)
	if shotgun:
		defaults.append(shotgun)
	if pistol:
		defaults.append(pistol)
	if fist:
		defaults.append(fist)
	return defaults


# ==============================================================================
# _create_weapon(data) — 根据 WeaponData 创建对应的武器节点
# ==============================================================================
# 根据 WeaponData 的 fire_mode 来决定创建哪种武器子类：
#   PUMP 模式 → Shotgun 节点（有泵动逻辑和长枪管模型）
#   其他模式 → Pistol 节点（半自动或全自动，手枪外观）
#
# 未来如果加了更多武器类型（步枪、火箭筒），在这里加新的判断分支即可。
func _create_weapon(data: WeaponData) -> WeaponNode:
	var weapon: WeaponNode

	if data.is_melee:
		weapon = Fist.new()
	elif data.fire_mode == WeaponData.FireMode.PUMP:
		weapon = Shotgun.new()
	elif data.fire_mode == WeaponData.FireMode.AUTO:
		weapon = Rifle.new()
	else:
		weapon = Pistol.new()

	weapon.setup(data, _camera)
	return weapon


# ==============================================================================
# _input(event) — 处理武器切换输入
# ==============================================================================
# 这里只处理"切换"类输入——武器选择、下一把/上一把。
# 射击和换弹输入由 WeaponNode 自己在 _input 中处理，
# 因为它们需要知道武器的状态（换弹中？泵动中？）。
func _input(event: InputEvent) -> void:
	# --- 数字键切武器：按 1~4 切到栏位 0~3 ---
	if event.is_action_pressed("weapon_1"):
		_equip(0)
	if event.is_action_pressed("weapon_2"):
		_equip(1)
	if event.is_action_pressed("weapon_3"):
		_equip(2)
	if event.is_action_pressed("weapon_4"):
		_equip(3)

	# 滚轮事件现在由 IronWhip 统一处理（铁链攻击），不再在 WeaponManager 中消费


# ==============================================================================
# _equip(index) — 装备指定栏位的武器
# ==============================================================================
# 切换流程：
#   1. 检查索引是否有效（不能切到不存在的栏位）
#   2. 如果已经是当前武器 → 什么都不做（避免无用切换）
#   3. 卸下旧武器（隐藏、停止换弹）
#   4. 装备新武器（显示、通知 HUD）
func _equip(index: int) -> void:
	# 边界检查
	if index < 0 or index >= _weapons.size():
		return

	# 已经是当前武器，不重复装备
	if index == _current_index:
		return

	# 卸下旧武器
	if _current_index >= 0:
		_weapons[_current_index]._on_unequip()

	# 装备新武器
	_current_index = index
	var weapon := _weapons[_current_index]
	weapon._on_equip()

	# 通知 HUD 武器切换了
	weapon_changed.emit(weapon.weapon_data.weapon_name, _current_index)


# ==============================================================================
# _next_weapon() / _prev_weapon() — 滚轮切换
# ==============================================================================
# 循环切换：到最后一格后滚回来到第一格，反之亦然。
# 只对至少 2 把武器的情况有意义。

func _next_weapon() -> void:
	if _weapons.size() <= 1:
		return
	var next_idx := (_current_index + 1) % _weapons.size()
	_equip(next_idx)

func _prev_weapon() -> void:
	if _weapons.size() <= 1:
		return
	# + _weapons.size() 确保负数变正数（Godot 的 % 对负数结果也是负数）
	var prev_idx := (_current_index - 1 + _weapons.size()) % _weapons.size()
	_equip(prev_idx)


# ==============================================================================
# reset_all_weapons() — 重置所有武器弹药并切回第一把武器（关卡重启时调用）
# ==============================================================================
# 遍历 _weapons 数组中的每一把武器，调用其 reset_ammo() 方法，
# 把手枪的弹药恢复到 8/50、霰弹枪恢复到 2/20。
#
# 重置后通过 _equip(0) 强制切回栏位 0 的第一把武器。
# 为什么需要切回第一把？
#   如果玩家上一局手持霰弹枪（栏位 1）然后死亡，重启后应该
#   回到手枪（栏位 0），这是 DOOM 传统的"开局只有手枪"体验。
#   _equip() 内部会判断——如果当前已经是栏位 0 则跳过切换，
#   避免不必要的武器卸装。
#
# 调用时机（Phase 2+）：
#   - 选关后进入新关卡时（由 main.gd 的 _start_level() 调用）
#   - 结算界面点击"重新开始"时
#
# 当前 Phase 1.7 通过 reload_current_scene() 重置一切，
# 这个方法暂时未被调用——它是在为 Phase 2 的增量关卡加载做准备。
func reset_all_weapons() -> void:
	for weapon in _weapons:
		weapon.reset_ammo()
		weapon.reset_runtime_modifiers()
	_equip(0)


# ==============================================================================
# get_current_weapon() — 供外部（如 HUD）查询当前武器信息
# ==============================================================================
# 返回当前装备的武器节点，如果没有任何武器则返回 null。
# HUD 通过这个公开方法获取武器引用，而不是直接访问 _weapons 数组。
func get_current_weapon() -> WeaponNode:
	if _current_index < 0 or _current_index >= _weapons.size():
		return null
	return _weapons[_current_index]


## 返回武器栏位总数（HUD 武器栏位显示用）
func get_weapon_count() -> int:
	return _weapons.size()

## 返回指定栏位的武器节点（HUD 武器栏位显示用）
func get_weapon_at(index: int) -> WeaponNode:
	if index < 0 or index >= _weapons.size():
		return null
	return _weapons[index]

## 返回当前装备武器的栏位索引（HUD 显示用）
func get_current_index() -> int:
	return _current_index


func apply_weapon_upgrade(target_id: String, stat_key: String, value: float, operation: int) -> void:
	for weapon in _weapons:
		var matches := false
		if target_id == "all_weapons":
			matches = true
		elif target_id == "rifle" and weapon is Rifle:
			matches = true
		elif target_id == "shotgun" and weapon is Shotgun:
			matches = true
		elif target_id == "pistol" and weapon is Pistol:
			matches = true
		elif target_id == "fist" and weapon is Fist:
			matches = true
		if not matches:
			continue
		_apply_stat(weapon, stat_key, value, operation)


func _apply_stat(weapon: WeaponNode, stat_key: String, value: float, operation: int) -> void:
	match stat_key:
		"damage_mult":
			match operation:
				0: weapon.damage_mult += value
				1: weapon.damage_mult *= value
				2: weapon.damage_mult = value
		"fire_rate_mult":
			match operation:
				0: weapon.fire_rate_mult += value
				1: weapon.fire_rate_mult *= value
				2: weapon.fire_rate_mult = value
		"reload_time_mult":
			match operation:
				0: weapon.reload_time_mult += value
				1: weapon.reload_time_mult *= value
				2: weapon.reload_time_mult = value
		"spread_mult":
			match operation:
				0: weapon.spread_mult += value
				1: weapon.spread_mult *= value
				2: weapon.spread_mult = value
		"pellet_bonus":
			match operation:
				0: weapon.pellet_bonus += int(value)
				1: weapon.pellet_bonus = int(float(weapon.pellet_bonus) * value)
				2: weapon.pellet_bonus = int(value)


func reset_runtime_modifiers() -> void:
	for weapon in _weapons:
		weapon.reset_runtime_modifiers()

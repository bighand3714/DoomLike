# ==============================================================================
# GameBus — 模块间通信信号总线（多 Agent 开发基础设施）
# ==============================================================================
# 唯一 Autoload 单例。只携带信号 + 共享数据引用，不包含游戏逻辑。
#
# 使用模式：模块 A emit 信号 → GameBus → main.gd 连接并转发
#   GameBus.signal_name.emit()
#
# 这替代了 13 处 get_tree().root.get_node_or_null("Main") 硬编码路径，
# 使各模块不需要知道 Main 节点的存在。
# ==============================================================================

class_name GameBus extends Node


# ==============================================================================
# 信号 — 模块到 Main 的通信通道
# ==============================================================================

## 拾取通知请求（ammo_pickup / health_pickup / armor_pickup / iron_whip → Main → HUD）
signal pickup_notification(text: String, color: Color)

## 玩家受击 → 屏幕闪红（player_controller → Main）
signal player_hit(amount: float)

## 暂停切换请求（player_controller / enemy → Main）
signal pause_toggle()

## 盾牌抵挡成功通知（enemy / projectile → Main → HUD）
signal shield_block()

## 抓取状态 HUD 显示（iron_whip → Main → HUD）
signal grab_status_show(enemy_name: String)

## 抓取状态 HUD 隐藏（iron_whip → Main → HUD）
signal grab_status_hide()


# ==============================================================================
# 共享数据引用 — 由 main.gd 在关卡生命周期中设置
# ==============================================================================

## 当前局统计引用（main.gd 在 _start_level() 中设置，_unload_current_level() 中置 null）
var run_stats = null  # RunStats

## 存档数据引用（main.gd 在 _ready() 中设置，持久有效）
var save_data = null  # SaveData

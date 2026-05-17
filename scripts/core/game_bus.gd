# ==============================================================================
# GameBus — 模块间通信信号总线（多 Agent 开发基础设施）
# ==============================================================================
# 唯一 Autoload 单例。只携带信号 + 共享数据引用，不包含游戏逻辑。
#
# 使用模式：模块 A emit 信号 → GameBus → main.gd 连接并转发
#   GameBus.signal_name.emit()
#
# 注意：信号在外部文件中 emit（如 weapon_node 中 GameBus.play_sfx.emit()），
# 所以 GameBus 自身不 emit 这些信号，unused_signal 警告是误报，已压制。
# ==============================================================================

extends Node


# ==============================================================================
# 信号 — 模块到 Main 的通信通道
# ==============================================================================

@warning_ignore("unused_signal")
signal pickup_notification(text: String, color: Color)

@warning_ignore("unused_signal")
signal player_hit(amount: float)

@warning_ignore("unused_signal")
signal pause_toggle()

@warning_ignore("unused_signal")
signal shield_block()

@warning_ignore("unused_signal")
signal grab_status_show(enemy_name: String)

@warning_ignore("unused_signal")
signal grab_status_hide()

@warning_ignore("unused_signal")
signal enemy_death_position(position: Vector3)

@warning_ignore("unused_signal")
signal play_sfx(sfx_name: String, position: Vector3)


# ==============================================================================
# 共享数据引用 — 由 main.gd 在关卡生命周期中设置
# ==============================================================================

var run_stats = null  # RunStats
var save_data = null  # SaveData

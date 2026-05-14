# ==============================================================================
# GameState — 游戏运行状态枚举
# ==============================================================================
# 定义游戏主循环的所有状态，由 main.gd 的 _set_game_state() 统一管理切换。
#
# 状态流转图（Phase 1.7 完整链路）：
#   BOOT → MAIN_MENU → LEVEL_SELECT → PLAYING ⇄ PAUSED
#                ↑            ↑              ↓
#                └──←──←──←──┘         GAME_OVER
#                (返回主菜单)            (玩家死亡)
#
# 每个状态的职责：
#   BOOT         —— 场景刚加载，还没决定进入哪个状态
#   MAIN_MENU    —— 显示"DOOM-LIKE"标题 + 开始游戏/退出按钮，鼠标可见
#   LEVEL_SELECT —— 显示荒漠/熔岩地狱两个关卡选择面板
#   PLAYING      —— 战斗进行中，鼠标捕获、HUD显示、物理运行
#   PAUSED       —— Esc 暂停，覆盖暂停菜单，鼠标释放
#   GAME_OVER    —— 玩家死亡，显示本局分数/时间/击杀 + 历史记录
# ==============================================================================

class_name GameState extends RefCounted

enum State {
	BOOT,          # 启动——加载资源、初始化系统
	MAIN_MENU,     # 主菜单——等待玩家点击"开始游戏"
	LEVEL_SELECT,  # 选关界面——选择荒漠或熔岩地狱
	PLAYING,       # 游戏中——HUD 可见、鼠标捕获、物理运行
	PAUSED,        # 暂停——暂停菜单覆盖、鼠标释放
	GAME_OVER,     # 结算——显示分数和记录
}

# ==============================================================================
# 跨场景重载持久化（Phase 1.7 关卡启动流程专用）
# ==============================================================================
# 问题背景：
#   选关或重新开始时，需要完全重置游戏状态（玩家位置、血量、弹药、敌人等）。
#   最彻底的方式是 get_tree().reload_current_scene()——它会销毁整个场景树并
#   重新加载 main.tscn，相当于"重启游戏"。
#
#   但场景重载有个问题：所有节点的实例变量都会丢失。_ready() 默认会走
#   BOOT → MAIN_MENU 流程，用户选关后又要看一遍主菜单，体验很差。
#
# 解决方案 —— static var：
#   GDScript 的 static var 是绑定在 class 本身而不是实例上的，只要进程不退出，
#   它的值就一直保留，即使场景被 reload_current_scene() 完全销毁重建也不会丢失。
#   类似"写在纸上的便条"——房间拆了重建，便条还在。
#
# 使用方式：
#   1. _start_level(level_id) 在调用 reload_current_scene() 之前，先把关卡 id
#      和"直接进游戏"的标志写入这两个 static var。
#   2. 场景重载后，新的 Main._ready() 检查 pending_level_start：
#        - 如果为 true → 跳过菜单，直接用 pending_level_id 进入 PLAYING 状态
#        - 如果为 false → 正常启动流程，进入 MAIN_MENU
#   3. 进入 PLAYING 后立即将 pending_level_start 重置为 false，避免下次
#      正常回到主菜单时又跳进战斗。
#
# 类比：
#   这是一套"跳关密码"系统。普通开机 → 看到主菜单；输入密码后重启 → 直接进关卡。

## 待启动的关卡 id（"desert" 或 "lava"），用于 _ready() 读取
static var pending_level_id: String = ""

## 是否跳过主菜单直接进入 PLAYING。true = 场景重载后的"热启动"
static var pending_level_start: bool = false

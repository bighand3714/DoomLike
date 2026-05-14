# ==============================================================================
# RunStats — 当前局统计
# ==============================================================================
# RefCounted 数据类，追踪单局游戏的分数、击杀、生存时间。
# 由 main.gd 在 _process 中驱动 update()，HUD 定时读取显示。

class_name RunStats extends RefCounted

var level_id: String = ""
var score: int = 0
var kills: int = 0
var survival_time: float = 0.0
var is_running: bool = false


func start(p_level_id: String) -> void:
	level_id = p_level_id
	score = 0
	kills = 0
	survival_time = 0.0
	is_running = true


func stop() -> void:
	is_running = false


func update(delta: float) -> void:
	if is_running:
		survival_time += delta


func add_score(amount: int) -> void:
	score += amount


func add_kill(score_value: int) -> void:
	kills += 1
	score += score_value

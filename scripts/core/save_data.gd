# ==============================================================================
# SaveData — 存档管理
# ==============================================================================
# 使用 ConfigFile 读写 user://save.cfg，存储每关最高分和最长时间。
# 由 main.gd 在结算时调用 submit_run()，选关界面调用 get_best_*() 显示。

class_name SaveData extends RefCounted

const SAVE_PATH := "user://save.cfg"

var _config: ConfigFile


func _init() -> void:
	_config = ConfigFile.new()
	load_records()


func load_records() -> void:
	var err := _config.load(SAVE_PATH)
	# 首次启动没有存档文件时忽略错误，后续 get 会返回默认值
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("SaveData: 读取存档失败 (%d)" % err)


func save_records() -> void:
	_config.save(SAVE_PATH)


func get_best_score(level_id: String) -> int:
	return _config.get_value(level_id, "best_score", 0)


func get_best_time(level_id: String) -> float:
	return _config.get_value(level_id, "best_time", 0.0)


func submit_run(level_id: String, score: int, time: float) -> Dictionary:
	var best_score := get_best_score(level_id)
	var best_time := get_best_time(level_id)
	var is_new_score := score > best_score
	var is_new_time := time > best_time

	if is_new_score:
		_config.set_value(level_id, "best_score", score)
	if is_new_time:
		_config.set_value(level_id, "best_time", time)

	save_records()

	return {
		best_score = max(score, best_score),
		best_time = max(time, best_time),
		is_new_record = is_new_score or is_new_time,
	}

extends Node

signal run_started()
signal floor_advanced(floor_number: int)

var current_floor: int = 0

var _player_run_data: PlayerRunData = null


func start_new_run() -> void:
	current_floor = 1
	WorldSeed.randomize_seed()
	get_tree().paused = false
	get_tree().reload_current_scene()


func advance_floor() -> void:
	current_floor += 1
	floor_advanced.emit(current_floor)


func register_player_run_data(prd: PlayerRunData) -> void:
	_player_run_data = prd


func get_player_run_data() -> PlayerRunData:
	return _player_run_data

# res://Scripts/Core/GameClock.gd
extends Node

signal time_scale_changed(new_scale: float, old_scale: float)

@export var default_scale: float = 1.0
var _scale: float = 1.0

func _ready() -> void:
	set_scale(default_scale)

func set_scale(new_scale: float) -> void:
	new_scale = clampf(new_scale, 0.0, 4.0)
	if is_equal_approx(new_scale, _scale):
		return
	var old := _scale
	_scale = new_scale
	Engine.time_scale = _scale
	time_scale_changed.emit(_scale, old)

func get_scale() -> float:
	return _scale

func reset_scale() -> void:
	set_scale(default_scale)

# Gameplay timer: respects Engine.time_scale (ignore_time_scale=false)
func timer_gameplay(seconds: float, process_always: bool = false) -> SceneTreeTimer:
	return get_tree().create_timer(seconds, process_always, true, false)

# UI timer: ignores Engine.time_scale (ignore_time_scale=true)
func timer_ui(seconds: float, process_always: bool = true) -> SceneTreeTimer:
	return get_tree().create_timer(seconds, process_always, true, true)

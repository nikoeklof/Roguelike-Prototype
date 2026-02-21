extends Node
class_name LocalTimeScale

@export var scale: float = 1.0

func get_scaled_delta(delta: float) -> float:
	# delta is already Engine.time_scale scaled
	# we counter or modify it locally
	return delta * scale

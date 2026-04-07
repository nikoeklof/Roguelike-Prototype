class_name AIDecision

var state: String  # "idle", "chase", "attack", "defend", "cast", etc.
var priority: int  # Higher = more important
var data: Dictionary = {}  # Module-specific data


func _init(p_state: String, p_priority: int, p_data: Dictionary = {}) -> void:
	state = p_state
	priority = p_priority
	data = p_data

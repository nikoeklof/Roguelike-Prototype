extends Node
class_name StateHandler

var current_state: State
var states: Dictionary = {}
var entity: Entity

func _ready() -> void:
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.state_handler = self

func init(owner_entity: Entity, start_state := "Idle") -> void:
	entity = owner_entity
	for s in states.values():
		s.entity = entity

	change_state(start_state)

func change_state(new_state_name: String) -> void:
	if not states.has(new_state_name):
		push_warning("StateHandler: Unknown state '%s'. Available: %s" % [new_state_name, states.keys()])
		return

	var next_state: State = states[new_state_name]

	if current_state:
		current_state.exit()

	current_state = next_state
	current_state.enter()

func physics_update(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

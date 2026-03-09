extends Node
class_name StateHandler

var current_state: State = null
var states: Dictionary = {}
var entity: Entity = null


func _ready() -> void:
	for child: Node in get_children():
		var state: State = child as State
		if state != null:
			states[state.name] = state
			state.state_handler = self


func init(owner_entity: Entity, start_state: String = "Idle") -> void:
	entity = owner_entity

	for value: Variant in states.values():
		var state: State = value as State
		if state != null:
			state.entity = entity

	change_state(start_state)


func change_state(new_state_name: String, msg: Dictionary = {}) -> void:
	if not states.has(new_state_name):
		push_warning(
			"StateHandler: Unknown state '%s'. Available: %s"
			% [new_state_name, states.keys()]
		)
		return

	var next_state: State = states[new_state_name] as State
	if next_state == null:
		push_warning("StateHandler: State '%s' resolved to null." % new_state_name)
		return

	if current_state != null:
		current_state.exit()

	current_state = next_state
	current_state.enter(msg)


func physics_update(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)

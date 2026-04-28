extends StaticBody2D
class_name Door

enum DoorState { OPEN, CLOSED, BROKEN }

signal state_changed(new_state: DoorState)

@export var initial_state: DoorState = DoorState.CLOSED

var _state: DoorState = DoorState.CLOSED

@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_state = initial_state
	_apply_state()


func get_state() -> DoorState:
	return _state


func is_passable() -> bool:
	return _state != DoorState.CLOSED


# OPEN / CLOSED only — use break_door() for BROKEN.
func set_state(new_state: DoorState) -> void:
	assert(new_state != DoorState.BROKEN, "Door: use break_door() to break a door.")
	if _state == DoorState.BROKEN or _state == new_state:
		return
	_state = new_state
	_apply_state()
	state_changed.emit(_state)


func open() -> void:
	set_state(DoorState.OPEN)


func close() -> void:
	set_state(DoorState.CLOSED)


func break_door() -> void:
	if _state == DoorState.BROKEN:
		return
	_state = DoorState.BROKEN
	_apply_state()
	state_changed.emit(_state)


func _apply_state() -> void:
	if not is_instance_valid(_collision):
		return
	_collision.set_deferred("disabled", _state != DoorState.CLOSED)
	_on_visual_state_changed(_state)


# No-op until art is wired. Override or connect state_changed signal.
func _on_visual_state_changed(_new_state: DoorState) -> void:
	pass

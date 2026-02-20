extends Area2D
class_name PickupBase

@export var interact_action: StringName = &"interact"

var _in_range_entity: Node = null

func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if _in_range_entity == null:
		return
	if event.is_action_pressed(interact_action):
		if on_interact(_in_range_entity):
			# Default behavior: consume pickup
			queue_free()

# Override in subclasses.
# Return true to consume (queue_free), false to keep.
func on_interact(_entity: Node) -> bool:
	return false

func _on_body_entered(body: Node) -> void:
	# Keep it flexible: allow player by group OR name fallback.
	if body.is_in_group("player") or body.name == "Player":
		_in_range_entity = body

func _on_body_exited(body: Node) -> void:
	if body == _in_range_entity:
		_in_range_entity = null

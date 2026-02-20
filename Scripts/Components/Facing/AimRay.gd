extends RayCast2D
class_name AimRay

@export_range(1.0, 1000.0, 1.0) var ray_length: float = 96.0

func _ready() -> void:
	# Ensure a sensible default length
	target_position = Vector2(ray_length, 0.0)

func _physics_process(_delta: float) -> void:
	var entity := _find_entity_root()
	if entity == null:
		return

	var control := _get_control(entity)
	if control == null:
		return

	var fallback := Vector2.RIGHT
	var fp := entity.get_node_or_null("FacingPointer") as FacingPointer
	if fp != null and fp.facing_vector.length() > 0.001:
		fallback = fp.facing_vector

	var dir := control.aim_dir(fallback)
	if dir.length() < 0.001:
		dir = fallback
	else:
		dir = dir.normalized()

	global_rotation = dir.angle()
	target_position = Vector2(ray_length, 0.0) # local X forward (rotation handles direction)


func _get_control(entity: Node) -> ControlSource:
	var c := entity.get_node_or_null("ControlSource") as ControlSource
	if c != null:
		return c
	# legacy fallback
	return entity.get_node_or_null("Control") as ControlSource


func _find_entity_root() -> CharacterBody2D:
	var n: Node = self
	while n != null:
		if n is CharacterBody2D:
			return n as CharacterBody2D
		n = n.get_parent()
	return null

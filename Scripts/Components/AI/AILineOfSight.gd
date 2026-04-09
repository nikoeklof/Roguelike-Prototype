extends RefCounted
class_name AILineOfSight

## Lightweight LOS utility for AI.
## Raycasts against the world collision layer (bit 0) to check
## if there is a clear path between two points.

## World geometry collision layer (bit 0 = layer 1)
const WORLD_COLLISION_LAYER: int = 1


static func has_line_of_sight(from_node: Node2D, to_pos: Vector2) -> bool:
	"""Returns true if nothing on the world layer blocks the line from from_node to to_pos."""
	if from_node == null or not is_instance_valid(from_node):
		return false

	var space_state: PhysicsDirectSpaceState2D = from_node.get_world_2d().direct_space_state
	if space_state == null:
		return false

	var query := PhysicsRayQueryParameters2D.new()
	query.from = from_node.global_position
	query.to = to_pos
	query.collision_mask = WORLD_COLLISION_LAYER
	query.collide_with_areas = false
	query.collide_with_bodies = true

	# Exclude the casting entity itself
	query.exclude = [from_node.get_rid()]

	var result: Dictionary = space_state.intersect_ray(query)
	# If nothing hit, we have clear LOS
	return result.is_empty()


static func has_los_to_target(from_node: Node2D, target: Node2D) -> bool:
	"""Convenience: check LOS from one node to another."""
	if target == null or not is_instance_valid(target):
		return false
	return has_line_of_sight(from_node, target.global_position)

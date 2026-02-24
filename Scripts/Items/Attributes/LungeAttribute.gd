extends ItemAttribute
class_name LungeAttribute

# Simple deterministic lunge on attack start.
# No loops: just a position impulse.

@export var distance: float = 22.0

func on_attack_start(context: CombatContext, item_instance: ItemInstance) -> void:
	if context == null or context.owner == null:
		return
	var owner := context.owner
	if not (owner is Node2D):
		return

	var dir := context.aim_dir
	if dir.length() < 0.001:
		dir = Vector2.RIGHT
	dir = dir.normalized()

	(owner as Node2D).global_position += dir * distance

extends ItemAttribute
class_name ParryWindowAttribute

@export_range(0.05, 0.5, 0.01) var window_sec: float = 0.15
@export var collider_size: Vector2 = Vector2(26, 18)
@export var local_offset: Vector2 = Vector2(16, 0)

func default_domains() -> PackedStringArray:
	return PackedStringArray(["parry"])

func on_parry(context: CombatContext, _item_instance: ItemInstance) -> void:
	if context == null or context.owner == null:
		return
	if not (context.owner is Node2D):
		return

	var owner := context.owner

	var pc := ParryCollider.new()
	pc.name = "ParryCollider"
	# Put it under FacingPointer so it follows aim rotation
	var parent := owner.get_node_or_null("FacingPointer/AimRay") as Node2D
	if parent == null:
		parent = owner as Node2D

	parent.add_child(pc)
	pc.position = Vector2.ZERO
	pc.rotation = 0.0
	pc.setup(owner, collider_size, local_offset, window_sec, false)

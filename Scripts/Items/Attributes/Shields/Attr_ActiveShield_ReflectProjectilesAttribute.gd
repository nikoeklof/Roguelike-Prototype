extends ItemAttribute
class_name ReflectProjectilesAttribute

@export_range(0.05, 0.6, 0.01) var window_sec: float = 0.20
@export var collider_size: Vector2 = Vector2(28, 18)
@export var local_offset: Vector2 = Vector2(16, 0)
@export_range(0.5, 3.0, 0.05) var reflect_speed_mult: float = 1.0

func default_domains() -> PackedStringArray:
	return PackedStringArray(["parry"])

func on_parry(context: CombatContext, _item_instance: ItemInstance) -> void:
	if context == null or context.owner == null:
		return
	if not (context.owner is Node2D):
		return

	var owner := context.owner

	var pc := ParryCollider.new()
	pc.name = "ReflectCollider"
	pc.reflect_speed_mult = reflect_speed_mult

	var parent := owner.get_node_or_null("FacingPointer/AimRay") as Node2D
	if parent == null:
		parent = owner as Node2D

	parent.add_child(pc)
	pc.position = Vector2.ZERO
	pc.rotation = 0.0
	pc.setup(owner, collider_size, local_offset, window_sec, true)

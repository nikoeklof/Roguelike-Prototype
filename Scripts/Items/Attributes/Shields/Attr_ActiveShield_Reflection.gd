extends ItemAttribute
class_name ProjectileReflectionAttribute

@export_range(0.05, 0.6, 0.01) var reflection_window_sec: float = 0.25
@export var reflector_size: Vector2 = Vector2(32, 20)
@export var reflector_offset: Vector2 = Vector2(18, 0)
@export_range(0.5, 3.0, 0.05) var reflect_speed_mult: float = 1.2

func default_domains() -> PackedStringArray:
	return PackedStringArray(["parry"])

func on_parry(context: CombatContext, _item_instance: ItemInstance) -> void:
	if context == null or context.owner == null:
		return
	if not (context.owner is Node2D):
		return

	var owner := context.owner

	var pc := ParryCollider.new()
	pc.name = "ProjectileReflector"
	pc.reflect_speed_mult = reflect_speed_mult

	var parent := owner.get_node_or_null("FacingPointer/AimRay") as Node2D
	if parent == null:
		parent = owner as Node2D

	parent.add_child(pc)
	pc.position = Vector2.ZERO
	pc.rotation = 0.0
	pc.setup(owner, reflector_size, reflector_offset, reflection_window_sec, true)
	
	print("[ProjectileReflectionAttribute] Reflection window active for %.2fs" % reflection_window_sec)

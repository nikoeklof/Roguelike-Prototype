extends ItemAttribute
class_name ProjectileReflectionAttribute

@export_range(0.05, 0.6, 0.01) var reflection_window_sec: float = 0.25
@export var reflector_size: Vector2 = Vector2(32, 20)
@export var reflector_offset: Vector2 = Vector2(18, 0)
@export_range(0.5, 3.0, 0.05) var reflect_speed_mult: float = 1.2

func default_domains() -> PackedStringArray:
	return PackedStringArray(["block_start"])

func on_block_start(_context: CombatContext, _item_instance: ItemInstance) -> void:
	# Collider creation is handled by ActiveShield._create_blocking_collider(),
	# which reads this attribute to set reflect=true on the persistent collider.
	pass

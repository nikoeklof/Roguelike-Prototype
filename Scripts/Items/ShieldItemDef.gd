extends ItemDef
class_name ShieldItemDef

enum ShieldType { ACTIVE, PASSIVE }

@export var shield_type: ShieldType = ShieldType.ACTIVE

# Active shield properties
@export var block_damage_reduction: float = 0.7
@export var movement_speed_mult_while_blocking: float = 0.65

# Shield health (active shields only). Set max_hp to 0 to disable (infinite block).
@export_group("Active Shield Health")
@export_range(0.0, 1000.0, 1.0) var shield_max_hp: float = 100.0
@export_range(0.0, 200.0, 0.5) var shield_regen_rate: float = 20.0
@export_range(0.0, 10.0, 0.1) var shield_regen_delay: float = 3.0

# Blocking collider configuration (only for ACTIVE shields)
@export_group("Active Shield Blocking Collider")
@export var blocking_collider_size: Vector2 = Vector2(60, 40)
@export var blocking_collider_offset: Vector2 = Vector2(30, 0)
@export var blocking_collider_duration: float = 0.2

# Passive shield properties
@export_group("Passive Shield")
@export var passive_damage_reduction_mult: float = 0.1
@export var passive_movement_speed_mult: float = 0.95

# Flat damage reduction (applies to both active and passive)
@export var flat_damage_reduction: float = 0.0

func get_display_name() -> String:
	var type_name = ShieldType.keys()[shield_type]
	return "%s (%s)" % [resource_name, type_name]

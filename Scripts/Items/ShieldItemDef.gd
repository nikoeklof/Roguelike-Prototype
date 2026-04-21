extends ItemDef
class_name ShieldItemDef

enum ShieldType { ACTIVE, PASSIVE }

@export var stats: ShieldItemStats

@export_group("Shield Config")
@export var shield_type: ShieldType = ShieldType.ACTIVE

@export_group("Active Shield")
@export var block_damage_reduction: float = 0.7
@export var movement_speed_mult_while_blocking: float = 0.65

@export_group("Active Shield Health")
@export_range(0.0, 1000.0, 1.0) var shield_max_hp: float = 100.0
@export_range(0.0, 200.0, 0.5) var shield_regen_rate: float = 20.0
@export_range(0.0, 10.0, 0.1) var shield_regen_delay: float = 3.0

@export_group("Active Shield Blocking Collider")
@export var blocking_collider_size: Vector2 = Vector2(60, 40)
@export var blocking_collider_offset: Vector2 = Vector2(30, 0)
@export var blocking_collider_duration: float = 0.2

@export_group("Passive Shield")
@export var passive_damage_reduction_mult: float = 0.1
@export var passive_movement_speed_mult: float = 0.95

func _init() -> void:
	category = Category.SHIELD


func _validate_property(property: Dictionary) -> void:
	if property["name"] == "base_stats":
		property["usage"] = PROPERTY_USAGE_NONE


func get_display_name() -> String:
	var type_name = ShieldType.keys()[shield_type]
	return "%s (%s)" % [resource_name, type_name]

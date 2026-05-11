extends Resource
class_name HealthPickupDef

enum HealType { FLAT, PERCENT }

@export var heal_type: HealType = HealType.FLAT
@export var value: float = 25.0
@export var display_name: String = "Health Pack"
@export var color: Color = Color(0.2, 0.9, 0.2)

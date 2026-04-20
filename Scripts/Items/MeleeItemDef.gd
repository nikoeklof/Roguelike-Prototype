extends ItemDef
class_name MeleeItemDef

func _init() -> void:
	category = Category.MELEE

@export var stats: MeleeItemStats

@export_group("Melee Style")
@export var swing_style: MeleeSlashVariant.SwingStyle = MeleeSlashVariant.SwingStyle.SWING
@export_range(30.0, 270.0, 5.0) var arc_degrees: float = 160.0
@export_range(0.0, 1.0, 0.05) var shield_penetration: float = 0.0
@export_range(0.0, 800.0, 10.0) var lunge_speed: float = 0.0


func _validate_property(property: Dictionary) -> void:
	if property["name"] == "base_stats":
		property["usage"] = PROPERTY_USAGE_NONE

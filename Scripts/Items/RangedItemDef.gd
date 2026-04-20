extends ItemDef
class_name RangedItemDef

func _init() -> void:
	category = Category.RANGED

@export var stats: RangedItemStats


func _validate_property(property: Dictionary) -> void:
	if property["name"] == "base_stats":
		property["usage"] = PROPERTY_USAGE_NONE

extends ItemStats
class_name RangedItemStats

## ItemStats subclass for ranged weapons.
## Hides melee-only fields (active_time, knockback, hitbox_offset, hitbox_size)
## from the inspector so designers only see fields meaningful for ranged items.
## The hidden fields remain at their default values and are still safe to read in code.

func _validate_property(property: Dictionary) -> void:
	var MELEE_ONLY: PackedStringArray = PackedStringArray([
		"active_time",
		"knockback",
		"hitbox_offset",
		"hitbox_size",
	])
	if property["name"] in MELEE_ONLY:
		property["usage"] = PROPERTY_USAGE_STORAGE

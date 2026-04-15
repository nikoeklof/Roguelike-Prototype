extends ItemStats
class_name MeleeItemStats

## ItemStats subclass for melee weapons.
## Hides ranged-only fields (projectile_count, pierce, spread, muzzle_offset, is_automatic)
## from the inspector so designers only see fields that are meaningful for melee items.
## The hidden fields remain at their default values and are still safe to read in code.

func _validate_property(property: Dictionary) -> void:
	var RANGED_ONLY: PackedStringArray = PackedStringArray([
		"is_automatic",
		"projectile_count",
		"pierce",
		"spread_degrees",
		"spread_pattern_degrees",
		"muzzle_offset",
	])
	if property["name"] in RANGED_ONLY:
		property["usage"] = PROPERTY_USAGE_STORAGE

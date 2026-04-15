extends ItemStats
class_name ShieldItemStats

## ItemStats subclass for shield items.
## Hides all attack-specific fields so the inspector only shows stats relevant
## to a shield: defensive multipliers, HP bonuses, and heal-on-equip.
## Hidden fields remain at default values and are still safe to read in code.

func _validate_property(property: Dictionary) -> void:
	var ATTACK_ONLY: PackedStringArray = PackedStringArray([
		"damage",
		"is_automatic",
		"projectile_count",
		"pierce",
		"spread_degrees",
		"spread_pattern_degrees",
		"muzzle_offset",
		"active_time",
		"knockback",
		"hitbox_offset",
		"hitbox_size",
	])
	if property["name"] in ATTACK_ONLY:
		property["usage"] = PROPERTY_USAGE_STORAGE

extends ItemAttribute
class_name FortifyAttribute

@export_range(0.0, 0.5, 0.05) var additional_damage_reduction: float = 0.15

func default_domains() -> PackedStringArray:
	return PackedStringArray(["stats"])

func get_stat_additive(_context: CombatContext, _item_instance: ItemInstance) -> ItemStats:
	var stats := ItemStats.new()
	stats.damage_taken_mult = 1.0 - additional_damage_reduction
	return stats

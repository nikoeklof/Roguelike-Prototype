extends ItemAttribute
class_name ShieldBonusAttribute

@export_range(0.0, 1.0, 0.05) var damage_reduction_bonus: float = 0.05
@export_range(0.0, 20.0, 1.0) var flat_reduction_bonus: float = 2.0

func default_domains() -> PackedStringArray:
	return PackedStringArray(["stats"])

func get_stat_additive(_context: CombatContext, _item_instance: ItemInstance) -> ItemStats:
	var stats := ItemStats.new()
	stats.flat_damage_reduction = flat_reduction_bonus
	stats.damage_taken_mult = 1.0 - damage_reduction_bonus
	return stats

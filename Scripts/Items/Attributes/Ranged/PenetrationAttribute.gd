extends ItemAttribute
class_name PenetrationAttribute

@export_range(1, 10, 1) var extra_pierce: int = 1

func get_stat_additive(_context: CombatContext, _item_instance: ItemInstance) -> ItemStats:
	var s := ItemStats.new()
	s.pierce = extra_pierce
	return s


func default_domains() -> PackedStringArray:
	return PackedStringArray([String(AttributeDomains.STATS)])

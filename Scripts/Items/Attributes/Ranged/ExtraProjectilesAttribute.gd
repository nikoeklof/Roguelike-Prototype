extends ItemAttribute
class_name ExtraProjectilesAttribute

@export_range(1, 10, 1) var extra_projectiles: int = 1

func get_stat_additive(_context: CombatContext, _item_instance: ItemInstance) -> ItemStats:
	var s := ItemStats.new()
	s.projectile_count = extra_projectiles
	return s


func default_domains() -> PackedStringArray:
	return PackedStringArray([String(AttributeDomains.STATS)])

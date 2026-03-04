extends ItemAttribute
class_name ExtraProjectilesAttribute

@export_range(1, 10, 1) var extra_projectiles: int = 1

func default_domains() -> PackedStringArray:
	return PackedStringArray(["stats"])

func contribute_modifiers(_context: CombatContext, _item_instance: ItemInstance, _domain: StringName, out_mods: Array) -> void:
	# Int ADD
	out_mods.append(StatModifier.new(StatId.PROJECTILE_COUNT, StatModifier.Op.ADD, extra_projectiles, 50, id))

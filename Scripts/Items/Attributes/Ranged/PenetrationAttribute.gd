extends ItemAttribute
class_name PenetrationAttribute

@export_range(1, 10, 1) var extra_pierce: int = 1

func default_domains() -> PackedStringArray:
	return PackedStringArray(["stats"])

func contribute_modifiers(_context: CombatContext, _item_instance: ItemInstance, _domain: StringName, out_mods: Array) -> void:
	out_mods.append(StatModifier.new(StatId.PIERCE, StatModifier.Op.ADD, extra_pierce, 50, id))

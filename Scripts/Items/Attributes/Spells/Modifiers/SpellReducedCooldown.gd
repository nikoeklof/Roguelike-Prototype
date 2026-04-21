extends ItemAttribute
class_name SpellReducedCooldown

@export_range(0.1, 10.0, 0.1) var reduction_sec: float = 1.5


func default_domains() -> PackedStringArray:
	return PackedStringArray(["stats"])


func contribute_modifiers(_context: CombatContext, _inst: ItemInstance, _domain: StringName, out: Array) -> void:
	out.append(StatModifier.new(StatId.COOLDOWN_SEC, StatModifier.Op.ADD, -reduction_sec, 50, id))

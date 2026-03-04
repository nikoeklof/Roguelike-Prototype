extends ItemAttribute
class_name BonusDamageOnHitAttribute

# Adds flat + percent damage on hit (demonstrates on_hit hook).
@export var flat_bonus: float = 0.5
@export_range(0.0, 5.0, 0.05) var percent_bonus: float = 0.15

func default_domains() -> PackedStringArray:
	return PackedStringArray(["hit"])

func on_hit(_context: CombatContext, hit: HitEvent, _item_instance: ItemInstance) -> void:
	if hit == null:
		return
	# Modify final damage.
	hit.damage = (hit.damage + flat_bonus) * (1.0 + percent_bonus)

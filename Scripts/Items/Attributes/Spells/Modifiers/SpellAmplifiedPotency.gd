extends ItemAttribute
class_name SpellAmplifiedPotency

@export_range(1.05, 2.0, 0.05) var potency_mult: float = 1.3


func get_spell_potency_mult() -> float:
	return potency_mult

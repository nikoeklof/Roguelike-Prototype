extends ItemAttribute
class_name SpellExtendedDuration

@export_range(1.1, 3.0, 0.05) var duration_mult: float = 1.5


func get_spell_duration_mult() -> float:
	return duration_mult

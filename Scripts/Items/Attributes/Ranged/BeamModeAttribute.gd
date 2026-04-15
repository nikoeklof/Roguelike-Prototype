extends ItemAttribute
class_name BeamModeAttribute

@export var max_range: float = 900.0

func default_domains() -> PackedStringArray:
	return PackedStringArray(["ranged_shot"])

func modify_ranged_shot(_context: CombatContext, shot: RangedShotData, _inst: ItemInstance) -> void:
	shot.mode = RangedShotData.ShotMode.BEAM
	shot.max_range = max_range

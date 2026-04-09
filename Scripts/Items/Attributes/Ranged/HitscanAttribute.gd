extends ItemAttribute
class_name HitscanModeAttribute

@export var max_range: float = 1100.0

func default_domains() -> PackedStringArray:
	return PackedStringArray(["ranged_shot"])

func modify_ranged_shot(_context: CombatContext, shot: RangedShotData, _inst: ItemInstance) -> void:
	shot.mode = RangedShotData.ShotMode.HITSCAN
	shot.range = max_range

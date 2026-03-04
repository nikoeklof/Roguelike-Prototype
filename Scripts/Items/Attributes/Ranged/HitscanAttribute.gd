extends ItemAttribute
class_name HitscanModeAttribute

@export var range: float = 1100.0

func modify_ranged_shot(_context: CombatContext, shot: RangedShotData, _inst: ItemInstance) -> void:
	shot.mode = RangedShotData.ShotMode.HITSCAN
	shot.range = range

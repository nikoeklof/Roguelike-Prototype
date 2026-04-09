extends ItemAttribute
class_name BeamModeAttribute

@export var duration_sec: float = 0.5
@export var tick_sec: float = 0.08
@export var max_range: float = 900.0

func default_domains() -> PackedStringArray:
	return PackedStringArray(["ranged_shot"])

func modify_ranged_shot(_context: CombatContext, shot: RangedShotData, _inst: ItemInstance) -> void:
	shot.mode = RangedShotData.ShotMode.BEAM
	shot.beam_duration_sec = duration_sec
	shot.beam_tick_sec = tick_sec
	shot.range = max_range

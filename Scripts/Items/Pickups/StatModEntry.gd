extends Resource
class_name StatModEntry

enum StatTarget {
	MOVE_SPEED_MULT,
	ATTACK_SPEED_MULT,
	DAMAGE_TAKEN_MULT,
	FLAT_DAMAGE_REDUCTION,
	MELEE_DAMAGE_MULT,
	RANGED_DAMAGE_MULT,
	COOLDOWN_REDUCTION,
	ACCEL_MULT,
}

@export var stat: StatTarget = StatTarget.MOVE_SPEED_MULT
@export var value: float = 1.1
@export var label: String = ""

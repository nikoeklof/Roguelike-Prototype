extends ItemDef
class_name MeleeItemDef

func _init() -> void:
	category = Category.MELEE

@export_group("Melee Style")

## Attack swing style — drives hitbox motion during the active phase.
@export var swing_style: MeleeSlashVariant.SwingStyle = MeleeSlashVariant.SwingStyle.SWING

## Full arc angle in degrees for SWING and OVERHEAD. STAB ignores this.
@export_range(30.0, 270.0, 5.0) var arc_degrees: float = 160.0

## Fraction of damage that passes through an active shield (0 = fully soaked, 1 = ignores shield).
@export_range(0.0, 1.0, 0.05) var shield_penetration: float = 0.0

## Velocity impulse applied to the attacker at the start of the active phase.
@export_range(0.0, 800.0, 10.0) var lunge_speed: float = 0.0

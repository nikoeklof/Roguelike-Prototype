extends AttackVariant
class_name MeleeSlashVariant

enum SwingStyle {
	SWING    = 0,  ## Bilateral arc sweep centered on aim. Wide coverage, fully blocked by shields.
	OVERHEAD = 1,  ## Power slam from one side through to aim direction. Partially penetrates shields.
	STAB     = 2,  ## Linear thrust along aim direction. Narrow, high shield penetration.
}

# Hitbox geometry (local to hitbox node; used as the swept shape)
@export var offset: Vector2 = Vector2(18, 0)
@export var size: Vector2 = Vector2(26, 18)

# Behavior
@export var one_hit_per_target: bool = true

# Attack style
@export var swing_style: SwingStyle = SwingStyle.SWING

## Full arc angle in degrees for SWING and OVERHEAD styles.
## SWING sweeps ±half on each side of aim. OVERHEAD sweeps mostly from one side.
@export_range(30.0, 270.0, 5.0) var arc_degrees: float = 160.0

## Fraction of damage that bypasses the victim's active shield (0 = fully soaked, 1 = ignores shield).
@export_range(0.0, 1.0, 0.05) var shield_penetration: float = 0.0

## Velocity impulse applied to the attacker along aim direction at attack start.
## Gives the attack a physical lunge feel. 0 = no movement.
@export_range(0.0, 800.0, 10.0) var lunge_speed: float = 0.0

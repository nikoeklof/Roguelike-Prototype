extends Node
class_name Mover

# Base values now come from Stats component, not direct exports
@export_range(0.0, 2000.0, 1.0) var move_speed := 250.0
@export_range(0.0, 10000.0, 1.0) var acceleration := 800.0
@export_range(0.0, 10000.0, 1.0) var friction := 900.0
@export_range(0.0, 50.0, 0.1) var deadzone := 5.0

var intent: Vector2 = Vector2.ZERO

func apply(entity: CharacterBody2D, delta: float) -> void:
	# Capability gate lives in the execution component (Mover).
	# If movement is blocked, we do NOT allow new acceleration,
	# but we preserve existing momentum and let friction slow us down.
	var ent := entity as Entity

	var move_blocked := false
	if ent != null:
		var caps := ent.find_component(&"Capabilities") as Capabilities
		if caps != null and caps.is_blocked(Capabilities.CAN_MOVE):
			move_blocked = true

	var speed_mult := 1.0
	var accel_mult := 1.0
	var friction_mult := 1.0

	var stats: Stats = null
	if ent != null:
		stats = ent.find_component(&"Stats") as Stats
	else:
		stats = entity.get_node_or_null("Stats") as Stats

	if stats != null:
		speed_mult = stats.move_speed_mult()
		accel_mult = stats.accel_mult()
		friction_mult = stats.friction_mult()

	# Effective intent: blocked movement ignores input
	var eff_intent := Vector2.ZERO if move_blocked else intent
	var target := eff_intent * (move_speed * speed_mult)

	if eff_intent != Vector2.ZERO:
		entity.velocity = entity.velocity.move_toward(target, (acceleration * accel_mult) * delta)
	else:
		entity.velocity = entity.velocity.move_toward(Vector2.ZERO, (friction * friction_mult) * delta)

	if entity.velocity.length() < deadzone:
		entity.velocity = Vector2.ZERO

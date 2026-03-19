extends Node
class_name Mover

# Base values - fallback if Stats doesn't exist
@export_range(0.0, 2000.0, 1.0) var move_speed := 250.0
@export_range(0.0, 10000.0, 1.0) var acceleration := 800.0
@export_range(0.0, 10000.0, 1.0) var friction := 900.0
@export_range(0.0, 50.0, 0.1) var deadzone := 5.0

var intent: Vector2 = Vector2.ZERO

func apply(entity: CharacterBody2D, delta: float) -> void:
	# Capability gate lives in the execution component (Mover).
	# If movement is blocked, we do NOT allow new acceleration,
	# but we preserve existing momentum and let friction slow us down.
	var ent : Entity = entity as Entity

	var move_blocked := false
	if ent != null:
		var caps := ent.find_component(&"Capabilities") as Capabilities
		if caps != null and caps.is_blocked(Capabilities.CAN_MOVE):
			move_blocked = true

	# Get stats and use effective values if available
	var stats: Stats = null
	if ent != null:
		stats = ent.find_component(&"Stats") as Stats
	else:
		stats = entity.get_node_or_null("Stats") as Stats

	# Use effective values from Stats if available, otherwise use exports with multipliers
	var effective_move_speed: float
	var effective_accel: float
	var effective_friction: float
	var effective_deadzone: float

	if stats != null:
		effective_move_speed = stats.effective_move_speed()
		effective_accel = stats.effective_acceleration()
		effective_friction = stats.effective_friction()
		effective_deadzone = stats.get_deadzone()
	else:
		# Fallback to exports with multipliers
		var speed_mult := 1.0
		var accel_mult := 1.0
		var friction_mult := 1.0
		effective_move_speed = move_speed * speed_mult
		effective_accel = acceleration * accel_mult
		effective_friction = friction * friction_mult
		effective_deadzone = deadzone

	# Effective intent: blocked movement ignores input
	var eff_intent := Vector2.ZERO if move_blocked else intent
	var target := eff_intent * effective_move_speed

	if eff_intent != Vector2.ZERO:
		entity.velocity = entity.velocity.move_toward(target, effective_accel * delta)
	else:
		entity.velocity = entity.velocity.move_toward(Vector2.ZERO, effective_friction * delta)

	if entity.velocity.length() < effective_deadzone:
		entity.velocity = Vector2.ZERO
	

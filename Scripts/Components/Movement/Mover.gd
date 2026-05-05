extends Node
class_name Mover

# Base values - fallback if Stats doesn't exist
@export_range(0.0, 2000.0, 1.0) var move_speed := 250.0
@export_range(0.0, 10000.0, 1.0) var acceleration := 800.0
@export_range(0.0, 10000.0, 1.0) var friction := 900.0
@export_range(0.0, 50.0, 0.1) var deadzone := 5.0

## Mass used for collision-based momentum transfer.
## Heavier objects push lighter ones harder and lose less speed doing so.
@export_range(1.0, 9999.0, 1.0) var mass: float = 70.0

var intent: Vector2 = Vector2.ZERO

## Cached from the previous frame's collision pass.
## Scales max speed when pushing objects heavier than self.
var _push_speed_factor: float = 1.0

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
	# Scale max speed by push resistance from last frame's heavy-object collision.
	var target := eff_intent * effective_move_speed * _push_speed_factor

	# Apply acceleration or friction
	if eff_intent != Vector2.ZERO:
		# Accelerate towards target
		entity.velocity = entity.velocity.move_toward(target, effective_accel * delta)
	else:
		# No input - apply normalized friction to slow down gradually
		# Friction is applied proportionally to current speed so stopping time is consistent
		var velocity_magnitude := entity.velocity.length()
		if velocity_magnitude > 0.0:
			# Normalized friction: multiply by speed ratio so it takes the same time regardless of actual speed
			var friction_per_second := effective_friction / effective_move_speed
			var new_magnitude := maxf(0.0, velocity_magnitude - (velocity_magnitude * friction_per_second * delta))
			if new_magnitude > 0.0:
				entity.velocity = entity.velocity.normalized() * new_magnitude
			else:
				entity.velocity = Vector2.ZERO
		else:
			entity.velocity = Vector2.ZERO

	# Apply deadzone
	if entity.velocity.length() < effective_deadzone:
		entity.velocity = Vector2.ZERO
	
	# Save velocity before move_and_slide — slide zeroes the approach component,
	# so approach_speed must be computed from pre-slide velocity.
	var pre_slide_velocity := entity.velocity

	# Actually move the entity
	entity.move_and_slide()

	# Collision-based momentum transfer + push resistance for next frame.
	var next_push_factor := 1.0
	for i: int in entity.get_slide_collision_count():
		var col: KinematicCollision2D = entity.get_slide_collision(i)
		var other: Object = col.get_collider()
		var push_dir: Vector2 = -col.get_normal()
		var approach_speed: float = pre_slide_velocity.dot(push_dir)
		if approach_speed <= 0.0:
			continue

		if other is RigidBody2D:
			var rb := other as RigidBody2D
			var combined := mass + rb.mass
			# Track the most restrictive resistance from all current RigidBody contacts.
			next_push_factor = minf(next_push_factor, mass / combined)
			var prop_delta_v := approach_speed * mass / combined
			rb.apply_central_impulse(push_dir * prop_delta_v * rb.mass)
		elif other is CharacterBody2D:
			var other_mover: Mover = (other as Node).get_node_or_null("Mover") as Mover
			if other_mover == null:
				continue
			var combined := mass + other_mover.mass
			next_push_factor = minf(next_push_factor, mass / combined)
			var transferred: float = approach_speed * mass / combined
			(other as CharacterBody2D).velocity += push_dir * transferred

	_push_speed_factor = next_push_factor

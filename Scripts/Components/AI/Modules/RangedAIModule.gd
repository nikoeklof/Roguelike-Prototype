extends AIBehaviorModule
class_name RangedAIModule

@export var preferred_distance: float = 200.0
@export var min_distance: float = 100.0
@export var max_distance: float = 400.0
@export var kite_speed_mult: float = 0.8


func decide(context: Dictionary) -> AIDecision:
	if _target == null or _combat == null:
		return null

	var distance: float = context.get("distance", INF)
	var ranged_cooldown: float = context.get("ranged_cooldown", 0.0)
	var is_ready: bool = ranged_cooldown <= 0.0

	var has_los: bool = context.get("has_los", false)
	var invuln: bool = context.get("target_invulnerable", false)
	var repositioning: bool = context.get("repositioning", false)

	# Attack only if LOS, not invuln, not repositioning
	if is_ready and distance <= max_distance and distance >= min_distance and has_los and (not invuln) and (not repositioning):
		return AIDecision.new("ranged_attack", 95, {"ready": true, "distance": distance})

	# Otherwise kite to get in range / reposition (even without LOS)
	if distance <= context.get("aggro_range", 300.0):
		return AIDecision.new("kite", 80, {
			"ready": is_ready,
			"distance": distance,
			"preferred": preferred_distance,
			"cooldown": ranged_cooldown
		})

	return null


func physics_update(delta: float, decision: AIDecision) -> void:
	"""Handle kiting movement"""
	if decision == null or decision.state != "kite" or _target == null or _mover == null:
		return

	var distance: float = _entity.global_position.distance_to(_target.global_position)
	var direction: Vector2 = (_target.global_position - _entity.global_position).normalized()

	# Kite: move away if too close, toward if too far, hold if perfect
	if distance < min_distance:
		_mover.intent = -direction * kite_speed_mult
	elif distance > max_distance:
		_mover.intent = direction * kite_speed_mult
	else:
		_mover.intent = Vector2.ZERO

	if _entity is CharacterBody2D:
		_mover.apply(_entity as CharacterBody2D, delta)

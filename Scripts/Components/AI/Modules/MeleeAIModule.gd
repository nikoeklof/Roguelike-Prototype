extends AIBehaviorModule
class_name MeleeAIModule

@export var attack_range: float = 50.0
@export var stop_distance: float = 40.0
@export var chase_speed_mult: float = 1.0
@export var separation_distance: float = 20.0


func decide(context: Dictionary) -> AIDecision:
	"""Decide melee action based on context"""
	if _target == null or _combat == null:
		return null
	
	var distance: float = context.get("distance", INF)
	var melee_cooldown: float = context.get("melee_cooldown", 0.0)
	var is_ready: bool = melee_cooldown <= 0.0
	
	# Priority 100: Attack if ready and in range
	if distance <= attack_range and is_ready:
		return AIDecision.new("melee_attack", 100, {
			"ready": true,
			"distance": distance
		})
	
	# Priority 70: Chase if in range to attack soon
	if distance <= context.get("aggro_range", 300.0):
		return AIDecision.new("chase", 70, {
			"ready": is_ready,
			"distance": distance,
			"cooldown": melee_cooldown
		})
	
	return null


func physics_update(delta: float, decision: AIDecision) -> void:
	"""Handle movement with overlap protection"""
	if decision == null or decision.state != "chase" or _target == null or _mover == null:
		return
	
	var to_target: Vector2 = _target.global_position - _entity.global_position
	var distance: float = to_target.length()
	
	if distance < 1.0:
		# Nearly perfectly overlapping — push away on a fixed axis
		_mover.intent = Vector2.DOWN * chase_speed_mult
	elif distance <= separation_distance:
		# Too close / overlapping — push apart instead of chasing
		_mover.intent = -to_target.normalized() * chase_speed_mult * 0.5
	elif distance <= stop_distance:
		_mover.intent = Vector2.ZERO
	else:
		_mover.intent = to_target.normalized() * chase_speed_mult
	
	if _entity is CharacterBody2D:
		_mover.apply(_entity as CharacterBody2D, delta)

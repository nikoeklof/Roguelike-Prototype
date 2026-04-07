extends AIBehaviorModule
class_name SpellAIModule

@export var spell_range: float = 250.0
@export var optimal_distance: float = 150.0


func decide(context: Dictionary) -> AIDecision:
	"""Decide spell action based on positioning and cooldown"""
	if _target == null or _combat == null:
		return null
	
	var distance: float = context.get("distance", INF)
	var spell_cooldown: float = context.get("spell_cooldown", 0.0)
	var is_ready: bool = spell_cooldown <= 0.0
	
	# Priority 90: Cast if ready and in range
	if is_ready and distance <= spell_range:
		return AIDecision.new("cast_spell", 90, {
			"ready": true,
			"distance": distance
		})
	
	# Priority 60: Move to optimal spell distance
	if distance <= context.get("aggro_range", 300.0):
		return AIDecision.new("spell_position", 60, {
			"ready": is_ready,
			"distance": distance,
			"cooldown": spell_cooldown
		})
	
	return null


func physics_update(delta: float, decision: AIDecision) -> void:
	"""Handle positioning for spells"""
	if decision == null or decision.state != "spell_position" or _target == null or _mover == null:
		return
	
	var distance: float = _entity.global_position.distance_to(_target.global_position)
	var direction: Vector2 = (_target.global_position - _entity.global_position).normalized()
	
	# Move to optimal casting distance
	if distance < optimal_distance * 0.8:
		_mover.intent = -direction * 0.7
	elif distance > optimal_distance * 1.2:
		_mover.intent = direction * 0.7
	else:
		_mover.intent = Vector2.ZERO
	
	if _entity is CharacterBody2D:
		_mover.apply(_entity as CharacterBody2D, delta)

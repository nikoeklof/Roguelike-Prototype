extends AIBehaviorModule
class_name MeleeAIModule

@export var attack_range: float = 50.0
@export var stop_distance: float = 40.0
@export var chase_speed_mult: float = 1.0
@export var separation_distance: float = 20.0

var _debug_timer: float = 0.0
const DEBUG_INTERVAL: float = 1.0


func decide(context: Dictionary) -> AIDecision:
	"""Decide melee action based on context"""
	if _target == null:
		print("[MeleeAI] decide: _target is NULL — cannot decide")
		return null
	if _combat == null:
		print("[MeleeAI] decide: _combat is NULL — cannot decide")
		return null

	var distance: float = context.get("distance", INF)
	var melee_cooldown: float = context.get("melee_cooldown", 0.0)
	var is_ready: bool = melee_cooldown <= 0.0
	var has_los: bool = context.get("has_los", false)

	# Priority 100: Attack if ready, in range, AND have line of sight
	if distance <= attack_range and is_ready and has_los:
		print("[MeleeAI] decide: MELEE_ATTACK (dist=%.1f, range=%.1f, cd=%.2f, LOS=true)" % [distance, attack_range, melee_cooldown])
		return AIDecision.new("melee_attack", 100, {
			"ready": true,
			"distance": distance
		})

	# Priority 70: Chase if in aggro range (chase regardless of LOS — need to navigate to target)
	if distance <= context.get("aggro_range", 300.0):
		return AIDecision.new("chase", 70, {
			"ready": is_ready,
			"distance": distance,
			"cooldown": melee_cooldown
		})

	return null


func physics_update(delta: float, decision: AIDecision) -> void:
	"""Periodic debug only. Movement is handled by EnemyAI._execute_decision()
	via the control source → state machine → mover pipeline."""
	_debug_timer += delta
	if _debug_timer >= DEBUG_INTERVAL:
		_debug_timer = 0.0
		var dist: float = INF
		if _target != null and _entity != null:
			dist = _entity.global_position.distance_to(_target.global_position)
		var decision_str: String = decision.state if decision != null else "null"
		print("[MeleeAI] tick: target=%s, combat=%s, dist=%.1f, decision=%s" % [
			"OK" if _target != null else "NULL",
			"OK" if _combat != null else "NULL",
			dist,
			decision_str
		])

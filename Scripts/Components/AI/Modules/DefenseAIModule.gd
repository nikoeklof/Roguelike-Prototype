extends AIBehaviorModule
class_name DefenseAIModule

@export var block_health_threshold: float = 0.4  # Block when below 40% HP
@export var critical_health_threshold: float = 0.2  # Prioritize defense when critical


func decide(context: Dictionary) -> AIDecision:
	"""Decide defense based on health and damage pressure"""
	if _health == null:
		return null
	
	var health_percent: float = context.get("health_percent", 1.0)
	
	# Priority 110: CRITICAL - Block when very low on health
	if health_percent < critical_health_threshold:
		return AIDecision.new("shield_block", 110, {
			"critical": true,
			"health_percent": health_percent
		})
	
	# Priority 85: Block when taking damage
	if health_percent < block_health_threshold:
		return AIDecision.new("shield_block", 85, {
			"critical": false,
			"health_percent": health_percent
		})
	
	return null

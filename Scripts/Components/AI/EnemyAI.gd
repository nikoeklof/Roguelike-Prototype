extends Node
class_name EnemyAI

signal behavior_changed(behavior_name: String)
signal target_changed(target: Node2D)

# Global aggro parameters
@export var aggro_range: float = 300.0
@export_range(0.0, 0.2, 0.01) var decision_interval: float = 0.1

var _entity: Entity
var _target: Node2D = null
var _equipment: Equipment = null
var _combat: Combat = null
var _mover: Mover = null
var _stats: Stats = null
var _health: Health = null
var _capabilities: Capabilities = null
var _faction: Faction = null

var _behavior_modules: Array[AIBehaviorModule] = []
var _current_decision: AIDecision = null
var _update_timer: float = 0.0


func _ready() -> void:
	_entity = get_parent() as Entity
	if _entity == null:
		print("[EnemyAI] ERROR: Parent is not Entity")
		return
	
	# Get all required components
	_equipment = _entity.find_component(&"Equipment") as Equipment
	_combat = _entity.find_component(&"Combat") as Combat
	_mover = _entity.find_component(&"Mover") as Mover
	_stats = _entity.find_component(&"Stats") as Stats
	_health = _entity.find_component(&"Health") as Health
	_capabilities = _entity.find_component(&"Capabilities") as Capabilities
	_faction = _entity.find_component(&"Faction") as Faction
	
	if _capabilities == null:
		print("[EnemyAI] ERROR: No Capabilities component")
		return
	
	if _equipment == null:
		print("[EnemyAI] ERROR: No Equipment component")
		return
	
	if _mover == null:
		print("[EnemyAI] ERROR: No Mover component")
		return
	
	# Check if entity can attack
	var can_attack: bool = _capabilities.has_capability(&"can_attack")
	if not can_attack:
		print("[EnemyAI] WARNING: Entity cannot attack (no can_attack capability)")
	
	# Find player via faction system
	_acquire_target()
	
	# Initialize behavior modules based on inventory
	_initialize_behavior_modules()
	
	print("[EnemyAI] Ready with %d behavior modules" % _behavior_modules.size())


func _acquire_target() -> void:
	"""Find player via faction system"""
	if _faction == null:
		print("[EnemyAI] ERROR: No Faction component")
		return
	
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		_target = player
		target_changed.emit(_target)
		print("[EnemyAI] Target acquired: %s" % player.name)
	else:
		print("[EnemyAI] WARNING: No player found")


func _initialize_behavior_modules() -> void:
	"""Create behavior modules based on actual equipped items, not capabilities"""
	_behavior_modules.clear()
	
	if _equipment == null:
		return
	
	# Check inventory slots for actual items
	var melee_slot: Node = _equipment.get_node_or_null("MeleeSlot")
	var ranged_slot: Node = _equipment.get_node_or_null("RangedSlot")
	var spell_slot: Node = _equipment.get_node_or_null("SpellSlot")
	var shield_slot: ShieldSlot = _equipment.get_node_or_null("ShieldSlot") as ShieldSlot
	
	# Check if items are actually equipped
	var has_melee: bool = false
	var has_ranged: bool = false
	var has_spell: bool = false
	var has_shield: bool = false
	
	if melee_slot != null and melee_slot.has_method("get_item"):
		has_melee = melee_slot.call("get_item") != null
	
	if ranged_slot != null and ranged_slot.has_method("get_item"):
		has_ranged = ranged_slot.call("get_item") != null
	
	if spell_slot != null and spell_slot.has_method("get_item"):
		has_spell = spell_slot.call("get_item") != null
	
	if shield_slot != null:
		has_shield = shield_slot.get_item() != null
	
	# Create modules only for equipped items
	if has_melee:
		var melee_module = MeleeAIModule.new()
		melee_module._setup(_entity, _target, _combat, _mover, _stats, _health, _equipment)
		_behavior_modules.append(melee_module)
		print("[EnemyAI] Added MeleeAIModule (melee equipped)")
	
	if has_ranged:
		var ranged_module = RangedAIModule.new()
		ranged_module._setup(_entity, _target, _combat, _mover, _stats, _health, _equipment)
		_behavior_modules.append(ranged_module)
		print("[EnemyAI] Added RangedAIModule (ranged equipped)")
	
	if has_spell:
		var spell_module = SpellAIModule.new()
		spell_module._setup(_entity, _target, _combat, _mover, _stats, _health, _equipment)
		_behavior_modules.append(spell_module)
		print("[EnemyAI] Added SpellAIModule (spell equipped)")
	
	if has_shield:
		var defense_module = DefenseAIModule.new()
		defense_module._setup(_entity, _target, _combat, _mover, _stats, _health, _equipment)
		_behavior_modules.append(defense_module)
		print("[EnemyAI] Added DefenseAIModule (shield equipped)")
	
	if _behavior_modules.is_empty():
		print("[EnemyAI] WARNING: No items equipped, no behavior modules created")


func _physics_process(delta: float) -> void:
	if _entity == null or _target == null or _behavior_modules.is_empty():
		return
	
	_update_timer += delta
	if _update_timer >= decision_interval:
		_update_timer = 0.0
		_make_decision()
	
	# Let modules do continuous updates
	for module in _behavior_modules:
		if module.has_method("physics_update"):
			module.physics_update(delta, _current_decision)


func _make_decision() -> void:
	"""Gather context and ask modules for best action, with conflict resolution"""
	var in_aggro_range: bool = _is_in_aggro_range()
	
	# Not in range? Idle
	if not in_aggro_range:
		_current_decision = AIDecision.new("idle", 0)
		return
	
	# Gather context for modules
	var context := _build_context()
	
	# Ask all modules for decisions
	var candidate_decisions: Array[AIDecision] = []
	
	for module in _behavior_modules:
		if not module.has_method("decide"):
			continue
		
		var decision: AIDecision = module.decide(context)
		if decision == null:
			continue
		
		candidate_decisions.append(decision)
	
	if candidate_decisions.is_empty():
		_current_decision = AIDecision.new("chase", 50)
		return
	
	# Resolve conflicts between decisions
	var best_decision := _resolve_conflicts(candidate_decisions, context)
	
	if best_decision.state != _current_decision.state:
		behavior_changed.emit(best_decision.state)
		print("[EnemyAI] Decision: %s (priority: %d)" % [best_decision.state, best_decision.priority])
	
	_current_decision = best_decision


func _resolve_conflicts(decisions: Array[AIDecision], context: Dictionary) -> AIDecision:
	"""Resolve conflicts between multiple module decisions using smart logic"""
	
	# If only one decision, return it
	if decisions.size() == 1:
		return decisions[0]
	
	var defense_decisions: Array[AIDecision] = []
	var attack_decisions: Array[AIDecision] = []
	var movement_decisions: Array[AIDecision] = []
	var spell_decisions: Array[AIDecision] = []
	
	# Categorize decisions
	for decision in decisions:
		if decision.state in ["shield_block"]:
			defense_decisions.append(decision)
		elif decision.state in ["cast_spell", "spell_position"]:
			spell_decisions.append(decision)
		elif decision.state in ["melee_attack", "ranged_attack"]:
			attack_decisions.append(decision)
		else:
			movement_decisions.append(decision)
	
	# Defense decisions override everything if health is critical
	if not defense_decisions.is_empty():
		var health_percent: float = context.get("health_percent", 1.0)
		if health_percent < 0.3:  # Critical health
			return defense_decisions[0]
	
	# If we have attack decisions, prioritize them
	if not attack_decisions.is_empty():
		# Sort by priority
		attack_decisions.sort_custom(func(a, b): return a.priority > b.priority)
		
		# Check if multiple attacks are viable
		if attack_decisions.size() > 1:
			# Prefer the attack that's ready (off cooldown)
			for decision in attack_decisions:
				if decision.data.get("ready", false):
					return decision
		
		return attack_decisions[0]
	
	# If we have spell decisions
	if not spell_decisions.is_empty():
		spell_decisions.sort_custom(func(a, b): return a.priority > b.priority)
		return spell_decisions[0]
	
	# Fall back to movement
	if not movement_decisions.is_empty():
		movement_decisions.sort_custom(func(a, b): return a.priority > b.priority)
		return movement_decisions[0]
	
	# Default fallback
	return AIDecision.new("idle", 0)


func _build_context() -> Dictionary:
	"""Build decision context from all systems"""
	var distance_to_target: float = INF
	if _target != null:
		distance_to_target = _entity.global_position.distance_to(_target.global_position)
	
	var health_percent: float = 1.0
	if _health != null:
		health_percent = _health.current_hp / _health.max_hp
	
	# Check item cooldowns
	var melee_cooldown: float = 0.0
	var ranged_cooldown: float = 0.0
	var spell_cooldown: float = 0.0
	
	if _stats != null:
		melee_cooldown = _stats.get_melee_cooldown_remaining() if _stats.has_method("get_melee_cooldown_remaining") else 0.0
		ranged_cooldown = _stats.get_ranged_cooldown_remaining() if _stats.has_method("get_ranged_cooldown_remaining") else 0.0
		spell_cooldown = _stats.get_spell_cooldown_remaining() if _stats.has_method("get_spell_cooldown_remaining") else 0.0
	
	return {
		"distance": distance_to_target,
		"health_percent": health_percent,
		"melee_cooldown": melee_cooldown,
		"ranged_cooldown": ranged_cooldown,
		"spell_cooldown": spell_cooldown,
		"target": _target,
		"aggro_range": aggro_range
	}


func _is_in_aggro_range() -> bool:
	"""Check if target is in global aggro range"""
	if _target == null:
		return false
	
	var distance: float = _entity.global_position.distance_to(_target.global_position)
	return distance <= aggro_range


func get_current_decision() -> AIDecision:
	return _current_decision


func get_entity() -> Entity:
	return _entity


func get_target() -> Node2D:
	return _target

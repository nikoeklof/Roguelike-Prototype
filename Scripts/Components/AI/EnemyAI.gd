extends Node
class_name EnemyAI

signal behavior_changed(behavior_name: String)
signal target_changed(target: Node2D)
signal awareness_changed(new_state: int)

enum Awareness { IDLE, ALERT, LOST }

# Global aggro parameters
@export var aggro_range: float = 300.0
@export var deaggro_range: float = 400.0
@export_range(0.0, 0.2, 0.01) var decision_interval: float = 0.1

# Patrol parameters
@export var patrol_speed_mult: float = 0.4
@export var patrol_direction_change_min: float = 1.5
@export var patrol_direction_change_max: float = 4.0
@export var patrol_idle_chance: float = 0.3
@export var patrol_idle_duration_min: float = 0.5
@export var patrol_idle_duration_max: float = 2.0

# How often to scan for a player when no target (seconds)
@export_range(0.1, 2.0, 0.1) var player_scan_interval: float = 0.5

# How long to search after losing the player before returning to patrol
@export var lost_search_duration: float = 3.0

var _entity: Entity
var _target: Node2D = null
var _equipment: Equipment = null
var _combat: Combat = null
var _mover: Mover = null
var _stats: Stats = null
var _health: Health = null
var _capabilities: Capabilities = null
var _faction: Faction = null
var _control: EnemyControl = null

var _behavior_modules: Array[AIBehaviorModule] = []
var _current_decision: AIDecision = null
var _update_timer: float = 0.0

# Awareness state
var _awareness: int = Awareness.IDLE
var _player_scan_timer: float = 0.0
var _lost_timer: float = 0.0

# Patrol state
var _patrol_dir: Vector2 = Vector2.ZERO
var _patrol_timer: float = 0.0
var _patrol_idle: bool = false
var _patrol_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_entity = get_parent() as Entity
	if _entity == null:
		print("[EnemyAI] ERROR: Parent is not Entity")
		return
	
	# Double-defer: LoadoutAssigner uses call_deferred once,
	# so we defer twice to guarantee we run after items are equipped.
	call_deferred("_deferred_init")


func _deferred_init() -> void:
	call_deferred("_full_init")


func _full_init() -> void:
	# Get all required components
	_equipment = _entity.find_component(&"Equipment") as Equipment
	_combat = _entity.find_component(&"Combat") as Combat
	_mover = _entity.find_component(&"Mover") as Mover
	_stats = _entity.find_component(&"Stats") as Stats
	_health = _entity.find_component(&"Health") as Health
	_capabilities = _entity.find_component(&"Capabilities") as Capabilities
	_faction = _entity.find_component(&"Faction") as Faction
	_control = _entity.find_component(&"ControlSource") as EnemyControl
	
	if _capabilities == null:
		print("[EnemyAI] ERROR: No Capabilities component")
		return
	
	if _equipment == null:
		print("[EnemyAI] ERROR: No Equipment component")
		return
	
	if _mover == null:
		print("[EnemyAI] ERROR: No Mover component")
		return
	
	if _control == null:
		print("[EnemyAI] WARNING: No ControlSource component - AI cannot execute actions")
	
	# Check if entity can attack
	var can_attack: bool = _capabilities.is_enabled(Capabilities.CAN_ATTACK)
	if not can_attack:
		print("[EnemyAI] WARNING: Entity cannot attack (no can_attack capability)")
	
	# Initialize behavior modules based on inventory
	_initialize_behavior_modules()
	
	# Initialize default decision
	_current_decision = AIDecision.new("idle", 0)
	
	# Initialize patrol RNG from entity path for determinism
	_patrol_rng.seed = hash(str(_entity.get_path()))
	_pick_new_patrol_direction()
	
	# Try to find player immediately, but don't worry if not found
	_try_acquire_target()
	
	if _target != null:
		_set_awareness(Awareness.ALERT)
	else:
		_set_awareness(Awareness.IDLE)
		print("[EnemyAI] No player found yet — starting patrol")
	
	print("[EnemyAI] Ready with %d behavior modules" % _behavior_modules.size())


func _try_acquire_target() -> void:
	"""Try to find a player. Returns true if found."""
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player != null and _is_valid_target(player):
		if _target != player:
			_target = player
			target_changed.emit(_target)
			
			# Update target reference on all modules
			for module in _behavior_modules:
				if "target" in module:
					module.target = _target
		return
	
	# Player node exists but might be too far — still track it
	if player != null and _target == null:
		_target = player
		target_changed.emit(_target)
		for module in _behavior_modules:
			if "target" in module:
				module.target = _target


func _is_valid_target(target: Node2D) -> bool:
	"""Check if a target is valid (exists, alive, in range)."""
	if target == null or not is_instance_valid(target):
		return false
	# Could add health check here later
	return true


func _set_awareness(new_state: int) -> void:
	if _awareness == new_state:
		return
	var old := _awareness
	_awareness = new_state
	
	var state_names := ["IDLE", "ALERT", "LOST"]
	print("[EnemyAI] Awareness: %s → %s" % [state_names[old], state_names[new_state]])
	awareness_changed.emit(new_state)


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
	
	if has_melee:
		var melee_module = MeleeAIModule.new()
		melee_module._setup(_entity, _target, _combat, _mover, _stats, _health, _equipment)
		add_child(melee_module)
		_behavior_modules.append(melee_module)
		print("[EnemyAI] Added MeleeAIModule (melee equipped)")
	
	if has_ranged:
		var ranged_module = RangedAIModule.new()
		ranged_module._setup(_entity, _target, _combat, _mover, _stats, _health, _equipment)
		add_child(ranged_module)
		_behavior_modules.append(ranged_module)
		print("[EnemyAI] Added RangedAIModule (ranged equipped)")
	
	if has_spell:
		var spell_module = SpellAIModule.new()
		spell_module._setup(_entity, _target, _combat, _mover, _stats, _health, _equipment)
		add_child(spell_module)
		_behavior_modules.append(spell_module)
		print("[EnemyAI] Added SpellAIModule (spell equipped)")
	
	if has_shield:
		var defense_module = DefenseAIModule.new()
		defense_module._setup(_entity, _target, _combat, _mover, _stats, _health, _equipment)
		add_child(defense_module)
		_behavior_modules.append(defense_module)
		print("[EnemyAI] Added DefenseAIModule (shield equipped)")
	
	if _behavior_modules.is_empty():
		print("[EnemyAI] WARNING: No items equipped, no behavior modules created")


func _physics_process(delta: float) -> void:
	if _entity == null:
		return
	
	# Always scan for player periodically
	_player_scan_timer += delta
	if _player_scan_timer >= player_scan_interval:
		_player_scan_timer = 0.0
		_try_acquire_target()
	
	# Update awareness state based on target distance
	_update_awareness(delta)
	
	# Route to appropriate behavior based on awareness
	match _awareness:
		Awareness.IDLE:
			_process_patrol(delta)
		Awareness.ALERT:
			_process_combat(delta)
		Awareness.LOST:
			_process_lost(delta)


func _update_awareness(delta: float) -> void:
	"""Transition between awareness states based on target proximity."""
	var has_target: bool = _target != null and is_instance_valid(_target)
	
	if not has_target:
		# No player in the scene at all
		if _awareness != Awareness.IDLE:
			_set_awareness(Awareness.IDLE)
		return
	
	var distance: float = _entity.global_position.distance_to(_target.global_position)
	
	match _awareness:
		Awareness.IDLE:
			# Spot the player within aggro range
			if distance <= aggro_range:
				_set_awareness(Awareness.ALERT)
		
		Awareness.ALERT:
			# Player moved out of deaggro range
			if distance > deaggro_range:
				_lost_timer = 0.0
				_set_awareness(Awareness.LOST)
		
		Awareness.LOST:
			# Player came back into aggro range
			if distance <= aggro_range:
				_set_awareness(Awareness.ALERT)
			else:
				# Search timer expires → go back to patrol
				_lost_timer += delta
				if _lost_timer >= lost_search_duration:
					_set_awareness(Awareness.IDLE)


# =========================================
# PATROL (Awareness.IDLE)
# =========================================

func _process_patrol(delta: float) -> void:
	"""Wander randomly when no target is detected."""
	_patrol_timer -= delta
	
	if _patrol_timer <= 0.0:
		_pick_new_patrol_direction()
	
	# Apply patrol movement
	if _control != null:
		_control.set_block_intent(false)
		if _patrol_idle:
			_control.set_move_intent(Vector2.ZERO)
		else:
			_control.set_move_intent(_patrol_dir * patrol_speed_mult)
	
	# Update decision for debug purposes
	if _patrol_idle:
		_current_decision = AIDecision.new("patrol_idle", 0)
	else:
		_current_decision = AIDecision.new("patrol", 10)


func _pick_new_patrol_direction() -> void:
	"""Choose a new random patrol direction or idle pause."""
	# Chance to stop and idle
	if _patrol_rng.randf() < patrol_idle_chance:
		_patrol_idle = true
		_patrol_timer = _patrol_rng.randf_range(patrol_idle_duration_min, patrol_idle_duration_max)
	else:
		_patrol_idle = false
		# Pick a random direction
		var angle: float = _patrol_rng.randf_range(0.0, TAU)
		_patrol_dir = Vector2(cos(angle), sin(angle))
		_patrol_timer = _patrol_rng.randf_range(patrol_direction_change_min, patrol_direction_change_max)


# =========================================
# COMBAT (Awareness.ALERT)
# =========================================

func _process_combat(delta: float) -> void:
	"""Full combat AI — modules decide what to do."""
	if _behavior_modules.is_empty():
		return
	
	_update_timer += delta
	if _update_timer >= decision_interval:
		_update_timer = 0.0
		_make_decision()
	
	_execute_decision()
	
	# Let modules do continuous updates
	for module in _behavior_modules:
		if module.has_method("physics_update"):
			module.physics_update(delta, _current_decision)


# =========================================
# LOST (Awareness.LOST)
# =========================================

func _process_lost(delta: float) -> void:
	"""Move toward last known player position, then give up."""
	# Move toward where the player was
	if _target != null and is_instance_valid(_target) and _control != null:
		var dir: Vector2 = (_target.global_position - _entity.global_position).normalized()
		_control.set_move_intent(dir * 0.6)
		_control.set_block_intent(false)
	
	_current_decision = AIDecision.new("searching", 30)


# =========================================
# COMBAT DECISION MAKING
# =========================================

func _make_decision() -> void:
	"""Gather context and ask modules for best action, with conflict resolution"""
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
	
	if _current_decision == null or best_decision.state != _current_decision.state:
		behavior_changed.emit(best_decision.state)
		print("[EnemyAI] Decision: %s (priority: %d)" % [best_decision.state, best_decision.priority])
	
	_current_decision = best_decision


func _execute_decision() -> void:
	"""Bridge between AI decisions and the EnemyControl/Combat systems"""
	if _current_decision == null or _control == null:
		return
	
	var dir_to_target := Vector2.ZERO
	if _target != null:
		dir_to_target = (_target.global_position - _entity.global_position).normalized()
	
	# Default: not blocking
	_control.set_block_intent(false)
	
	match _current_decision.state:
		"melee_attack":
			if _combat != null:
				_equipment.set_active_slot_melee("ai_melee")
				# Let the state machine + Combat handle the actual attack.
				# We set move intent toward target so Walk→Idle→Attack cycle works,
				# and press_attack so the ControlSource signals the Attack state.
				_control.set_move_intent(dir_to_target)
				if not _control.attack_is_down():
					_control.press_attack(dir_to_target, Combat.AttackKind.MELEE)
		"ranged_attack":
			if _combat != null:
				_equipment.set_active_slot_ranged("ai_ranged")
				_control.set_move_intent(Vector2.ZERO)
				if not _control.attack_is_down():
					_control.press_attack(dir_to_target, Combat.AttackKind.RANGED)
		"cast_spell":
			if _combat != null:
				_equipment.set_active_slot_spell("ai_spell")
				_control.set_move_intent(Vector2.ZERO)
				if not _control.attack_is_down():
					_control.press_attack(dir_to_target, Combat.AttackKind.SPELL)
		"shield_block":
			_control.set_block_intent(true)
			if _control.attack_is_down():
				_control.release_attack()
		"chase":
			var dist: float = _entity.global_position.distance_to(_target.global_position) if _target != null else INF
			if dist < 1.0:
				# Overlapping — escape downward
				_control.set_move_intent(Vector2.DOWN)
			elif dist < 20.0:
				# Too close — push apart
				_control.set_move_intent(-dir_to_target * 0.5)
			else:
				_control.set_move_intent(dir_to_target)
			if _control.attack_is_down():
				_control.release_attack()
		"kite":
			# Handled by RangedAIModule.physics_update()
			if _control.attack_is_down():
				_control.release_attack()
		"idle", "patrol", "patrol_idle":
			_control.set_move_intent(Vector2.ZERO)
			if _control.attack_is_down():
				_control.release_attack()
		_:
			# Unknown state — release everything
			if _control.attack_is_down():
				_control.release_attack()


func _resolve_conflicts(decisions: Array[AIDecision], context: Dictionary) -> AIDecision:
	"""Resolve conflicts between multiple module decisions using smart logic"""
	if decisions.size() == 1:
		return decisions[0]
	
	var defense_decisions: Array[AIDecision] = []
	var attack_decisions: Array[AIDecision] = []
	var movement_decisions: Array[AIDecision] = []
	var spell_decisions: Array[AIDecision] = []
	
	for decision in decisions:
		if decision.state in ["shield_block"]:
			defense_decisions.append(decision)
		elif decision.state in ["cast_spell", "spell_position"]:
			spell_decisions.append(decision)
		elif decision.state in ["melee_attack", "ranged_attack"]:
			attack_decisions.append(decision)
		else:
			movement_decisions.append(decision)
	
	# Defense overrides everything if health is critical
	if not defense_decisions.is_empty():
		var health_percent: float = context.get("health_percent", 1.0)
		if health_percent < 0.3:
			return defense_decisions[0]
	
	if not attack_decisions.is_empty():
		attack_decisions.sort_custom(func(a, b): return a.priority > b.priority)
		if attack_decisions.size() > 1:
			for decision in attack_decisions:
				if decision.data.get("ready", false):
					return decision
		return attack_decisions[0]
	
	if not spell_decisions.is_empty():
		spell_decisions.sort_custom(func(a, b): return a.priority > b.priority)
		return spell_decisions[0]
	
	if not movement_decisions.is_empty():
		movement_decisions.sort_custom(func(a, b): return a.priority > b.priority)
		return movement_decisions[0]
	
	return AIDecision.new("idle", 0)


func _build_context() -> Dictionary:
	"""Build decision context from all systems"""
	var distance_to_target: float = INF
	if _target != null:
		distance_to_target = _entity.global_position.distance_to(_target.global_position)
	
	var health_percent: float = 1.0
	if _health != null:
		health_percent = _health.hp / _health.max_hp
	
	var melee_cooldown: float = 0.0
	var ranged_cooldown: float = 0.0
	var spell_cooldown: float = 0.0
	
	if _combat != null and _equipment != null:
		var melee_item: Node = _equipment.get_item_for_kind(Combat.AttackKind.MELEE)
		var ranged_item: Node = _equipment.get_item_for_kind(Combat.AttackKind.RANGED)
		melee_cooldown = _combat.get_cooldown_remaining(melee_item)
		ranged_cooldown = _combat.get_cooldown_remaining(ranged_item)
	
	if _stats != null:
		spell_cooldown = _stats.get_spell_cooldown_remaining()
	
	return {
		"distance": distance_to_target,
		"health_percent": health_percent,
		"melee_cooldown": melee_cooldown,
		"ranged_cooldown": ranged_cooldown,
		"spell_cooldown": spell_cooldown,
		"target": _target,
		"aggro_range": aggro_range,
		"awareness": _awareness
	}


func get_current_decision() -> AIDecision:
	return _current_decision


func get_entity() -> Entity:
	return _entity


func get_target() -> Node2D:
	return _target


func get_awareness() -> int:
	return _awareness

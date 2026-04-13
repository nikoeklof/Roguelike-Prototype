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

# Damage aggro boost — after being hit, ranges are multiplied for this duration
@export var damage_aggro_duration: float = 8.0
@export var damage_aggro_range_mult: float = 2.0

# LOS check interval (don't raycast every frame)
@export_range(0.05, 0.5, 0.05) var los_check_interval: float = 0.1

# Navigation repath interval
@export_range(0.1, 1.0, 0.05) var nav_repath_interval: float = 0.25

# If true, enemies only aggro when the player is in LOS.
@export var require_los_to_aggro: bool = true
# Once LOS is acquired, keep "seen" for this many seconds (prevents flicker drop / windup cancel spam).
@export_range(0.0, 2.0, 0.05) var los_memory_sec: float = 0.35

# --- Attack pacing / anti-stunlock ---
@export var ranged_burst_count: int = 2
@export var ranged_reposition_sec: float = 0.6
@export var spell_burst_count: int = 2
@export var spell_reposition_sec: float = 0.6

# Attack wind-up (reaction time). Adds a delay between "in range" and actual press_attack.
@export_range(0.0, 1.0, 0.01) var melee_windup_sec: float = 0.05
@export_range(0.0, 1.0, 0.01) var ranged_windup_sec: float = 0.18
@export_range(0.0, 1.0, 0.01) var spell_windup_sec: float = 0.15
@export_range(0.0, 0.5, 0.01) var windup_jitter_sec: float = 0.10

# Optional: melee pacing (usually not needed)
@export var melee_burst_count: int = 999
@export var melee_reposition_sec: float = 0.0

# Reposition movement tuning
@export_range(0.2, 1.5, 0.05) var reposition_speed_mult: float = 0.8
@export_range(0.0, 1.0, 0.05) var reposition_backstep_mult: float = 0.15

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

# Damage aggro boost state
var _damage_aggro_timer: float = 0.0

# LOS state (cached, updated periodically)
var _has_los: bool = false
var _los_timer: float = 0.0
var _los_seen_timer: float = 0.0
var _los_has_fresh_sample: bool = false # becomes true after we raycast at least once

# Target health / invulnerability (cached)
var _target_health: Health = null
var _target_invulnerable: bool = false

# Navigation
var _nav_agent: NavigationAgent2D = null
var _nav_repath_timer: float = 0.0

# Attack pacing state
var _pending_attack_kind: int = Combat.AttackKind.NONE
var _pending_attack_timer: float = 0.0
var _reposition_timer: float = 0.0
var _recent_attacks: Dictionary = {
	Combat.AttackKind.MELEE: 0,
	Combat.AttackKind.RANGED: 0,
	Combat.AttackKind.SPELL: 0,
}

# Patrol state
var _patrol_dir: Vector2 = Vector2.ZERO
var _patrol_timer: float = 0.0
var _patrol_idle: bool = false
var _patrol_rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Debug
@warning_ignore("unused_private_class_variable")
var _debug_timer: float = 0.0
const DEBUG_INTERVAL: float = 2.0


func _ready() -> void:
	_entity = get_parent() as Entity
	if _entity == null:
		print("[EnemyAI] ERROR: Parent is not Entity")
		return

	# Find or create NavigationAgent2D on the entity
	_nav_agent = _entity.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	if _nav_agent == null:
		_nav_agent = NavigationAgent2D.new()
		_nav_agent.name = "NavigationAgent2D"
		_entity.add_child.call_deferred(_nav_agent)
		print("[EnemyAI] Created NavigationAgent2D")

	# Configure nav agent (also configured in _full_init, but safe defaults here)
	_nav_agent.path_desired_distance = 8.0
	_nav_agent.target_desired_distance = 16.0
	_nav_agent.path_max_distance = 600.0
	_nav_agent.avoidance_enabled = false  # We handle movement ourselves
	_nav_agent.debug_enabled = false

	# Double-defer: LoadoutAssigner uses call_deferred once,
	# so we defer twice to guarantee we run after items are equipped.
	call_deferred("_deferred_init")


func _deferred_init() -> void:
	call_deferred("_full_init")


func _full_init() -> void:
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
	if _combat == null:
		print("[EnemyAI] WARNING: No Combat component - AI cannot attack")

	if _combat != null and not _combat.attack_finished.is_connected(_on_attack_finished):
		_combat.attack_finished.connect(_on_attack_finished)

	var can_attack: bool = _capabilities.is_enabled(Capabilities.CAN_ATTACK)
	if not can_attack:
		print("[EnemyAI] WARNING: Entity cannot attack (no can_attack capability)")

	if _health != null and not _health.damaged.is_connected(_on_damaged):
		_health.damaged.connect(_on_damaged)

	_configure_nav_agent()
	_try_acquire_target()
	_initialize_behavior_modules()

	_current_decision = AIDecision.new("idle", 0)

	_patrol_rng.seed = hash(str(_entity.get_path()))
	_pick_new_patrol_direction()

	if _target != null:
		# Force an immediate LOS sample next frame so we don't stay "blind" early.
		_los_timer = los_check_interval
		_set_awareness(Awareness.IDLE)
	else:
		_set_awareness(Awareness.IDLE)


# =========================================
# TARGET HELPERS
# =========================================

func _bind_target_health() -> void:
	_target_health = null
	_target_invulnerable = false
	if _target == null or not is_instance_valid(_target):
		return
	_target_health = _target.get_node_or_null("Health") as Health


# =========================================
# LINE OF SIGHT
# =========================================

func _update_los() -> void:
	if _entity == null or _target == null or not is_instance_valid(_target):
		_has_los = false
		_los_has_fresh_sample = true
		return

	_has_los = AILineOfSight.has_los_to_target(_entity, _target)
	_los_has_fresh_sample = true

	if _has_los:
		_los_seen_timer = los_memory_sec


func _has_recent_los() -> bool:
	# If we haven't sampled yet, assume false.
	if not _los_has_fresh_sample:
		return false
	return _has_los or _los_seen_timer > 0.0


func has_los() -> bool:
	return _has_los


# =========================================
# NAVIGATION
# =========================================

func _update_nav_target() -> void:
	if _nav_agent == null or _target == null:
		return
	_nav_agent.target_position = _target.global_position


func _configure_nav_agent() -> void:
	if _nav_agent == null:
		_nav_agent = _entity.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	if _nav_agent == null:
		return
	if not _nav_agent.is_inside_tree():
		call_deferred("_configure_nav_agent")
		return

	_nav_agent.path_desired_distance = 8.0
	_nav_agent.target_desired_distance = 16.0
	_nav_agent.path_max_distance = 600.0
	_nav_agent.avoidance_enabled = false
	_nav_agent.debug_enabled = false


func _get_nav_direction_to_target() -> Vector2:
	if _target == null or _entity == null:
		return Vector2.ZERO

	var direct: Vector2 = (_target.global_position - _entity.global_position).normalized()

	if _nav_agent == null or not _nav_agent.is_inside_tree():
		return direct

	if _nav_agent.is_navigation_finished():
		return Vector2.ZERO

	var next_point: Vector2 = _nav_agent.get_next_path_position()
	var direction: Vector2 = (next_point - _entity.global_position).normalized()
	if direction.length() < 0.001:
		return direct
	return direction


# =========================================
# DAMAGE AGGRO
# =========================================

func _on_damaged(_amount: float, source: Node) -> void:
	_damage_aggro_timer = damage_aggro_duration

	var aggro_target: Node2D = null
	if source is Node2D and source.is_in_group("player"):
		aggro_target = source as Node2D
	if aggro_target == null:
		aggro_target = get_tree().get_first_node_in_group("player") as Node2D
	if aggro_target == null:
		return

	if _target != aggro_target:
		_target = aggro_target
		_bind_target_health()
		target_changed.emit(_target)
		for module: AIBehaviorModule in _behavior_modules:
			module.set_target(_target)

	# Taking damage should always alert (even without LOS), but still won't attack without LOS.
	_set_awareness(Awareness.ALERT)
	_los_timer = los_check_interval # force LOS sample soon


func _is_damage_aggro_active() -> bool:
	return _damage_aggro_timer > 0.0


func _effective_aggro_range() -> float:
	if _is_damage_aggro_active():
		return aggro_range * damage_aggro_range_mult
	return aggro_range


func _effective_deaggro_range() -> float:
	if _is_damage_aggro_active():
		return deaggro_range * damage_aggro_range_mult
	return deaggro_range


func _try_acquire_target() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if _target == player:
		return

	_target = player
	_bind_target_health()
	target_changed.emit(_target)
	for module: AIBehaviorModule in _behavior_modules:
		module.set_target(_target)

	# Force early LOS sample next frame
	_los_timer = los_check_interval


func _set_awareness(new_state: int) -> void:
	if _awareness == new_state:
		return
	_awareness = new_state
	awareness_changed.emit(new_state)


func _initialize_behavior_modules() -> void:
	_behavior_modules.clear()
	if _equipment == null:
		return

	var melee_slot: Node = _equipment.get_node_or_null("MeleeSlot")
	var ranged_slot: Node = _equipment.get_node_or_null("RangedSlot")
	var spell_slot: Node = _equipment.get_node_or_null("SpellSlot")
	var shield_slot: ShieldSlot = _equipment.get_node_or_null("ShieldSlot") as ShieldSlot

	var has_melee := melee_slot != null and melee_slot.has_method("get_item") and melee_slot.call("get_item") != null
	var has_ranged := ranged_slot != null and ranged_slot.has_method("get_item") and ranged_slot.call("get_item") != null
	var has_spell := spell_slot != null and spell_slot.has_method("get_item") and spell_slot.call("get_item") != null
	var has_shield := shield_slot != null and shield_slot.get_item() != null

	if has_melee:
		var melee_module = MeleeAIModule.new()
		melee_module._setup(_entity, _target, _combat, _mover, _stats, _health, _equipment)
		add_child(melee_module)
		_behavior_modules.append(melee_module)

	if has_ranged:
		var ranged_module = RangedAIModule.new()
		ranged_module._setup(_entity, _target, _combat, _mover, _stats, _health, _equipment)
		add_child(ranged_module)
		_behavior_modules.append(ranged_module)

	if has_spell:
		var spell_module = SpellAIModule.new()
		spell_module._setup(_entity, _target, _combat, _mover, _stats, _health, _equipment)
		add_child(spell_module)
		_behavior_modules.append(spell_module)

	if has_shield:
		var defense_module = DefenseAIModule.new()
		defense_module._setup(_entity, _target, _combat, _mover, _stats, _health, _equipment)
		add_child(defense_module)
		_behavior_modules.append(defense_module)


# =========================================
# ATTACK PACING
# =========================================

func _on_attack_finished(kind: int) -> void:
	if not _recent_attacks.has(kind):
		_recent_attacks[kind] = 0
	_recent_attacks[kind] = int(_recent_attacks[kind]) + 1

	if kind == Combat.AttackKind.RANGED and int(_recent_attacks[kind]) >= ranged_burst_count:
		_recent_attacks[kind] = 0
		_reposition_timer = maxf(_reposition_timer, ranged_reposition_sec)

	elif kind == Combat.AttackKind.SPELL and int(_recent_attacks[kind]) >= spell_burst_count:
		_recent_attacks[kind] = 0
		_reposition_timer = maxf(_reposition_timer, spell_reposition_sec)

	elif kind == Combat.AttackKind.MELEE and int(_recent_attacks[kind]) >= melee_burst_count:
		_recent_attacks[kind] = 0
		_reposition_timer = maxf(_reposition_timer, melee_reposition_sec)


func _reposition_move_dir(dir_to_target: Vector2) -> Vector2:
	var strafe := Vector2(-dir_to_target.y, dir_to_target.x)
	if int(hash(str(_entity.get_instance_id()))) % 2 == 0:
		strafe = -strafe

	var backstep := -dir_to_target * reposition_backstep_mult
	var move := (strafe + backstep)
	if move.length() < 0.001:
		move = strafe
	return move.normalized()


# =========================================
# ATTACK WINDUP HELPERS
# =========================================

func _windup_for_kind(kind: int) -> float:
	match kind:
		Combat.AttackKind.RANGED:
			return ranged_windup_sec
		Combat.AttackKind.SPELL:
			return spell_windup_sec
		Combat.AttackKind.MELEE:
			return melee_windup_sec
		_:
			return 0.0


func _start_attack_windup(kind: int) -> void:
	if kind == Combat.AttackKind.NONE:
		return

	# If already winding up the same kind, keep it.
	if _pending_attack_kind == kind and _pending_attack_timer > 0.0:
		return

	_pending_attack_kind = kind

	var salt := hash("%s|%d" % [str(_entity.get_instance_id()), kind])
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	var jitter := rng.randf_range(0.0, windup_jitter_sec)

	_pending_attack_timer = _windup_for_kind(kind) + jitter


func _cancel_attack_windup() -> void:
	_pending_attack_kind = Combat.AttackKind.NONE
	_pending_attack_timer = 0.0


func _tick_attack_windup(delta: float) -> void:
	if _pending_attack_timer <= 0.0:
		return
	_pending_attack_timer = maxf(_pending_attack_timer - delta, 0.0)


# =========================================
# MAIN LOOP
# =========================================

func _physics_process(delta: float) -> void:
	if _entity == null:
		return

	_tick_attack_windup(delta)

	# Tick damage aggro boost
	if _damage_aggro_timer > 0.0:
		_damage_aggro_timer = maxf(_damage_aggro_timer - delta, 0.0)

	# Tick reposition
	if _reposition_timer > 0.0:
		_reposition_timer = maxf(_reposition_timer - delta, 0.0)

	# Tick LOS memory
	if _los_seen_timer > 0.0:
		_los_seen_timer = maxf(_los_seen_timer - delta, 0.0)

	# Update target invuln (cheap)
	if _target_health != null and is_instance_valid(_target_health):
		_target_invulnerable = _target_health.is_invulnerable()
	else:
		_target_invulnerable = false

	# If player becomes invulnerable, cancel pending windups immediately
	if _target_invulnerable:
		_cancel_attack_windup()

	# Periodically update LOS
	_los_timer += delta
	if _los_timer >= los_check_interval:
		_los_timer = 0.0
		_update_los()

	# Periodically repath navigation
	_nav_repath_timer += delta
	if _nav_repath_timer >= nav_repath_interval:
		_nav_repath_timer = 0.0
		_update_nav_target()

	# Always scan for player periodically
	_player_scan_timer += delta
	if _player_scan_timer >= player_scan_interval:
		_player_scan_timer = 0.0
		_try_acquire_target()

	# Update awareness state based on target distance + LOS
	_update_awareness(delta)

	match _awareness:
		Awareness.IDLE:
			_process_patrol(delta)
		Awareness.ALERT:
			_process_combat(delta)
		Awareness.LOST:
			_process_lost(delta)


func _update_awareness(delta: float) -> void:
	var has_target: bool = _target != null and is_instance_valid(_target)
	if not has_target:
		if _awareness != Awareness.IDLE:
			_set_awareness(Awareness.IDLE)
		return

	var distance: float = _entity.global_position.distance_to(_target.global_position)
	var eff_aggro: float = _effective_aggro_range()
	var eff_deaggro: float = _effective_deaggro_range()
	var has_recent_los := _has_recent_los()

	match _awareness:
		Awareness.IDLE:
			if distance <= eff_aggro and (not require_los_to_aggro or has_recent_los):
				_set_awareness(Awareness.ALERT)

		Awareness.ALERT:
			# If we require LOS to stay aggro, we can transition to LOST when far OR long time no LOS.
			if distance > eff_deaggro:
				_lost_timer = 0.0
				_set_awareness(Awareness.LOST)
			elif require_los_to_aggro and not has_recent_los:
				_lost_timer = 0.0
				_set_awareness(Awareness.LOST)

		Awareness.LOST:
			if distance <= eff_aggro and (not require_los_to_aggro or has_recent_los):
				_set_awareness(Awareness.ALERT)
			else:
				_lost_timer += delta
				if _lost_timer >= lost_search_duration:
					_set_awareness(Awareness.IDLE)


# =========================================
# PATROL / COMBAT / LOST
# =========================================

func _process_patrol(delta: float) -> void:
	_patrol_timer -= delta
	if _patrol_timer <= 0.0:
		_pick_new_patrol_direction()

	if _control != null:
		_control.set_block_intent(false)
		_control.set_move_intent(Vector2.ZERO if _patrol_idle else _patrol_dir * patrol_speed_mult)

	_current_decision = AIDecision.new("patrol_idle", 0) if _patrol_idle else AIDecision.new("patrol", 10)


func _pick_new_patrol_direction() -> void:
	if _patrol_rng.randf() < patrol_idle_chance:
		_patrol_idle = true
		_patrol_timer = _patrol_rng.randf_range(patrol_idle_duration_min, patrol_idle_duration_max)
	else:
		_patrol_idle = false
		var angle: float = _patrol_rng.randf_range(0.0, TAU)
		_patrol_dir = Vector2(cos(angle), sin(angle))
		_patrol_timer = _patrol_rng.randf_range(patrol_direction_change_min, patrol_direction_change_max)


func _process_combat(delta: float) -> void:
	if _behavior_modules.is_empty():
		return

	_update_timer += delta
	if _update_timer >= decision_interval:
		_update_timer = 0.0
		_make_decision()

	_execute_decision()

	for module in _behavior_modules:
		if module.has_method("physics_update"):
			module.physics_update(delta, _current_decision)


func _process_lost(_delta: float) -> void:
	_cancel_attack_windup()

	if _target != null and is_instance_valid(_target) and _control != null:
		var move_dir: Vector2 = _get_nav_direction_to_target()
		_control.set_move_intent(move_dir * 0.6)
		_control.set_block_intent(false)

	_current_decision = AIDecision.new("searching", 30)


# =========================================
# DECISION MAKING
# =========================================

func _make_decision() -> void:
	var context := _build_context()
	var candidate_decisions: Array[AIDecision] = []

	for module in _behavior_modules:
		if not module.has_method("decide"):
			continue

		var decision: AIDecision = module.decide(context)
		if decision != null:
			candidate_decisions.append(decision)

	if candidate_decisions.is_empty():
		_current_decision = AIDecision.new("chase", 50)
		return

	var best_decision := _resolve_conflicts(candidate_decisions, context)
	if _current_decision == null or best_decision.state != _current_decision.state:
		behavior_changed.emit(best_decision.state)
	_current_decision = best_decision


func _execute_decision() -> void:
	if _current_decision == null or _control == null:
		return

	var dir_to_target := Vector2.ZERO
	if _target != null and is_instance_valid(_target):
		dir_to_target = (_target.global_position - _entity.global_position).normalized()

	# Global attack suppression:
	# - during reposition window (anti-stunlock)
	# - while target is invulnerable (respect player invuln)
	var suppress_attacks: bool = (_reposition_timer > 0.0) or _target_invulnerable

	_control.set_block_intent(false)

	if suppress_attacks and _control.attack_is_down():
		_control.release_attack()

	# Force reposition decision when the timer is active
	var state := _current_decision.state
	if _reposition_timer > 0.0:
		state = "reposition"

	match state:
		"reposition":
			_cancel_attack_windup()
			if dir_to_target != Vector2.ZERO:
				var move_dir := _reposition_move_dir(dir_to_target)
				_control.set_move_intent(move_dir * reposition_speed_mult)
			else:
				_control.set_move_intent(Vector2.ZERO)

		"melee_attack":
			# Must have recent LOS to execute attacks (modules already check has_los, but this is extra safety)
			if suppress_attacks or not _has_recent_los():
				_cancel_attack_windup()
				_control.set_move_intent(_get_nav_direction_to_target())
				return

			_start_attack_windup(Combat.AttackKind.MELEE)
			if _pending_attack_kind == Combat.AttackKind.MELEE and _pending_attack_timer <= 0.0:
				_cancel_attack_windup()
				if _combat != null:
					_equipment.set_active_slot_melee("ai_melee")
					_control.set_move_intent(dir_to_target)
					if not _control.attack_is_down():
						_control.press_attack(dir_to_target, Combat.AttackKind.MELEE)
			else:
				# Keep chasing while winding up
				_control.set_move_intent(_get_nav_direction_to_target())

		"ranged_attack":
			if suppress_attacks or not _has_recent_los():
				_cancel_attack_windup()
				_control.set_move_intent(Vector2.ZERO)
				return

			_start_attack_windup(Combat.AttackKind.RANGED)
			if _pending_attack_kind == Combat.AttackKind.RANGED and _pending_attack_timer <= 0.0:
				_cancel_attack_windup()
				if _combat != null:
					_equipment.set_active_slot_ranged("ai_ranged")
					_control.set_move_intent(Vector2.ZERO)
					if not _control.attack_is_down():
						_control.press_attack(dir_to_target, Combat.AttackKind.RANGED)
			else:
				_control.set_move_intent(Vector2.ZERO)

		"cast_spell":
			if suppress_attacks or not _has_recent_los():
				_cancel_attack_windup()
				_control.set_move_intent(Vector2.ZERO)
				return

			_start_attack_windup(Combat.AttackKind.SPELL)
			if _pending_attack_kind == Combat.AttackKind.SPELL and _pending_attack_timer <= 0.0:
				_cancel_attack_windup()
				if _combat != null:
					_equipment.set_active_slot_spell("ai_spell")
					_control.set_move_intent(Vector2.ZERO)
					if not _control.attack_is_down():
						_control.press_attack(dir_to_target, Combat.AttackKind.SPELL)
			else:
				_control.set_move_intent(Vector2.ZERO)

		"shield_block":
			_cancel_attack_windup()
			_control.set_block_intent(true)

		"chase":
			_cancel_attack_windup()
			var move_dir: Vector2 = _get_nav_direction_to_target()
			_control.set_move_intent(move_dir)

		"kite", "spell_position":
			# These are handled by module physics_update; don't cancel windup here, just don't force attack.
			if suppress_attacks:
				_cancel_attack_windup()
				_control.set_move_intent(Vector2.ZERO)

		"idle", "patrol", "patrol_idle":
			_cancel_attack_windup()
			_control.set_move_intent(Vector2.ZERO)

		_:
			_cancel_attack_windup()
			_control.set_move_intent(Vector2.ZERO)


func _resolve_conflicts(decisions: Array[AIDecision], context: Dictionary) -> AIDecision:
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

	if not defense_decisions.is_empty():
		var health_percent: float = context.get("health_percent", 1.0)
		if health_percent < 0.3:
			return defense_decisions[0]

	if not attack_decisions.is_empty():
		attack_decisions.sort_custom(func(a, b): return a.priority > b.priority)
		if attack_decisions.size() > 1:
			for d in attack_decisions:
				if d.data.get("ready", false):
					return d
		return attack_decisions[0]

	if not spell_decisions.is_empty():
		spell_decisions.sort_custom(func(a, b): return a.priority > b.priority)
		return spell_decisions[0]

	if not movement_decisions.is_empty():
		movement_decisions.sort_custom(func(a, b): return a.priority > b.priority)
		return movement_decisions[0]

	return AIDecision.new("idle", 0)


func _build_context() -> Dictionary:
	var distance_to_target: float = INF
	if _target != null and is_instance_valid(_target):
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
		"aggro_range": _effective_aggro_range(),
		"awareness": _awareness,
		"has_los": _has_los,
		"target_invulnerable": _target_invulnerable,
		"repositioning": _reposition_timer > 0.0,
	}


# Getter functions (for DebugHUD)
func get_current_decision() -> AIDecision:
	return _current_decision

func get_entity() -> Entity:
	return _entity

func get_target() -> Node2D:
	return _target

func get_awareness() -> int:
	return _awareness

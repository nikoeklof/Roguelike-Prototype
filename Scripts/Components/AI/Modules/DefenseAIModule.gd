extends AIBehaviorModule
class_name DefenseAIModule

## Minimum distance to target before the module will suggest blocking.
## Keeps melee enemies attacking rather than hiding behind a shield at close range.
@export var block_min_range: float = 80.0

## Maximum distance at which the module will bother blocking.
## Enemies far away don't need to react to incoming fire.
@export var block_max_range: float = 380.0

## Half-angle of the cone (degrees) within which the player's aim must point
## toward this entity for it to count as "being aimed at".
@export_range(10.0, 90.0, 5.0) var player_aim_cone_deg: float = 50.0

## How long the AI will hold the block before it is forced to drop it.
## Prevents the enemy from permanently turtling.
@export_range(0.5, 6.0, 0.1) var block_duration_max: float = 2.5

## Cooldown (seconds) before the AI can block again after dropping the shield.
@export_range(0.5, 8.0, 0.25) var block_cooldown_sec: float = 2.5

## HP fraction below which the AI will block even when the player isn't actively
## aiming at it (last-resort defensive behavior).
@export_range(0.0, 1.0, 0.05) var low_hp_threshold: float = 0.30

## Half-angle of the vision cone (degrees) used for projectile threat detection.
## Projectiles must be within this cone (relative to facing direction) to trigger a block.
@export_range(10.0, 180.0, 5.0) var projectile_vision_cone_deg: float = 100.0

## Maximum range at which incoming projectiles will be noticed.
@export var projectile_vision_range: float = 350.0

var _block_timer: float = 0.0    ## Seconds spent in the current block window.
var _block_cooldown: float = 0.0 ## Seconds remaining on the post-block cooldown.

## Projectiles currently tracked as threats. Cleared each decide() call and rebuilt.
var _tracked_threats: Array = []


func decide(context: Dictionary) -> AIDecision:
	var distance: float = context.get("distance", INF)
	var health_pct: float = context.get("health_percent", 1.0)

	# --- Hard gates ---

	# Shield is on cooldown from the previous block window.
	if _block_cooldown > 0.0:
		_tracked_threats.clear()
		return null

	# Shield is broken — can't block.
	if _is_shield_broken():
		_tracked_threats.clear()
		return null

	# --- Projectile threat scan (highest priority, no range gate) ---
	_tracked_threats = _get_threatening_projectiles()
	if not _tracked_threats.is_empty():
		return AIDecision.new("shield_block", 95, {"reason": "incoming_projectile"})

	# --- Range gates for aim/HP-based blocking ---

	# In melee range: let the attack module take priority — don't block.
	if distance < block_min_range:
		_maybe_end_block()
		return null

	# Too far away to care about blocking.
	if distance > block_max_range:
		_maybe_end_block()
		return null

	# --- Threat assessment ---
	var aimed_at: bool = _is_player_aiming_at_us()
	var player_attacking: bool = _is_player_attacking()

	# Priority 90 — player is actively shooting at us: proactive block.
	if aimed_at and player_attacking:
		return AIDecision.new("shield_block", 90, {"reason": "incoming_fire"})

	# Priority 75 — player is aiming our way and we're wounded.
	if aimed_at and health_pct < 0.55:
		return AIDecision.new("shield_block", 75, {"reason": "wounded_under_aim"})

	# Priority 65 — critically low HP regardless of aim direction.
	if health_pct < low_hp_threshold:
		return AIDecision.new("shield_block", 65, {"reason": "critical_hp"})

	# No reason to block.
	_maybe_end_block()
	return null


func physics_update(delta: float, decision: AIDecision) -> void:
	# Tick the post-block cooldown.
	if _block_cooldown > 0.0:
		_block_cooldown = maxf(0.0, _block_cooldown - delta)

	var currently_blocking: bool = decision != null and decision.state == "shield_block"

	if currently_blocking:
		_block_timer += delta
		# Force-drop the block after max duration to prevent permanent turtling,
		# but only if we're not holding because of live projectile threats.
		if _block_timer >= block_duration_max and _tracked_threats.is_empty():
			_end_block()
	else:
		# Decision changed away from blocking — start cooldown if we were blocking.
		_maybe_end_block()


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _maybe_end_block() -> void:
	if _block_timer > 0.0:
		_end_block()


func _end_block() -> void:
	if _block_timer > 0.0:
		_block_cooldown = block_cooldown_sec
	_block_timer = 0.0


func _is_shield_broken() -> bool:
	if _entity == null:
		return false
	var active_shield: ActiveShield = _entity.find_component(&"ActiveShield") as ActiveShield
	if active_shield == null:
		return false
	return active_shield.is_broken()


func _is_player_aiming_at_us() -> bool:
	if _target == null or _entity == null:
		return false
	var control: ControlSource = _target.get_node_or_null("ControlSource") as ControlSource
	if control == null:
		return false
	var aim: Vector2 = control.aim_dir(Vector2.RIGHT).normalized()
	# Direction from the player toward this entity.
	var dir_to_self: Vector2 = (_entity.global_position - _target.global_position).normalized()
	var dot: float = aim.dot(dir_to_self)
	return dot >= cos(deg_to_rad(player_aim_cone_deg))


func _is_player_attacking() -> bool:
	if _target == null:
		return false
	var sh: StateHandler = _target.get_node_or_null("StateHandler") as StateHandler
	if sh == null:
		return false
	return sh.current_state != null and sh.current_state.name == "Attack"


## Returns all live projectiles that are:
##   - Owned by a hostile entity
##   - Within projectile_vision_range
##   - Within projectile_vision_cone_deg of our facing direction
##   - Moving toward (or across) us (velocity has a component toward us)
func _get_threatening_projectiles() -> Array:
	if _entity == null:
		return []

	var threats: Array = []
	var my_pos: Vector2 = _entity.global_position
	var facing: Vector2 = _get_facing_vector()
	var cos_half: float = cos(deg_to_rad(projectile_vision_cone_deg))
	var range_sq: float = projectile_vision_range * projectile_vision_range

	# Get our Faction for hostility checks.
	var my_faction: Faction = _entity.get_node_or_null("Faction") as Faction
	if my_faction == null:
		my_faction = _find_faction_in_children(_entity)

	for proj_node in _entity.get_tree().get_nodes_in_group("projectiles"):
		var proj: Projectile = proj_node as Projectile
		if proj == null or not is_instance_valid(proj):
			continue

		# Distance check.
		var proj_pos: Vector2 = proj.global_position
		var dist_sq: float = my_pos.distance_squared_to(proj_pos)
		if dist_sq > range_sq:
			continue

		# Hostility check — skip projectiles we own or that come from allies.
		var proj_owner: Node = proj.get_projectile_owner()
		if proj_owner != null and my_faction != null:
			if not my_faction.is_hostile_to(proj_owner):
				continue

		# Vision cone check — is projectile within our forward cone?
		var dir_to_proj: Vector2 = (proj_pos - my_pos).normalized()
		if facing.dot(dir_to_proj) < cos_half:
			continue

		# Approach check — projectile velocity must have a component toward us.
		if proj.velocity != Vector2.ZERO:
			var dir_to_us: Vector2 = (my_pos - proj_pos).normalized()
			if proj.velocity.normalized().dot(dir_to_us) < 0.0:
				continue  # Moving away from us.

		threats.append(proj)

	return threats


func _get_facing_vector() -> Vector2:
	if _entity == null:
		return Vector2.RIGHT
	var fp: FacingPointer = _entity.get_node_or_null("FacingPointer") as FacingPointer
	if fp != null:
		return fp.get_facing_vector()
	# Fallback: face toward target if we have one.
	if _target != null:
		var dir: Vector2 = (_target.global_position - _entity.global_position)
		if dir.length_squared() > 1.0:
			return dir.normalized()
	return Vector2.RIGHT


func _find_faction_in_children(node: Node) -> Faction:
	for c in node.get_children():
		var f: Faction = c as Faction
		if f != null:
			return f
	return null

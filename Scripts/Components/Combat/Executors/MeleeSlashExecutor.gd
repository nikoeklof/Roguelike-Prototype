extends AttackExecutor
class_name MeleeSlashExecutor

var _hit_ids: Dictionary[int, bool] = {}
var _hitbox: Area2D = null
var _collision_shape: CollisionShape2D = null
var _attacker: Node2D = null

# Animation state
var _attack_aim_angle: float = 0.0
var _attack_progress: float = 0.0
var _active_time_total: float = 0.1


func execute() -> void:
	var melee: MeleeSlashVariant = variant as MeleeSlashVariant
	if melee == null:
		push_warning("MeleeSlashExecutor requires MeleeSlashVariant.")
		finish(false)
		return

	var snap: AttackSnapshot = resolve_snapshot()
	dispatch_attack_start()

	if snap.windup_time > 0.0:
		await wait_seconds(snap.windup_time)

	_spawn_hitbox(melee, snap)

	var active_time: float = max(snap.active_time, 0.01)
	await wait_seconds(active_time)

	_cleanup_hitbox()

	if snap.recovery_time > 0.0:
		await wait_seconds(snap.recovery_time)

	finish(true)


func _physics_process(delta: float) -> void:
	if _hitbox == null or not is_instance_valid(_hitbox):
		set_physics_process(false)
		return

	_attack_progress = minf(_attack_progress + delta / _active_time_total, 1.0)
	_update_hitbox_for_progress(_attack_progress)


func _spawn_hitbox(melee: MeleeSlashVariant, snap: AttackSnapshot) -> void:
	if context == null or context.owner == null:
		finish(false)
		return

	_attacker = context.owner as Node2D
	if _attacker == null:
		finish(false)
		return

	_hit_ids.clear()

	# Capture aim angle at spawn time so the arc starts from the correct direction.
	var aim: Vector2 = context.aim_dir
	if aim.length() < 0.001:
		aim = Vector2.RIGHT
	_attack_aim_angle = aim.angle()
	_active_time_total = maxf(snap.active_time, 0.01)
	_attack_progress = 0.0

	_hitbox = Area2D.new()
	_hitbox.name = "MeleeHitbox"
	_hitbox.monitoring = true
	_hitbox.monitorable = false
	_hitbox.top_level = true
	_hitbox.collision_layer = 1
	_hitbox.collision_mask = 0x7FFFFFFF

	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = snap.hitbox_size

	_collision_shape = CollisionShape2D.new()
	_collision_shape.shape = shape
	_collision_shape.position = snap.hitbox_offset
	_hitbox.add_child(_collision_shape)

	_hitbox.area_entered.connect(func(area: Area2D) -> void:
		_try_hit(area, melee.one_hit_per_target)
	)
	_hitbox.body_entered.connect(func(body: Node) -> void:
		_try_hit(body, melee.one_hit_per_target)
	)

	context.owner.add_child(_hitbox)

	# Apply lunge impulse at the moment the active phase begins.
	_apply_lunge(melee)

	# Position hitbox at t=0 immediately so the first overlap check is correct.
	_update_hitbox_for_progress(0.0)
	set_physics_process(true)


func _apply_lunge(melee: MeleeSlashVariant) -> void:
	if melee.lunge_speed <= 0.0:
		return
	var body: CharacterBody2D = context.owner as CharacterBody2D
	if body == null:
		return
	body.velocity += Vector2.RIGHT.rotated(_attack_aim_angle) * melee.lunge_speed


func _update_hitbox_for_progress(t: float) -> void:
	if _hitbox == null or not is_instance_valid(_hitbox) or _attacker == null:
		return
	if not is_instance_valid(_attacker):
		return

	var origin: Vector2 = _attacker.global_position
	var melee: MeleeSlashVariant = variant as MeleeSlashVariant
	if melee == null:
		_hitbox.global_position = origin
		_hitbox.global_rotation = _attack_aim_angle
		return

	var arc_half: float = deg_to_rad(melee.arc_degrees * 0.5)

	match melee.swing_style:
		MeleeSlashVariant.SwingStyle.SWING:
			# Bilateral arc: sweeps linearly from (aim - arc_half) to (aim + arc_half).
			# Midpoint (t=0.5) is exactly the aim direction.
			_hitbox.global_position = origin
			_hitbox.global_rotation = lerp_angle(
				_attack_aim_angle - arc_half,
				_attack_aim_angle + arc_half,
				t
			)

		MeleeSlashVariant.SwingStyle.OVERHEAD:
			# Power slam: same arc range as SWING so midpoint (t=0.5) = aim direction.
			# Ease-in-out (smoothstep) gives a slow telegraph wind-up then a fast slam
			# through the contact zone, then a brief follow-through — distinct from SWING's
			# constant-speed sweep while keeping the midpoint aligned with aim.
			var eased: float = t * t * (3.0 - 2.0 * t)  # smoothstep
			_hitbox.global_position = origin
			_hitbox.global_rotation = lerp_angle(
				_attack_aim_angle - arc_half,
				_attack_aim_angle + arc_half,
				eased
			)

		MeleeSlashVariant.SwingStyle.STAB:
			# Linear thrust: hitbox slides outward along the aim direction.
			# Collision shape x-position advances from 20% to 140% of configured reach.
			_hitbox.global_position = origin
			_hitbox.global_rotation = _attack_aim_angle
			if _collision_shape != null:
				var snap: AttackSnapshot = resolve_snapshot()
				var base_reach: float = snap.hitbox_offset.x
				_collision_shape.position.x = lerp(base_reach * 0.2, base_reach * 1.4, t)


func _try_hit(other: Node, one_hit_per_target: bool) -> void:
	if context == null or context.owner == null or other == null:
		return
	if other == context.owner:
		return

	var victim_root: Node = CombatQuery.resolve_victim_root(other)
	if victim_root == null:
		return

	if one_hit_per_target:
		var victim_id: int = victim_root.get_instance_id()
		if _hit_ids.has(victim_id):
			return
		_hit_ids[victim_id] = true

	var snap: AttackSnapshot = resolve_snapshot()
	var melee: MeleeSlashVariant = variant as MeleeSlashVariant

	var aim_dir: Vector2 = context.aim_dir
	if aim_dir.length() < 0.001:
		aim_dir = Vector2.RIGHT
	else:
		aim_dir = aim_dir.normalized()

	# --- Shield interaction ---
	# Check if the victim is actively blocking with a shield that faces the attacker.
	var active_shield: ActiveShield = _find_active_shield(victim_root)
	if active_shield != null and active_shield.is_blocking() and _shield_faces_attacker(victim_root, aim_dir):
		var penetration: float = melee.shield_penetration if melee != null else 0.0
		var absorbed: float = snap.damage * (1.0 - penetration)
		var through: float = snap.damage * penetration
		if absorbed > 0.0:
			active_shield.consume_shield_hp(absorbed)
		if through > 0.0:
			AttackImpactResolver.apply_hit(context, snap, victim_root, other, aim_dir, through)
		return

	AttackImpactResolver.apply_hit(context, snap, victim_root, other, aim_dir)


func _find_active_shield(root: Node) -> ActiveShield:
	if root is Entity:
		return (root as Entity).find_component(&"ActiveShield") as ActiveShield
	return root.get_node_or_null("ActiveShield") as ActiveShield


func _shield_faces_attacker(victim_root: Node, hit_dir: Vector2) -> bool:
	## Returns true when the victim's facing direction is oriented toward the attacker,
	## meaning the shield intercepts the incoming strike.
	## hit_dir points from attacker toward victim; -hit_dir points victim → attacker.
	var fp: FacingPointer = victim_root.get_node_or_null("FacingPointer") as FacingPointer
	if fp == null and victim_root is Entity:
		fp = (victim_root as Entity).get_node_or_null("FacingPointer") as FacingPointer
	if fp == null:
		return true  # No facing data — assume the shield intercepts.
	# dot > 0: blocker is facing at least partially toward the attacker.
	return fp.get_facing_vector().dot(-hit_dir) > 0.0


func _cleanup_hitbox() -> void:
	set_physics_process(false)
	_collision_shape = null
	_attacker = null

	if _hitbox != null and is_instance_valid(_hitbox):
		_hitbox.queue_free()
	_hitbox = null


func _exit_tree() -> void:
	_cleanup_hitbox()

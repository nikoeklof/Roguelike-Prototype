extends AttackExecutor
class_name RangedFireExecutor

@export var debug_draw_shots: bool = true
@export_range(0.01, 1.0, 0.01) var debug_hitscan_life_sec: float = 0.08
@export_range(0.01, 2.0, 0.01) var debug_beam_life_pad_sec: float = 0.05
@export_range(1.0, 16.0, 0.5) var debug_line_width: float = 2.0

var _beam_tween: Tween = null
var _beam_line: Line2D = null


func execute() -> void:
	var ranged: RangedFireVariant = variant as RangedFireVariant
	if ranged == null:
		push_warning("RangedFireExecutor requires RangedFireVariant.")
		finish(false)
		return

	var snap: AttackSnapshot = resolve_snapshot()
	dispatch_attack_start()

	if snap.windup_time > 0.0:
		await wait_seconds(snap.windup_time)

	_fire(ranged, snap)

	if snap.recovery_time > 0.0:
		await wait_seconds(snap.recovery_time)

	finish(true)


func _fire(ranged: RangedFireVariant, snap: AttackSnapshot) -> void:
	if context == null or context.owner == null:
		return
	if not (context.owner is Node2D):
		return

	var owner: Node2D = context.owner as Node2D
	var muzzle: Node2D = _resolve_muzzle(owner)

	var inst: ItemInstance = context.item_instance

	var base_dir: Vector2 = context.aim_dir
	if base_dir.length() < 0.001:
		base_dir = Vector2.RIGHT
	else:
		base_dir = base_dir.normalized()

	var projectile_count: int = maxi(1, snap.projectile_count)
	for i: int in range(projectile_count):
		var shot: RangedShotData = _build_base_shot(ranged, snap, muzzle, base_dir, i, projectile_count, inst)
		_dispatch_modify_shot(shot, inst)
		_execute_shot(shot, snap, inst)


func _build_base_shot(
	ranged: RangedFireVariant,
	snap: AttackSnapshot,
	muzzle: Node2D,
	base_dir: Vector2,
	index: int,
	count: int,
	inst: ItemInstance
) -> RangedShotData:
	var shot: RangedShotData = RangedShotData.new()

	shot.mode = ranged.default_mode
	if snap.ranged_mode >= 0:
		shot.mode = snap.ranged_mode

	shot.origin = muzzle.global_position + ranged.muzzle_offset.rotated(muzzle.global_rotation)
	shot.direction = _compute_shot_dir(ranged, base_dir, index, count, inst)

	shot.damage = snap.damage
	shot.pierce = snap.pierce
	shot.shot_index = index
	shot.shot_count = count

	shot.projectile_scene = ranged.projectile_scene
	shot.speed = ranged.projectile_speed
	shot.gravity = ranged.projectile_gravity
	shot.lifetime_sec = ranged.projectile_lifetime_sec
	shot.inherit_owner_velocity = ranged.inherit_owner_velocity

	shot.range = ranged.hitscan_range
	if shot.mode == RangedShotData.ShotMode.BEAM:
		shot.range = ranged.beam_range

	shot.beam_duration_sec = ranged.beam_duration_sec
	shot.beam_tick_sec = ranged.beam_tick_sec

	if ranged.projectile_range > 0.0:
		shot.range = ranged.projectile_range

	return shot


func _dispatch_modify_shot(shot: RangedShotData, inst: ItemInstance) -> void:
	if inst == null:
		return
	ItemAttributeBus.dispatch_modify_ranged_shot(context, shot, inst)


func _execute_shot(shot: RangedShotData, snap: AttackSnapshot, inst: ItemInstance) -> void:
	match shot.mode:
		RangedShotData.ShotMode.PROJECTILE:
			_fire_projectile(shot, inst)
		RangedShotData.ShotMode.HITSCAN:
			_fire_hitscan(shot, snap)
		RangedShotData.ShotMode.BEAM:
			_start_beam(shot, snap)


func _compute_shot_dir(
	ranged: RangedFireVariant,
	base_dir: Vector2,
	index: int,
	count: int,
	inst: ItemInstance
) -> Vector2:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var seed_base: int = inst.seed if inst != null else 1337
	rng.seed = int((seed_base * 1103515245 + 12345 + index * 1013) & 0x7fffffff)

	if count > 1 and ranged.spread_pattern_degrees > 0.0:
		var half_arc: float = deg_to_rad(ranged.spread_pattern_degrees) * 0.5
		var t: float = 0.0 if count <= 1 else float(index) / float(count - 1)
		var ang: float = lerp(-half_arc, half_arc, t)
		return base_dir.rotated(ang).normalized()

	if ranged.spread_degrees <= 0.0:
		return base_dir

	var half: float = ranged.spread_degrees * 0.5
	var ang_rand: float = deg_to_rad(rng.randf_range(-half, half))
	return base_dir.rotated(ang_rand).normalized()


func _resolve_muzzle(owner: Node) -> Node2D:
	var ws: Node2D = owner.get_node_or_null("FacingPointer/AimRay/WeaponSocket") as Node2D
	if ws != null:
		return ws

	var ar: Node2D = owner.get_node_or_null("FacingPointer/AimRay") as Node2D
	if ar != null:
		return ar

	var direct: Node2D = owner.get_node_or_null("WeaponSocket") as Node2D
	if direct != null:
		return direct

	return owner as Node2D


func _fire_projectile(shot: RangedShotData, inst: ItemInstance) -> void:
	if shot.projectile_scene == null:
		push_warning("Ranged shot PROJECTILE has no projectile_scene.")
		return

	var node: Node = shot.projectile_scene.instantiate()
	var projectile: Projectile = node as Projectile
	if projectile == null:
		push_warning("projectile_scene is not a Projectile.")
		if is_instance_valid(node):
			node.queue_free()
		return

	projectile.global_position = shot.origin

	var velocity: Vector2 = shot.direction.normalized() * shot.speed
	if shot.inherit_owner_velocity > 0.0 and context.owner is CharacterBody2D:
		var owner_body: CharacterBody2D = context.owner as CharacterBody2D
		velocity += owner_body.velocity * clampf(shot.inherit_owner_velocity, 0.0, 1.0)

	projectile.setup(
		velocity,
		shot.gravity,
		shot.lifetime_sec,
		int(round(shot.damage)),
		shot.pierce,
		context.owner
	)

	if inst != null:
		ItemAttributeBus.dispatch_projectile_spawn(context, projectile, inst)

	var owner: Node = context.owner
	if owner != null and owner.get_parent() != null:
		owner.get_parent().add_child(projectile)
	else:
		get_tree().current_scene.add_child(projectile)


func _fire_hitscan(shot: RangedShotData, snap: AttackSnapshot) -> void:
	if context == null or context.owner == null:
		return
	if not (context.owner is Node2D):
		return

	var owner: Node2D = context.owner as Node2D
	var space: PhysicsDirectSpaceState2D = owner.get_world_2d().direct_space_state

	var to: Vector2 = shot.origin + shot.direction.normalized() * max(1.0, shot.range)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(shot.origin, to)
	query.exclude = [owner.get_rid()]
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		_debug_draw_transient_line(shot.origin, to, debug_hitscan_life_sec)
		return

	var hit_pos: Vector2 = hit.get("position", to) as Vector2
	_debug_draw_transient_line(shot.origin, hit_pos, debug_hitscan_life_sec)

	var collider_obj: Object = hit.get("collider")
	var collider_node: Node = collider_obj as Node
	if collider_node == null:
		return

	var victim_root: Node = CombatQuery.resolve_victim_root(collider_node)
	if victim_root == null:
		return

	AttackImpactResolver.apply_hit(
		context,
		snap,
		victim_root,
		collider_node,
		shot.direction,
		shot.damage
	)


func _start_beam(shot: RangedShotData, snap: AttackSnapshot) -> void:
	_kill_beam()

	var tick_sec: float = max(shot.beam_tick_sec, 0.01)
	var ticks: int = int(ceil(shot.beam_duration_sec / tick_sec))

	_beam_tween = (context.owner as Node).create_tween()
	_beam_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)

	for _i: int in range(ticks):
		_beam_tween.tween_callback(func() -> void:
			_beam_tick(shot, snap)
		)
		_beam_tween.tween_interval(tick_sec)

	_beam_tween.tween_callback(func() -> void:
		_kill_beam()
	)


func _beam_tick(base_shot: RangedShotData, snap: AttackSnapshot) -> void:
	if context == null or context.owner == null:
		return
	if not (context.owner is Node2D):
		return

	var owner: Node2D = context.owner as Node2D
	var muzzle: Node2D = _resolve_muzzle(owner)

	var origin: Vector2 = muzzle.global_position
	var dir: Vector2 = context.aim_dir
	if dir.length() < 0.001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()

	var range_val: float = max(1.0, base_shot.range)
	var to: Vector2 = origin + dir * range_val

	var space: PhysicsDirectSpaceState2D = owner.get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origin, to)
	query.exclude = [owner.get_rid()]
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		_debug_set_beam_line(origin, to)
		return

	var hit_pos: Vector2 = hit.get("position", to) as Vector2
	_debug_set_beam_line(origin, hit_pos)

	var collider_obj: Object = hit.get("collider")
	var collider_node: Node = collider_obj as Node
	if collider_node == null:
		return

	var victim_root: Node = CombatQuery.resolve_victim_root(collider_node)
	if victim_root == null:
		return

	AttackImpactResolver.apply_hit(
		context,
		snap,
		victim_root,
		collider_node,
		dir,
		base_shot.damage
	)


func _kill_beam() -> void:
	if _beam_tween != null and is_instance_valid(_beam_tween):
		_beam_tween.kill()
	_beam_tween = null
	_debug_clear_beam_line(debug_beam_life_pad_sec)


func _debug_make_line(parent: Node) -> Line2D:
	var line: Line2D = Line2D.new()
	line.width = debug_line_width
	line.z_index = 1024
	line.z_as_relative = false
	parent.add_child(line)

	var timer: SceneTreeTimer = get_tree().create_timer(0.15)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(line):
			line.queue_free()
	)

	return line


func _debug_draw_transient_line(from: Vector2, to: Vector2, life_sec: float) -> void:
	if not debug_draw_shots:
		return
	if context == null or context.owner == null:
		return
	if not (context.owner is Node2D):
		return

	var owner: Node2D = context.owner as Node2D
	var parent: Node = owner.get_parent() if owner.get_parent() != null else get_tree().current_scene
	if parent == null:
		return

	var line: Line2D = _debug_make_line(parent)
	line.add_point(from)
	line.add_point(to)

	var tween: Tween = line.create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_interval(max(0.01, life_sec))
	tween.tween_callback(func() -> void:
		if is_instance_valid(line):
			line.queue_free()
	)


func _debug_set_beam_line(from: Vector2, to: Vector2) -> void:
	if not debug_draw_shots:
		return
	if context == null or context.owner == null:
		return
	if not (context.owner is Node2D):
		return

	if _beam_line == null or not is_instance_valid(_beam_line):
		var owner: Node2D = context.owner as Node2D
		var parent: Node = owner.get_parent() if owner.get_parent() != null else get_tree().current_scene
		if parent == null:
			return
		_beam_line = _debug_make_line(parent)

	_beam_line.clear_points()
	_beam_line.add_point(from)
	_beam_line.add_point(to)


func _debug_clear_beam_line(delay_sec: float) -> void:
	if _beam_line == null or not is_instance_valid(_beam_line):
		_beam_line = null
		return

	var line: Line2D = _beam_line
	_beam_line = null

	var tween: Tween = line.create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_interval(max(0.01, delay_sec))
	tween.tween_callback(func() -> void:
		if is_instance_valid(line):
			line.queue_free()
	)

extends AttackExecutor
class_name RangedFireExecutor

const DEFAULT_PROJECTILE_SCENE: PackedScene = preload("res://Scenes/Templates/EquipmentItems/Projectile_template.tscn")

@export var debug_draw_shots: bool = true
@export_range(0.01, 1.0, 0.01) var debug_hitscan_life_sec: float = 0.08
@export_range(0.01, 2.0, 0.01) var debug_beam_life_pad_sec: float = 0.05
@export_range(1.0, 16.0, 0.5) var debug_line_width: float = 2.0

var _beam_tween: Tween = null
var _beam_line: Line2D = null


func execute() -> void:
	var snap: AttackSnapshot = resolve_snapshot()
	dispatch_attack_start()

	if snap.windup_time > 0.0:
		await wait_seconds(snap.windup_time)

	_fire(snap)

	if snap.recovery_time > 0.0:
		await wait_seconds(snap.recovery_time)

	finish(true)


func _fire(snap: AttackSnapshot) -> void:
	if context == null or context.owner == null:
		return
	if not (context.owner is Node2D):
		return

	var owner_entity: Node2D = context.owner as Node2D
	var muzzle: Node2D = _resolve_muzzle(owner_entity)
	var inst: ItemInstance = context.item_instance

	var base_dir: Vector2 = context.aim_dir
	if base_dir.length() < 0.001:
		base_dir = Vector2.RIGHT
	else:
		base_dir = base_dir.normalized()

	var projectile_count: int = maxi(1, snap.projectile_count)
	for i: int in range(projectile_count):
		var shot: RangedShotData = _build_base_shot(snap, muzzle, base_dir, i, projectile_count, inst)
		_dispatch_modify_shot(shot, inst)
		_execute_shot(shot, snap, context, inst)


func _build_base_shot(
	snap: AttackSnapshot,
	muzzle: Node2D,
	base_dir: Vector2,
	index: int,
	count: int,
	inst: ItemInstance
) -> RangedShotData:
	var shot: RangedShotData = RangedShotData.new()

	shot.mode = snap.ranged_mode as RangedShotData.ShotMode
	shot.origin = muzzle.global_position + snap.muzzle_offset.rotated(muzzle.global_rotation)
	shot.direction = _compute_shot_dir(snap, base_dir, index, count, inst)

	shot.damage = snap.damage
	shot.pierce = snap.pierce
	shot.shot_index = index
	shot.shot_count = count

	shot.projectile_spec = snap.projectile_spec
	shot.projectile_scene = snap.projectile_scene
	shot.speed = snap.projectile_speed
	shot.gravity = snap.projectile_gravity
	shot.lifetime_sec = snap.projectile_lifetime_sec
	shot.projectile_radius = snap.projectile_radius
	shot.projectile_collision_mask = snap.projectile_collision_mask
	shot.projectile_sprite_texture = snap.projectile_sprite_texture
	shot.projectile_sprite_tint = snap.projectile_sprite_tint
	shot.inherit_owner_velocity = snap.projectile_inherit_owner_velocity

	shot.max_range = snap.hitscan_range
	if shot.mode == RangedShotData.ShotMode.BEAM:
		shot.max_range = snap.beam_range

	shot.beam_duration_sec = snap.beam_duration_sec
	shot.beam_tick_sec = snap.beam_tick_sec

	if snap.projectile_range > 0.0:
		shot.max_range = snap.projectile_range

	return shot


func _dispatch_modify_shot(shot: RangedShotData, inst: ItemInstance) -> void:
	if inst == null:
		return
	ItemAttributeBus.dispatch_modify_ranged_shot(context, shot, inst)


func _execute_shot(
	shot: RangedShotData,
	snap: AttackSnapshot,
	combat_context: CombatContext,
	inst: ItemInstance
) -> void:
	match shot.mode:
		RangedShotData.ShotMode.PROJECTILE:
			_fire_projectile(shot, snap, inst)
		RangedShotData.ShotMode.HITSCAN:
			_fire_hitscan(shot, snap, combat_context)
		RangedShotData.ShotMode.BEAM:
			_start_beam(shot, snap, combat_context)


func _compute_shot_dir(
	snap: AttackSnapshot,
	base_dir: Vector2,
	index: int,
	count: int,
	inst: ItemInstance
) -> Vector2:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var seed_base: int = inst.item_seed if inst != null else 1337
	var roll: int = maxi(1, snap.spread_roll)

	rng.seed = int(
		(seed_base * 1103515245 + 12345 + roll * 7919 + index * 1013) & 0x7fffffff
	)

	var dir: Vector2 = base_dir

	if count > 1 and snap.spread_pattern_degrees > 0.0:
		var half_arc: float = deg_to_rad(snap.spread_pattern_degrees) * 0.5
		var t: float = 0.5 if count <= 1 else float(index) / float(count - 1)
		var pattern_ang: float = lerp(-half_arc, half_arc, t)
		dir = dir.rotated(pattern_ang)

	if snap.spread_degrees > 0.0:
		var half_rand: float = snap.spread_degrees * 0.5
		var rand_ang: float = deg_to_rad(rng.randf_range(-half_rand, half_rand))
		dir = dir.rotated(rand_ang)

	return dir.normalized()


func _resolve_muzzle(source_entity: Node) -> Node2D:
	var ws: Node2D = source_entity.get_node_or_null("FacingPointer/AimRay/WeaponSocket") as Node2D
	if ws != null:
		return ws

	var ar: Node2D = source_entity.get_node_or_null("FacingPointer/AimRay") as Node2D
	if ar != null:
		return ar

	var direct: Node2D = source_entity.get_node_or_null("WeaponSocket") as Node2D
	if direct != null:
		return direct

	return source_entity as Node2D


func _fire_projectile(shot: RangedShotData, snap: AttackSnapshot, inst: ItemInstance) -> void:
	var proj_scene: PackedScene = shot.projectile_scene
	if proj_scene == null and shot.projectile_spec != null:
		proj_scene = shot.projectile_spec.scene
	if proj_scene == null:
		proj_scene = DEFAULT_PROJECTILE_SCENE

	var node: Node = proj_scene.instantiate()
	var projectile: Projectile = node as Projectile
	if projectile == null:
		push_warning("projectile_scene is not a Projectile.")
		if is_instance_valid(node):
			node.queue_free()
		return

	var velocity: Vector2 = shot.direction.normalized() * shot.speed
	if shot.inherit_owner_velocity > 0.0 and context.owner is CharacterBody2D:
		var owner_body: CharacterBody2D = context.owner as CharacterBody2D
		velocity += owner_body.velocity * clampf(shot.inherit_owner_velocity, 0.0, 1.0)

	var launch: ProjectileLaunchData = ProjectileLaunchData.new()
	launch.context = context
	launch.snapshot = snap
	launch.owner = context.owner
	launch.origin = shot.origin
	launch.direction = shot.direction.normalized()
	launch.velocity = velocity
	launch.gravity = shot.gravity
	launch.lifetime_sec = shot.lifetime_sec
	launch.damage = shot.damage
	launch.pierce = shot.pierce
	launch.radius = max(1.0, shot.projectile_radius)
	launch.max_range = max(0.0, shot.max_range)
	launch.collision_mask = shot.projectile_collision_mask
	launch.sprite_texture = shot.projectile_sprite_texture
	launch.sprite_tint = shot.projectile_sprite_tint

	projectile.global_position = launch.origin
	projectile.setup(launch)

	if inst != null:
		ItemAttributeBus.dispatch_projectile_spawn(context, projectile, inst)

	var parent_node: Node = context.owner
	if parent_node != null and parent_node.get_parent() != null:
		parent_node.get_parent().add_child(projectile)
	else:
		get_tree().current_scene.add_child(projectile)


func _collect_ray_hits(
	origin: Vector2,
	to: Vector2,
	source_entity: Node2D,
	max_targets: int
) -> Dictionary:
	var space: PhysicsDirectSpaceState2D = source_entity.get_world_2d().direct_space_state
	var exclude: Array[RID] = _build_owner_exclude_list(source_entity)
	var victims: Array[Dictionary] = []
	var final_pos: Vector2 = to
	var seen_victims: Dictionary = {}

	for _i: int in range(max_targets + 16):
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origin, to)
		query.exclude = exclude
		query.collide_with_areas = true
		query.collide_with_bodies = true

		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			final_pos = to
			break

		var collider_obj: Object = hit.get("collider", null) as Object
		var collider_node: Node = collider_obj as Node
		var hit_pos: Vector2 = hit.get("position", to) as Vector2
		var hit_rid: RID = hit.get("rid", RID()) as RID

		final_pos = hit_pos

		if collider_node == null:
			break

		var victim_root: Node = CombatQuery.resolve_victim_root(collider_node)

		# Non-victim collider (wall/terrain/etc.) blocks the ray.
		if victim_root == null:
			break

		# Ignore self-hits if they slipped through.
		if victim_root == source_entity or source_entity.is_ancestor_of(victim_root):
			_collect_collision_rids(victim_root, exclude)
			continue

		# If we've already hit this victim, exclude all of its colliders and keep going.
		if seen_victims.has(victim_root):
			_collect_collision_rids(victim_root, exclude)
			continue

		seen_victims[victim_root] = true

		victims.append({
			"victim_root": victim_root,
			"collider_node": collider_node,
			"position": hit_pos,
			"rid": hit_rid,
		})

		# Exclude every collider belonging to this victim so the next raycast
		# can continue past the whole target, not just one shape.
		_collect_collision_rids(victim_root, exclude)

		if victims.size() >= max_targets:
			break

	return {
		"victims": victims,
		"final_pos": final_pos,
	}


func _fire_hitscan(
	shot: RangedShotData,
	snap: AttackSnapshot,
	combat_context: CombatContext
) -> void:
	if combat_context == null or combat_context.owner == null:
		return
	if not (combat_context.owner is Node2D):
		return

	var source_entity: Node2D = combat_context.owner as Node2D
	var origin: Vector2 = shot.origin
	var dir: Vector2 = shot.direction.normalized()
	var range_value: float = max(1.0, shot.max_range)
	var damage: float = shot.damage
	var pierce: int = max(0, shot.pierce)

	var to: Vector2 = origin + dir * range_value
	var max_targets: int = max(1, pierce + 1)

	var result: Dictionary = _collect_ray_hits(origin, to, source_entity, max_targets)
	var victims: Array[Dictionary] = result.get("victims", []) as Array[Dictionary]
	var final_pos: Vector2 = result.get("final_pos", to) as Vector2

	_debug_draw_transient_line(origin, final_pos, debug_hitscan_life_sec)

	for entry: Dictionary in victims:
		var victim_root: Node = entry["victim_root"] as Node
		var collider_node: Node = entry["collider_node"] as Node

		AttackImpactResolver.apply_hit(
			combat_context,
			snap,
			victim_root,
			collider_node,
			dir,
			damage
		)


func _start_beam(
	shot: RangedShotData,
	snap: AttackSnapshot,
	combat_context: CombatContext
) -> void:
	_kill_beam()

	if combat_context == null or combat_context.owner == null:
		return

	var owner_node: Node = combat_context.owner as Node
	if owner_node == null:
		return

	var tick_sec: float = max(shot.beam_tick_sec, 0.01)
	var ticks: int = int(ceil(shot.beam_duration_sec / tick_sec))

	_beam_tween = owner_node.create_tween()
	_beam_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)

	for _i: int in range(ticks):
		_beam_tween.tween_callback(Callable(self, "_beam_tick_callback").bind(shot, snap, combat_context))
		_beam_tween.tween_interval(tick_sec)

	_beam_tween.tween_callback(Callable(self, "_beam_finish_callback"))


func _beam_tick_callback(
	shot: RangedShotData,
	snap: AttackSnapshot,
	combat_context: CombatContext
) -> void:
	_beam_tick(shot, snap, combat_context)


func _beam_finish_callback() -> void:
	_kill_beam()


func _beam_tick(
	base_shot: RangedShotData,
	snap: AttackSnapshot,
	combat_context: CombatContext
) -> void:
	if combat_context == null or combat_context.owner == null:
		return
	if not (combat_context.owner is Node2D):
		return

	var source_entity: Node2D = combat_context.owner as Node2D
	var muzzle: Node2D = _resolve_muzzle(source_entity)

	var origin: Vector2 = muzzle.global_position
	var dir: Vector2 = combat_context.aim_dir
	if dir.length() < 0.001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()

	var range_value: float = max(1.0, base_shot.max_range)
	var damage: float = base_shot.damage
	var pierce: int = max(0, base_shot.pierce)

	var to: Vector2 = origin + dir * range_value
	var max_targets: int = max(1, pierce + 1)

	var result: Dictionary = _collect_ray_hits(origin, to, source_entity, max_targets)
	var victims: Array[Dictionary] = result.get("victims", []) as Array[Dictionary]
	var final_pos: Vector2 = result.get("final_pos", to) as Vector2

	_debug_set_beam_line(origin, final_pos)

	for entry: Dictionary in victims:
		var victim_root: Node = entry["victim_root"] as Node
		var collider_node: Node = entry["collider_node"] as Node

		AttackImpactResolver.apply_hit(
			combat_context,
			snap,
			victim_root,
			collider_node,
			dir,
			damage
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
	return line


func _debug_draw_transient_line(from: Vector2, to: Vector2, life_sec: float) -> void:
	if not debug_draw_shots:
		return
	if context == null or context.owner == null:
		return
	if not (context.owner is Node2D):
		return

	var source_entity: Node2D = context.owner as Node2D
	var parent: Node = source_entity.get_parent() if source_entity.get_parent() != null else get_tree().current_scene
	if parent == null:
		return

	var line: Line2D = _debug_make_line(parent)
	line.add_point(from)
	line.add_point(to)

	var tween: Tween = line.create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_interval(max(0.01, life_sec))
	tween.tween_callback(Callable(line, "queue_free"))


func _debug_set_beam_line(from: Vector2, to: Vector2) -> void:
	if not debug_draw_shots:
		return
	if context == null or context.owner == null:
		return
	if not (context.owner is Node2D):
		return

	if _beam_line == null or not is_instance_valid(_beam_line):
		var source_entity: Node2D = context.owner as Node2D
		var parent: Node = source_entity.get_parent() if source_entity.get_parent() != null else get_tree().current_scene
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

	# Free immediately if delay is negligible, otherwise tween
	if delay_sec <= 0.01:
		line.queue_free()
		return

	if not line.is_inside_tree():
		line.queue_free()
		return

	var tween: Tween = line.create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_interval(max(0.01, delay_sec))
	tween.tween_callback(Callable(line, "queue_free"))


func _build_owner_exclude_list(source_entity: Node) -> Array[RID]:
	var out: Array[RID] = []
	_collect_collision_rids(source_entity, out)
	return out


func _collect_collision_rids(node: Node, out: Array[RID]) -> void:
	if node == null:
		return

	if node is CollisionObject2D:
		var co: CollisionObject2D = node as CollisionObject2D
		out.append(co.get_rid())

	for child: Node in node.get_children():
		_collect_collision_rids(child, out)


func _exit_tree() -> void:
	if _beam_tween != null and is_instance_valid(_beam_tween):
		_beam_tween.kill()
	_beam_tween = null

	if _beam_line != null and is_instance_valid(_beam_line):
		_beam_line.queue_free()
	_beam_line = null

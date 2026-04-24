extends AttackExecutor
class_name RangedFireExecutor

const DEFAULT_PROJECTILE_SCENE: PackedScene = preload("res://Scenes/Templates/EquipmentItems/Projectile_template.tscn")

@export var debug_draw_shots: bool = true
@export_range(0.01, 1.0, 0.01) var debug_hitscan_life_sec: float = 0.08
@export_range(0.01, 2.0, 0.01) var debug_beam_life_pad_sec: float = 0.05
@export_range(1.0, 16.0, 0.5) var debug_line_width: float = 2.0

## Damage multiplier applied per beam tick. Keeps sustained beam DPS balanced
## relative to projectile/hitscan bursts (beam fires many ticks per second).
@export_range(0.05, 2.0, 0.05) var beam_damage_per_tick_mult: float = 0.4

## One Line2D per beam index (supports multi-shot beam spread).
var _beam_lines: Dictionary = {}


func execute() -> void:
	var snap: AttackSnapshot = resolve_snapshot()
	dispatch_attack_start()

	if snap.windup_time > 0.0:
		await wait_seconds(snap.windup_time)

	if _is_beam_mode(snap):
		await _execute_beam_continuous(snap)
		# Release the sentinel cooldown so the weapon can fire again immediately.
		_clear_cooldown_on_owner()
	else:
		_fire(snap)
		if snap.recovery_time > 0.0:
			await wait_seconds(snap.recovery_time)

	finish(true)


# ---------------------------------------------------------------------------
# Beam — continuous path
# ---------------------------------------------------------------------------

func _is_beam_mode(snap: AttackSnapshot) -> bool:
	if snap.ranged_mode == RangedShotData.ShotMode.BEAM:
		return true
	if context == null or context.item_instance == null:
		return false
	for attr: ItemAttribute in context.item_instance.attributes:
		if attr is BeamModeAttribute:
			return true
	return false


func _execute_beam_continuous(snap: AttackSnapshot) -> void:
	var tick_sec: float = maxf(0.02, snap.beam_tick_sec)

	# Fire first tick immediately, then loop while the attack button is held.
	_fire_beam_tick_all(snap)

	while true:
		await wait_seconds(tick_sec)

		if not _is_attack_held():
			break

		_update_context_aim()
		_fire_beam_tick_all(snap)

	_kill_beam()


func _fire_beam_tick_all(snap: AttackSnapshot) -> void:
	if context == null or context.owner == null:
		return
	if not (context.owner is Node2D):
		return

	var owner_entity: Node2D = context.owner as Node2D
	var muzzle: Node2D = _resolve_muzzle(owner_entity)
	var inst: ItemInstance = context.item_instance
	var count: int = maxi(1, snap.projectile_count)

	var base_dir: Vector2 = context.aim_dir
	if base_dir.length() < 0.001:
		base_dir = Vector2.RIGHT
	else:
		base_dir = base_dir.normalized()

	# Vary spread_roll each tick so random spread shifts frame-to-frame.
	snap.spread_roll = (snap.spread_roll + 1) % 64

	for i: int in range(count):
		var shot: RangedShotData = _build_base_shot(snap, muzzle, base_dir, i, count, inst)
		_dispatch_modify_shot(shot, inst)

		# Enforce beam mode and apply per-tick damage multiplier.
		shot.mode = RangedShotData.ShotMode.BEAM
		var tick_damage: float = shot.damage * beam_damage_per_tick_mult

		var origin: Vector2 = shot.origin
		var dir: Vector2 = shot.direction.normalized()
		var range_val: float = maxf(1.0, shot.max_range)
		var to: Vector2 = origin + dir * range_val
		var max_targets: int = maxi(1, shot.pierce + 1)

		var result: Dictionary = _collect_ray_hits(origin, to, owner_entity, max_targets, tick_damage)
		var victims: Array[Dictionary] = result.get("victims", []) as Array[Dictionary]
		var final_pos: Vector2 = result.get("final_pos", to) as Vector2

		_debug_set_beam_line_indexed(i, origin, final_pos)

		for entry: Dictionary in victims:
			var victim_root: Node = entry["victim_root"] as Node
			var collider_node: Node = entry["collider_node"] as Node
			AttackImpactResolver.apply_hit(context, snap, victim_root, collider_node, dir, tick_damage)


func _is_attack_held() -> bool:
	if context == null or context.owner == null:
		return false
	var control: ControlSource = context.owner.get_node_or_null("ControlSource") as ControlSource
	if control == null:
		return false
	return control.attack_is_down()


func _update_context_aim() -> void:
	if context == null or context.owner == null:
		return
	var control: ControlSource = context.owner.get_node_or_null("ControlSource") as ControlSource
	if control == null:
		return
	var dir: Vector2 = control.aim_dir(Vector2.RIGHT)
	if dir.length() > 0.001:
		context.aim_dir = dir.normalized()


func _clear_cooldown_on_owner() -> void:
	if context == null or context.owner == null:
		return
	var combat: Combat = context.owner.get_node_or_null("Combat") as Combat
	if combat != null:
		combat.clear_cooldown(context.item)


# ---------------------------------------------------------------------------
# Projectile / hitscan fire path (unchanged)
# ---------------------------------------------------------------------------

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
			# Continuous beam is handled by _execute_beam_continuous().
			# This branch is a safety fallback — treat as hitscan.
			_fire_hitscan(shot, snap, combat_context)


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


func _find_parry_collider(node: Node) -> ParryCollider:
	if node is ParryCollider:
		return node as ParryCollider
	if node != null and node.get_parent() is ParryCollider:
		return node.get_parent() as ParryCollider
	return null


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

	var proj_parent: Node = get_tree().current_scene
	proj_parent.add_child(projectile)
	projectile.global_position = launch.origin
	projectile.setup(launch)

	if inst != null:
		ItemAttributeBus.dispatch_projectile_spawn(context, projectile, inst)


func _collect_ray_hits(
	origin: Vector2,
	to: Vector2,
	source_entity: Node2D,
	max_targets: int,
	shot_damage: float = 0.0
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

		# Shield block — stop the ray here.
		var parry: ParryCollider = _find_parry_collider(collider_node)
		if parry != null:
			parry.on_shot_blocked(shot_damage, source_entity)
			break

		var victim_root: Node = CombatQuery.resolve_victim_root(collider_node)

		if victim_root == null:
			break

		if victim_root == source_entity or source_entity.is_ancestor_of(victim_root):
			_collect_collision_rids(victim_root, exclude)
			continue

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

	var result: Dictionary = _collect_ray_hits(origin, to, source_entity, max_targets, damage)
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


# ---------------------------------------------------------------------------
# Beam line visuals (indexed per shot for multi-beam support)
# ---------------------------------------------------------------------------

func _kill_beam() -> void:
	_debug_clear_all_beam_lines(debug_beam_life_pad_sec)


func _debug_set_beam_line_indexed(index: int, from: Vector2, to: Vector2) -> void:
	if not debug_draw_shots:
		return
	if context == null or context.owner == null:
		return
	if not (context.owner is Node2D):
		return

	if not _beam_lines.has(index) or not is_instance_valid(_beam_lines[index]):
		var parent: Node = get_tree().current_scene
		if parent == null:
			return
		_beam_lines[index] = _debug_make_line(parent)

	var line: Line2D = _beam_lines[index] as Line2D
	if line == null:
		return
	line.clear_points()
	line.add_point(from)
	line.add_point(to)


func _debug_clear_all_beam_lines(delay_sec: float) -> void:
	for idx: int in _beam_lines.keys():
		var line: Line2D = _beam_lines[idx] as Line2D
		if line == null or not is_instance_valid(line):
			continue
		if delay_sec <= 0.01 or not line.is_inside_tree():
			line.queue_free()
			continue
		var tween: Tween = line.create_tween()
		tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tween.tween_interval(maxf(0.01, delay_sec))
		tween.tween_callback(Callable(line, "queue_free"))
	_beam_lines.clear()


# ---------------------------------------------------------------------------
# Shared debug helpers
# ---------------------------------------------------------------------------

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

	var parent: Node = get_tree().current_scene
	if parent == null:
		return

	var line: Line2D = _debug_make_line(parent)
	line.add_point(from)
	line.add_point(to)

	var tween: Tween = line.create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_interval(max(0.01, life_sec))
	tween.tween_callback(Callable(line, "queue_free"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

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
	_debug_clear_all_beam_lines(0.0)

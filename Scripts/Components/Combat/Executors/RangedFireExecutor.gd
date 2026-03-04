extends AttackExecutor
class_name RangedFireExecutor

@export var debug_draw_shots: bool = true
@export_range(0.01, 1.0, 0.01) var debug_hitscan_life_sec: float = 0.08
@export_range(0.01, 2.0, 0.01) var debug_beam_life_pad_sec: float = 0.05
@export_range(1.0, 16.0, 0.5) var debug_line_width: float = 2.0

var _beam_tween: Tween = null
var _beam_line: Line2D = null
var _attr_bus: CombatAttributeBus


func execute() -> void:
	var v: RangedFireVariant = variant as RangedFireVariant
	if v == null:
		push_warning("RangedFireExecutor requires RangedFireVariant.")
		finish(false)
		return

	_attr_bus = CombatAttributeBus.new(context)
	_attr_bus.dispatch_attack_start()

	if variant.windup_time > 0.0:
		await get_tree().create_timer(variant.windup_time, true, true).timeout

	_fire(v)

	if variant.recovery_time > 0.0:
		await get_tree().create_timer(variant.recovery_time, true, true).timeout

	finish(true)


func _dispatch_attack_start() -> void:
	if _attr_bus != null:
		_attr_bus.dispatch_attack_start()


func _fire(v: RangedFireVariant) -> void:
	if context == null or context.owner == null:
		return
	if not (context.owner is Node2D):
		return

	var owner: Node2D = context.owner as Node2D
	var muzzle: Node2D = _resolve_muzzle(owner)

	var inst: ItemInstance = context.item_instance
	var stats: ItemStats = inst.compute_stats(context) if inst != null else null

	var projectile_count: int = 1
	var pierce: int = 0
	var damage: float = 1.0

	if stats != null:
		projectile_count = maxi(1, stats.projectile_count)
		pierce = maxi(0, stats.pierce)
		damage = float(stats.damage)

	var base_dir: Vector2 = context.aim_dir
	if base_dir.length() < 0.001:
		base_dir = Vector2.RIGHT
	base_dir = base_dir.normalized()

	for i: int in range(projectile_count):
		var shot: RangedShotData = _build_base_shot(v, muzzle, base_dir, i, projectile_count, damage, pierce, inst)
		_dispatch_modify_shot(shot, inst)
		_execute_shot(shot, inst)


func _build_base_shot(
	v: RangedFireVariant,
	muzzle: Node2D,
	base_dir: Vector2,
	index: int,
	count: int,
	damage: float,
	pierce: int,
	inst: ItemInstance
) -> RangedShotData:
	var shot: RangedShotData = RangedShotData.new()

	shot.mode = v.default_mode
	shot.origin = muzzle.global_position + v.muzzle_offset.rotated(muzzle.global_rotation)
	shot.direction = _compute_shot_dir(v, base_dir, index, count, inst)

	shot.damage = damage
	shot.pierce = pierce
	shot.shot_index = index
	shot.shot_count = count

	shot.projectile_scene = v.projectile_scene
	shot.speed = v.projectile_speed
	shot.gravity = v.projectile_gravity
	shot.lifetime_sec = v.projectile_lifetime_sec
	shot.inherit_owner_velocity = v.inherit_owner_velocity

	shot.range = v.hitscan_range
	if shot.mode == RangedShotData.ShotMode.BEAM:
		shot.range = v.beam_range

	shot.beam_duration_sec = v.beam_duration_sec
	shot.beam_tick_sec = v.beam_tick_sec

	if v.projectile_range > 0.0:
		shot.range = v.projectile_range

	return shot


func _dispatch_modify_shot(shot: RangedShotData, inst: ItemInstance) -> void:
	if inst == null:
		return
	if _attr_bus == null:
		_attr_bus = CombatAttributeBus.new(context)
	_attr_bus.dispatch_modify_ranged_shot(shot)


func _execute_shot(shot: RangedShotData, inst: ItemInstance) -> void:
	match shot.mode:
		RangedShotData.ShotMode.PROJECTILE:
			_fire_projectile(shot, inst)
		RangedShotData.ShotMode.HITSCAN:
			_fire_hitscan(shot, inst)
		RangedShotData.ShotMode.BEAM:
			_start_beam(shot, inst)


func _compute_shot_dir(v: RangedFireVariant, base_dir: Vector2, index: int, count: int, inst: ItemInstance) -> Vector2:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var seed_base: int = inst.seed if inst != null else 1337
	rng.seed = int((seed_base * 1103515245 + 12345 + index * 1013) & 0x7fffffff)

	if count > 1 and v.spread_pattern_degrees > 0.0:
		var half_arc: float = deg_to_rad(v.spread_pattern_degrees) * 0.5
		var t: float = 0.0 if count <= 1 else float(index) / float(count - 1)
		var ang: float = lerp(-half_arc, half_arc, t)
		return base_dir.rotated(ang).normalized()

	if v.spread_degrees <= 0.0:
		return base_dir

	var half: float = v.spread_degrees * 0.5
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

	var n: Node = shot.projectile_scene.instantiate()
	var p: Projectile = n as Projectile
	if p == null:
		push_warning("projectile_scene is not a Projectile.")
		if is_instance_valid(n):
			n.queue_free()
		return

	p.global_position = shot.origin

	var vel: Vector2 = shot.direction.normalized() * shot.speed
	if shot.inherit_owner_velocity > 0.0 and context.owner is CharacterBody2D:
		var ov: Vector2 = (context.owner as CharacterBody2D).velocity
		vel += ov * clampf(shot.inherit_owner_velocity, 0.0, 1.0)

	p.setup(vel, shot.gravity, shot.lifetime_sec, int(round(shot.damage)), shot.pierce, context.owner)

	if inst != null:
		if _attr_bus == null:
			_attr_bus = CombatAttributeBus.new(context)
		_attr_bus.dispatch_projectile_spawn(p)

	var owner: Node = context.owner
	if owner != null and owner.get_parent() != null:
		owner.get_parent().add_child(p)
	else:
		get_tree().current_scene.add_child(p)


func _fire_hitscan(shot: RangedShotData, inst: ItemInstance) -> void:
	var owner: Node2D = context.owner as Node2D
	var space: PhysicsDirectSpaceState2D = owner.get_world_2d().direct_space_state

	var to: Vector2 = shot.origin + shot.direction.normalized() * max(1.0, shot.range)
	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(shot.origin, to)
	q.exclude = [owner.get_rid()]
	q.collide_with_areas = true
	q.collide_with_bodies = true

	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		_debug_draw_transient_line(shot.origin, to, debug_hitscan_life_sec)
		return

	var hit_pos: Vector2 = hit.get("position", to) as Vector2
	_debug_draw_transient_line(shot.origin, hit_pos, debug_hitscan_life_sec)

	var collider_obj: Object = hit.get("collider")
	var collider_node: Node = collider_obj as Node
	if collider_node == null:
		return

	_apply_ranged_hit(collider_node, collider_node, shot.damage, shot.direction, inst)


func _start_beam(shot: RangedShotData, inst: ItemInstance) -> void:
	_kill_beam()

	var ticks: int = int(ceil(shot.beam_duration_sec / max(shot.beam_tick_sec, 0.01)))

	_beam_tween = (context.owner as Node).create_tween()
	_beam_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)

	for _i: int in range(ticks):
		_beam_tween.tween_callback(func() -> void:
			_beam_tick(shot, inst)
		)
		_beam_tween.tween_interval(shot.beam_tick_sec)

	_beam_tween.tween_callback(func() -> void:
		_kill_beam()
	)


func _beam_tick(base_shot: RangedShotData, inst: ItemInstance) -> void:
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
	dir = dir.normalized()

	var range_val: float = max(1.0, base_shot.range)

	var space: PhysicsDirectSpaceState2D = owner.get_world_2d().direct_space_state
	var to: Vector2 = origin + dir * range_val

	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origin, to)
	q.exclude = [owner.get_rid()]
	q.collide_with_areas = true
	q.collide_with_bodies = true

	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		_debug_set_beam_line(origin, to)
		return

	var hit_pos: Vector2 = hit.get("position", to) as Vector2
	_debug_set_beam_line(origin, hit_pos)

	var collider_obj: Object = hit.get("collider")
	var collider_node: Node = collider_obj as Node
	if collider_node == null:
		return

	_apply_ranged_hit(collider_node, collider_node, base_shot.damage, dir, inst)


func _apply_ranged_hit(victim_node: Node, collider_node: Node, base_damage: float, dir: Vector2, inst: ItemInstance) -> void:
	if victim_node == null:
		return
	if victim_node == context.owner:
		return

	var victim_root: Node = _resolve_victim_root(victim_node)
	if not _can_damage(victim_root):
		return

	var hp: Health = _find_health(victim_root)
	if hp == null:
		return

	var dmg: float = base_damage

	if inst != null:
		var hit: HitEvent = HitEvent.new()
		hit.attacker = context.owner
		hit.item_node = context.item
		hit.item_instance = inst
		hit.victim = victim_root
		hit.collider = collider_node
		hit.dir = dir
		hit.base_damage = dmg
		hit.damage = dmg

		if _attr_bus == null:
			_attr_bus = CombatAttributeBus.new(context)
		_attr_bus.dispatch_on_hit(hit)

		dmg = hit.damage

	hp.take_damage(dmg, context.owner)


func _kill_beam() -> void:
	if _beam_tween != null and is_instance_valid(_beam_tween):
		_beam_tween.kill()
	_beam_tween = null
	_debug_clear_beam_line(debug_beam_life_pad_sec)


# ---------------- Debug helpers ----------------

func _debug_make_line(parent: Node) -> Line2D:
	var line: Line2D = Line2D.new()
	line.width = debug_line_width
	line.z_index = 9999
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

	var owner: Node2D = context.owner as Node2D
	var parent: Node = owner.get_parent() if owner.get_parent() != null else get_tree().current_scene
	if parent == null:
		return

	var line: Line2D = _debug_make_line(parent)
	line.add_point(from)
	line.add_point(to)

	var tw: Tween = line.create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_interval(max(0.01, life_sec))
	tw.tween_callback(func() -> void:
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

	var tw: Tween = line.create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_interval(max(0.01, delay_sec))
	tw.tween_callback(func() -> void:
		if is_instance_valid(line):
			line.queue_free()
	)


# ---------------- Victim helpers ----------------

func _resolve_victim_root(n: Node) -> Node:
	var cur: Node = n
	for _i: int in range(6):
		if cur == null:
			break
		if cur is Entity:
			return cur
		if _find_health(cur) != null:
			return cur
		cur = cur.get_parent()
	return n


func _find_health(root: Node) -> Health:
	if root == null:
		return null
	if root is Entity:
		var h: Health = (root as Entity).find_component(&"Health") as Health
		if h != null:
			return h
	return root.get_node_or_null("Health") as Health


func _find_faction(root: Node) -> Faction:
	if root == null:
		return null
	if root is Entity:
		var f: Faction = (root as Entity).find_component(&"Faction") as Faction
		if f != null:
			return f
	return root.get_node_or_null("Faction") as Faction


func _can_damage(victim_root: Node) -> bool:
	var src_f: Faction = _find_faction(context.owner)
	if src_f == null:
		return true
	return src_f.can_damage(victim_root)

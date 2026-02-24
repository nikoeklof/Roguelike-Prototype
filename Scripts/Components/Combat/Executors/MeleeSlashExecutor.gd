extends AttackExecutor
class_name MeleeSlashExecutor

var _hit_ids: Dictionary = {}
var _hitbox: Area2D


func execute() -> void:
	var v := variant as MeleeSlashVariant
	if v == null:
		push_warning("MeleeSlashExecutor requires MeleeSlashVariant.")
		finish(false)
		return

	# ---- Hook: on_attack_start ----
	_dispatch_attack_start()

	# Optional windup (PHYSICS timer so capture FPS doesn't affect gameplay time)
	if v.windup_time > 0.0:
		await get_tree().create_timer(v.windup_time, true, true).timeout

	# Spawn hitbox
	_spawn_hitbox(v)

	# Keep active for a short window (PHYSICS timer)
	await get_tree().create_timer(max(v.active_time, 0.01), true, true).timeout

	# Cleanup hitbox
	if is_instance_valid(_hitbox):
		_hitbox.queue_free()
	_hitbox = null

	# Optional recovery (PHYSICS timer)
	if v.recovery_time > 0.0:
		await get_tree().create_timer(v.recovery_time, true, true).timeout

	finish(true)


func _dispatch_attack_start() -> void:
	if context == null:
		return
	var inst := context.item_instance
	if inst == null:
		return
	for a in inst.attributes:
		if a == null:
			continue
		a.on_attack_start(context, inst)


func _spawn_hitbox(v: MeleeSlashVariant) -> void:
	if context == null or context.owner == null:
		finish(false)
		return

	_hit_ids.clear()
	_hitbox = Area2D.new()
	_hitbox.name = "MeleeHitbox"
	_hitbox.monitoring = true
	_hitbox.monitorable = false

	# IMPORTANT: avoid inheriting any parent transforms (prevents drift if owner is scaled/offset).
	_hitbox.top_level = true

	# Detect everything by default
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 0x7FFFFFFF

	# --- Use existing facing/aim tree as origin ---
	var origin_node := _resolve_attack_origin(context.owner)
	var origin_pos := Vector2.ZERO
	var origin_rot := 0.0

	if origin_node != null:
		origin_pos = origin_node.global_position
		origin_rot = origin_node.global_rotation
	elif context.owner is Node2D:
		origin_pos = (context.owner as Node2D).global_position

		# Fall back to context aim if no aim nodes exist
		var aim := context.aim_dir
		if aim.length() < 0.001:
			aim = Vector2.RIGHT
		origin_rot = aim.normalized().angle()

	_hitbox.global_position = origin_pos
	_hitbox.global_rotation = origin_rot

	# Shape
	var shape := RectangleShape2D.new()
	shape.size = v.size

	var cs := CollisionShape2D.new()
	cs.shape = shape

	# Offset in LOCAL hitbox space; +X is forward (AimRay/WeaponSocket convention)
	cs.position = v.offset
	_hitbox.add_child(cs)

	_hitbox.body_entered.connect(func(body: Node) -> void:
		_try_damage(body, v)
	)
	_hitbox.area_entered.connect(func(area: Area2D) -> void:
		_try_damage(area, v)
	)

	# As top_level, parenting doesn't affect its transform.
	context.owner.add_child(_hitbox)


func _resolve_attack_origin(owner: Node) -> Node2D:
	# Prefer WeaponSocket if present (your tree: FacingPointer/AimRay/WeaponSocket)
	var ws := owner.get_node_or_null("FacingPointer/AimRay/WeaponSocket") as Node2D
	if ws != null:
		return ws

	# Next best: AimRay itself (RayCast2D is Node2D)
	var ar := owner.get_node_or_null("FacingPointer/AimRay") as Node2D
	if ar != null:
		return ar

	# Fallback: any Node2D named WeaponSocket somewhere under the owner (robust)
	var found := _find_node2d_named(owner, &"WeaponSocket")
	if found != null:
		return found

	return null


func _find_node2d_named(root: Node, target_name: StringName) -> Node2D:
	for c in root.get_children():
		if c is Node2D and (c as Node2D).name == String(target_name):
			return c as Node2D
		var deeper := _find_node2d_named(c, target_name)
		if deeper != null:
			return deeper
	return null


func _try_damage(other: Node, v: MeleeSlashVariant) -> void:
	if other == null:
		return
	if context == null or context.owner == null:
		return

	# Don't hit self or own children
	if other == context.owner or context.owner.is_ancestor_of(other):
		return

	# Resolve victim "root" that likely owns Health/Faction
	var victim_root := _resolve_victim_root(other)

	# Prevent multi-hit spam (optional)
	if v.one_hit_per_target:
		var id := victim_root.get_instance_id()
		if _hit_ids.has(id):
			return
		_hit_ids[id] = true

	# Faction filtering
	if not _can_damage(victim_root):
		return

	# Find Health
	var hp := _find_health(victim_root)
	if hp == null:
		return

	# Damage calc
	var dmg := v.base_damage
	if context.stats != null and context.stats.has_method("melee_damage_mult"):
		dmg *= float(context.stats.call("melee_damage_mult"))

	# ---- Hook: on_hit (can modify damage) ----
	dmg = _dispatch_on_hit(victim_root, other, dmg)

	# Apply
	hp.take_damage(dmg, context.owner)

	# Optional knockback (only if victim is CharacterBody2D)
	if v.knockback > 0.0 and victim_root is CharacterBody2D:
		var cb := victim_root as CharacterBody2D
		var dir := Vector2.RIGHT
		# Prefer the hitbox rotation (matches AimRay/WeaponSocket) to avoid aim mismatch.
		if is_instance_valid(_hitbox):
			dir = Vector2.RIGHT.rotated(_hitbox.global_rotation)
		elif context.aim_dir.length() >= 0.001:
			dir = context.aim_dir.normalized()
		elif context.owner is Node2D:
			dir = (cb.global_position - (context.owner as Node2D).global_position).normalized()
		cb.velocity += dir * v.knockback


func _dispatch_on_hit(victim_root: Node, collider: Node, base_damage: float) -> float:
	var dmg := base_damage
	if context == null:
		return dmg
	var inst := context.item_instance
	if inst == null:
		return dmg

	var hit := HitEvent.new()
	hit.attacker = context.owner
	hit.item_node = context.item
	hit.item_instance = inst
	hit.victim = victim_root
	hit.collider = collider
	hit.dir = context.aim_dir
	hit.base_damage = base_damage
	hit.damage = base_damage

	for a in inst.attributes:
		if a == null:
			continue
		a.on_hit(context, hit, inst)

	return hit.damage


func _resolve_victim_root(n: Node) -> Node:
	var cur := n
	for _i in 6:
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
	var src_f := _find_faction(context.owner)
	if src_f == null:
		return true
	return src_f.can_damage(victim_root)

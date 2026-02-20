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

	# Optional windup
	if v.windup_time > 0.0:
		await get_tree().create_timer(v.windup_time).timeout

	# Spawn hitbox
	_spawn_hitbox(v)

	# Keep active for a short window
	await get_tree().create_timer(max(v.active_time, 0.01)).timeout

	# Cleanup hitbox
	if is_instance_valid(_hitbox):
		_hitbox.queue_free()
	_hitbox = null

	# Optional recovery
	if v.recovery_time > 0.0:
		await get_tree().create_timer(v.recovery_time).timeout

	finish(true)


func _spawn_hitbox(v: MeleeSlashVariant) -> void:
	if context == null or context.owner == null:
		finish(false)
		return
	_hit_ids.clear()
	_hitbox = Area2D.new()
	_hitbox.name = "MeleeHitbox"
	_hitbox.monitoring = true
	_hitbox.monitorable = false
	# Detect everything by default (simple / robust for now)
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 0x7FFFFFFF
	# Place relative to owner, rotated along aim dir
	var aim := context.aim_dir
	if aim.length() < 0.001:
		aim = Vector2.RIGHT
	aim = aim.normalized()
	_hitbox.global_position = context.owner.global_position
	_hitbox.global_rotation = aim.angle()
	# Shape
	var shape := RectangleShape2D.new()
	shape.size = v.size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = v.offset
	_hitbox.add_child(cs)
	# Connect
	_hitbox.body_entered.connect(func(body: Node) -> void:
		_try_damage(body, v)
	)
	_hitbox.area_entered.connect(func(area: Area2D) -> void:
		_try_damage(area, v)
	)
	context.owner.add_child(_hitbox)


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
	# Apply
	hp.take_damage(dmg, context.owner)
	# Optional knockback (only if victim is CharacterBody2D)
	if v.knockback > 0.0 and victim_root is CharacterBody2D:
		var cb := victim_root as CharacterBody2D
		var dir := context.aim_dir
		if dir.length() < 0.001:
			dir = (cb.global_position - context.owner.global_position).normalized()
		else:
			dir = dir.normalized()
		cb.velocity += dir * v.knockback


func _resolve_victim_root(n: Node) -> Node:
	# If you hit a child Area2D, climb up to something meaningful.
	var cur := n
	for i in 6:
		if cur == null:
			break
		# Prefer Entity root if present
		if cur is Entity:
			return cur
		# If it has Health, it is good enough
		if _find_health(cur) != null:
			return cur
		cur = cur.get_parent()
	return n


func _find_health(root: Node) -> Health:
	if root == null:
		return null
	if root is Entity:
		var h := (root as Entity).find_component(&"Health") as Health
		if h != null:
			return h
	# Common child name fallback
	return root.get_node_or_null("Health") as Health


func _find_faction(root: Node) -> Faction:
	if root == null:
		return null
	if root is Entity:
		var f := (root as Entity).find_component(&"Faction") as Faction
		if f != null:
			return f
	return root.get_node_or_null("Faction") as Faction


func _can_damage(victim_root: Node) -> bool:
	var src_f := _find_faction(context.owner)
	var dst_f := _find_faction(victim_root)

	# If we can't resolve faction, allow damage (keeps things robust early)
	if src_f == null or dst_f == null:
		return true

	# Friendly fire enabled on source? then allow.
	if src_f.friendly_fire:
		return true

	# Block same-faction hits
	return src_f.faction != dst_f.faction

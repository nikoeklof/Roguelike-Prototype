extends AttackExecutor
class_name MeleeSlashExecutor

var _hit_ids: Dictionary = {}
var _hitbox: Area2D
var _origin_node: Node2D
var _fallback_owner_2d: Node2D


func execute() -> void:
	var v: MeleeSlashVariant = variant as MeleeSlashVariant
	if v == null:
		push_warning("MeleeSlashExecutor requires MeleeSlashVariant.")
		finish(false)
		return

	var inst: ItemInstance = context.item_instance
	var stats: ItemStats = inst.compute_stats(context) if inst != null else null

	_dispatch_attack_start()

	var windup: float = stats.windup_time if stats != null else 0.0
	var active_time: float = stats.active_time if stats != null else 0.10
	var recovery: float = stats.recovery_time if stats != null else 0.10

	if windup > 0.0:
		await get_tree().create_timer(windup, true, true).timeout

	_spawn_hitbox(v)

	await get_tree().create_timer(max(active_time, 0.01), true, true).timeout

	# Cleanup
	set_physics_process(false)
	_origin_node = null
	_fallback_owner_2d = null
	if is_instance_valid(_hitbox):
		_hitbox.queue_free()
	_hitbox = null

	if recovery > 0.0:
		await get_tree().create_timer(recovery, true, true).timeout

	finish(true)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_hitbox):
		set_physics_process(false)
		return
	_update_hitbox_transform()


func _dispatch_attack_start() -> void:
	if context == null:
		return
	var inst: ItemInstance = context.item_instance
	if inst == null:
		return
	ItemAttributeBus.dispatch_attack_start(context, inst)


func _spawn_hitbox(v: MeleeSlashVariant) -> void:
	if context == null or context.owner == null:
		finish(false)
		return

	_hit_ids.clear()
	_hitbox = Area2D.new()
	_hitbox.name = "MeleeHitbox"
	_hitbox.monitoring = true
	_hitbox.monitorable = false
	_hitbox.top_level = true

	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 0x7FFFFFFF

	_origin_node = _resolve_attack_origin(context.owner)
	_fallback_owner_2d = context.owner as Node2D if context.owner is Node2D else null
	_update_hitbox_transform()

	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = v.size

	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.shape = shape
	cs.position = v.offset
	_hitbox.add_child(cs)

	_hitbox.body_entered.connect(func(body: Node) -> void:
		_try_damage(body, v)
	)
	_hitbox.area_entered.connect(func(area: Area2D) -> void:
		_try_damage(area, v)
	)

	context.owner.add_child(_hitbox)
	set_physics_process(true)


func _update_hitbox_transform() -> void:
	if not is_instance_valid(_hitbox):
		return

	if is_instance_valid(_origin_node):
		_hitbox.global_position = _origin_node.global_position
		_hitbox.global_rotation = _origin_node.global_rotation
		return

	if _fallback_owner_2d != null and is_instance_valid(_fallback_owner_2d):
		_hitbox.global_position = _fallback_owner_2d.global_position

		var aim: Vector2 = context.aim_dir if context != null else Vector2.RIGHT
		if aim.length() < 0.001:
			aim = Vector2.RIGHT
		_hitbox.global_rotation = aim.normalized().angle()


func _resolve_attack_origin(owner: Node) -> Node2D:
	var ws: Node2D = owner.get_node_or_null("FacingPointer/AimRay/WeaponSocket") as Node2D
	if ws != null:
		return ws
	var ar: Node2D = owner.get_node_or_null("FacingPointer/AimRay") as Node2D
	if ar != null:
		return ar
	return null


func _try_damage(other: Node, v: MeleeSlashVariant) -> void:
	if other == null:
		return
	if context == null or context.owner == null:
		return
	if other == context.owner or context.owner.is_ancestor_of(other):
		return

	var victim_root: Node = _resolve_victim_root(other)

	if v.one_hit_per_target:
		var id: int = victim_root.get_instance_id()
		if _hit_ids.has(id):
			return
		_hit_ids[id] = true

	if not _can_damage(victim_root):
		return

	var hp: Health = _find_health(victim_root)
	if hp == null:
		return

	var inst: ItemInstance = context.item_instance
	var stats: ItemStats = inst.compute_stats(context) if inst != null else null

	var dmg: float = 1.0
	var knockback: float = 0.0
	if stats != null:
		dmg = float(stats.damage)
		knockback = float(stats.knockback)

	# Hook: on_hit
	dmg = _dispatch_on_hit(victim_root, other, dmg)

	hp.take_damage(dmg, context.owner)

	# Knockback
	if knockback > 0.0 and victim_root is CharacterBody2D:
		var cb: CharacterBody2D = victim_root as CharacterBody2D
		var dir: Vector2 = Vector2.RIGHT.rotated(_hitbox.global_rotation) if is_instance_valid(_hitbox) else context.aim_dir.normalized()
		cb.velocity += dir * knockback


func _dispatch_on_hit(victim_root: Node, collider: Node, base_damage: float) -> float:
	var dmg: float = base_damage
	if context == null:
		return dmg
	var inst: ItemInstance = context.item_instance
	if inst == null:
		return dmg

	var hit: HitEvent = HitEvent.new()
	hit.attacker = context.owner
	hit.item_node = context.item
	hit.item_instance = inst
	hit.victim = victim_root
	hit.collider = collider
	hit.dir = context.aim_dir
	hit.base_damage = base_damage
	hit.damage = base_damage

	ItemAttributeBus.dispatch_hit(context, hit, inst)

	return hit.damage


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

extends AttackExecutor
class_name MeleeSlashExecutor

var _hit_ids: Dictionary[int, bool] = {}
var _hitbox: Area2D = null
var _origin_node: Node2D = null
var _fallback_owner_2d: Node2D = null


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


func _physics_process(_delta: float) -> void:
	if _hitbox == null or not is_instance_valid(_hitbox):
		set_physics_process(false)
		return

	_update_hitbox_transform()


func _spawn_hitbox(melee: MeleeSlashVariant, snap: AttackSnapshot) -> void:
	if context == null or context.owner == null:
		finish(false)
		return

	_hit_ids.clear()

	_hitbox = Area2D.new()
	_hitbox.name = "MeleeHitbox"
	_hitbox.monitoring = true
	_hitbox.monitorable = false
	_hitbox.top_level = true

	# Safer than layer 0 for broad overlap behavior.
	_hitbox.collision_layer = 1
	_hitbox.collision_mask = 0x7FFFFFFF

	_origin_node = _resolve_attack_origin(context.owner)
	_fallback_owner_2d = context.owner as Node2D if context.owner is Node2D else null

	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = snap.hitbox_size

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = shape
	collision_shape.position = snap.hitbox_offset
	_hitbox.add_child(collision_shape)

	_hitbox.body_entered.connect(func(body: Node) -> void:
		_try_hit(body, melee.one_hit_per_target)
	)

	_hitbox.area_entered.connect(func(area: Area2D) -> void:
		_try_hit(area, melee.one_hit_per_target)
	)

	context.owner.add_child(_hitbox)
	_update_hitbox_transform()
	set_physics_process(true)


func _update_hitbox_transform() -> void:
	if _hitbox == null or not is_instance_valid(_hitbox):
		return

	if _origin_node != null and is_instance_valid(_origin_node):
		_hitbox.global_position = _origin_node.global_position
		_hitbox.global_rotation = _origin_node.global_rotation
		return

	if _fallback_owner_2d != null and is_instance_valid(_fallback_owner_2d):
		_hitbox.global_position = _fallback_owner_2d.global_position

		var aim: Vector2 = Vector2.RIGHT
		if context != null:
			aim = context.aim_dir

		if aim.length() < 0.001:
			aim = Vector2.RIGHT
		else:
			aim = aim.normalized()

		_hitbox.global_rotation = aim.angle()


func _resolve_attack_origin(owner: Node) -> Node2D:
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


func _try_hit(other: Node, one_hit_per_target: bool) -> void:
	if context == null or context.owner == null:
		return
	if other == null:
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

	var aim_dir: Vector2 = context.aim_dir
	if aim_dir.length() < 0.001:
		aim_dir = Vector2.RIGHT
	else:
		aim_dir = aim_dir.normalized()

	AttackImpactResolver.apply_hit(context, resolve_snapshot(), victim_root, other, aim_dir)


func _cleanup_hitbox() -> void:
	set_physics_process(false)
	_origin_node = null
	_fallback_owner_2d = null

	if _hitbox != null and is_instance_valid(_hitbox):
		_hitbox.queue_free()

	_hitbox = null


func _exit_tree() -> void:
	_cleanup_hitbox()

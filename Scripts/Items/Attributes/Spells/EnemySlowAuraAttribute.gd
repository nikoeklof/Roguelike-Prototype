extends ItemAttribute
class_name EnemySlowAuraAttribute

@export_range(1.0, 600.0, 1.0) var radius: float = 120.0
@export_range(0.1, 0.99, 0.01) var slow_mult: float = 0.70
@export_range(0.1, 20.0, 0.1) var duration_sec: float = 4.0

func default_domains() -> PackedStringArray:
	return PackedStringArray(["cast"])


func on_cast_apply(context: CombatContext, item_instance: ItemInstance) -> void:
	if context == null or context.owner == null:
		return
	if not (context.owner is Node2D):
		return

	var owner2d := context.owner as Node2D
	var origin: Vector2 = owner2d.global_position

	var world := owner2d.get_world_2d()
	if world == null:
		return

	var space: PhysicsDirectSpaceState2D = world.direct_space_state
	if space == null:
		return

	var shape := CircleShape2D.new()
	shape.radius = radius

	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, origin)
	q.collide_with_areas = false
	q.collide_with_bodies = true

	var hits: Array[Dictionary] = space.intersect_shape(q, 32)
	if hits.is_empty():
		return

	for h: Dictionary in hits:
		var c: Variant = h.get("collider")
		if not (c is Node):
			continue
		var n: Node = c as Node
		if n == context.owner:
			continue

		# Only affect hostiles (best-effort)
		if context.faction != null and context.faction is Faction:
			var f := context.faction as Faction
			# If your Faction doesn't implement is_hostile_to, skip this check safely
			if f.has_method(&"is_hostile_to"):
				if not bool(f.call(&"is_hostile_to", n)):
					continue

		var target_stats := _find_stats(n)
		if target_stats == null:
			continue

		var key := _make_key(item_instance, n, "slow")
		target_stats.set_move_speed_mult(key, slow_mult)

		_start_clear_timer(n, duration_sec, func() -> void:
			if is_instance_valid(target_stats):
				target_stats.clear_move_speed_mult(key)
		)


func _find_stats(root: Node) -> Stats:
	if root is Entity:
		return (root as Entity).find_component(&"Stats") as Stats
	return root.get_node_or_null("Stats") as Stats


func _make_key(item_instance: ItemInstance, target: Node, suffix: String) -> StringName:
	var seed := 0
	if item_instance != null:
		seed = item_instance.seed
	return StringName("spell_%s_%d_%d" % [suffix, seed, target.get_instance_id()])


func _start_clear_timer(host: Node, sec: float, cb: Callable) -> void:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = maxf(0.01, sec)
	host.add_child(t)
	t.timeout.connect(func() -> void:
		cb.call()
		t.queue_free()
	)
	t.start()

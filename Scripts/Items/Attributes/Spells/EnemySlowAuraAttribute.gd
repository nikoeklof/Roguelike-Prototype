extends ItemAttribute
class_name EnemySlowAuraAttribute

# Shares stat key and timer meta with SlowDebuff — same effect type, one slot per target.
const STAT_KEY: StringName = &"debuff_slow"
const TIMER_META: StringName = &"_debuff_slow_tmr"

@export_range(1.0, 600.0, 1.0) var radius: float = 120.0
@export_range(0.1, 0.99, 0.01) var slow_mult: float = 0.70
@export_range(0.1, 20.0, 0.1) var duration_sec: float = 4.0


func default_domains() -> PackedStringArray:
	return PackedStringArray(["cast"])


func on_cast_apply(context: CombatContext, _item_instance: ItemInstance) -> void:
	if context == null or context.owner == null:
		return
	if not (context.owner is Node2D):
		return

	var caster_faction: Faction = _find_faction(context.owner)
	if caster_faction == null:
		return

	var owner2d: Node2D = context.owner as Node2D
	var space: PhysicsDirectSpaceState2D = owner2d.get_world_2d().direct_space_state
	if space == null:
		return

	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius

	var q: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, owner2d.global_position)
	q.collide_with_areas = false
	q.collide_with_bodies = true

	var hits: Array[Dictionary] = space.intersect_shape(q, 32)
	if hits.is_empty():
		return

	var processed: Dictionary = {}
	for h: Dictionary in hits:
		var c: Variant = h.get("collider")
		if not (c is Node):
			continue
		var n: Node = c as Node
		if n == context.owner:
			continue
		if not caster_faction.is_hostile_to(n):
			continue

		# Walk to Entity root to avoid double-processing multiple colliders on one entity.
		var root: Node = _resolve_entity_root(n)
		if root == null or processed.has(root):
			continue
		processed[root] = true

		var target_stats: Stats = _find_stats(root)
		if target_stats == null:
			continue

		target_stats.set_move_speed_mult(STAT_KEY, slow_mult)
		_refresh_timer(root, duration_sec, target_stats)


func _refresh_timer(host: Node, sec: float, stats: Stats) -> void:
	if host.has_meta(TIMER_META):
		var old: Timer = host.get_meta(TIMER_META) as Timer
		if is_instance_valid(old):
			old.queue_free()
		host.remove_meta(TIMER_META)

	var t: Timer = Timer.new()
	t.one_shot = true
	t.wait_time = maxf(0.01, sec)
	host.add_child(t)
	host.set_meta(TIMER_META, t)
	t.timeout.connect(func() -> void:
		if is_instance_valid(stats):
			stats.clear_move_speed_mult(STAT_KEY)
		if is_instance_valid(host) and host.has_meta(TIMER_META):
			host.remove_meta(TIMER_META)
		if is_instance_valid(t):
			t.queue_free()
	, CONNECT_ONE_SHOT)
	t.start()


func _resolve_entity_root(n: Node) -> Node:
	var cur: Node = n
	while cur != null:
		if cur is Entity:
			return cur
		cur = cur.get_parent()
	return n


func _find_stats(root: Node) -> Stats:
	if root is Entity:
		return (root as Entity).find_component(&"Stats") as Stats
	return root.get_node_or_null("Stats") as Stats


func _find_faction(root: Node) -> Faction:
	if root is Entity:
		return (root as Entity).find_component(&"Faction") as Faction
	return root.get_node_or_null("Faction") as Faction

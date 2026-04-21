extends SpellEffect
class_name EnemySlowAuraEffect

const STAT_KEY:   StringName = &"debuff_slow"
const TIMER_META: StringName = &"_debuff_slow_tmr"

@export_range(1.0, 600.0, 1.0)  var radius: float = 120.0
@export_range(0.1, 0.99, 0.01)  var slow_mult: float = 0.70
@export_range(0.1, 20.0, 0.1)   var duration_sec: float = 4.0


func apply_buff(caster: Node, _context: CombatContext, _instance: ItemInstance) -> void:
	if not (caster is Node2D):
		return

	var caster_faction: Faction = _find_faction(caster)
	if caster_faction == null:
		return

	var caster2d: Node2D = caster as Node2D
	var space: PhysicsDirectSpaceState2D = caster2d.get_world_2d().direct_space_state
	if space == null:
		return

	var potency: float     = _get_effect_potency(_instance)
	var actual_mult: float = clampf(_scale_mult_stat(slow_mult, potency), 0.05, 1.0)
	var actual_dur: float  = _get_effect_duration(duration_sec, _instance)

	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius

	var q: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, caster2d.global_position)
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
		if n == caster:
			continue
		if not caster_faction.is_hostile_to(n):
			continue

		var root: Node = _resolve_entity_root(n)
		if root == null or processed.has(root):
			continue
		processed[root] = true

		var target_stats: Stats = _find_stats(root)
		if target_stats == null:
			continue

		target_stats.set_move_speed_mult(STAT_KEY, actual_mult)
		_refresh_timer(root, TIMER_META, actual_dur, func() -> void:
			if is_instance_valid(target_stats):
				target_stats.clear_move_speed_mult(STAT_KEY)
		)


func _resolve_entity_root(n: Node) -> Node:
	var cur: Node = n
	while cur != null:
		if cur is Entity:
			return cur
		cur = cur.get_parent()
	return n

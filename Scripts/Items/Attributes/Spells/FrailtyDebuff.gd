extends DebuffSpellAttribute
class_name FrailtyDebuff

const STAT_KEY: StringName = &"debuff_frailty"
const TIMER_META: StringName = &"_debuff_frailty_tmr"

@export_range(1.01, 3.0, 0.01) var damage_taken_mult: float = 1.4
@export_range(0.1, 20.0, 0.1) var duration_sec: float = 4.0


func on_hit(_context: CombatContext, hit: HitEvent, _item_instance: ItemInstance) -> void:
	if hit == null or hit.victim == null:
		return

	var stats: Stats = _find_stats(hit.victim)
	if stats == null:
		return

	stats.set_damage_taken_mult(STAT_KEY, damage_taken_mult)
	_set_visual_effect(hit.victim, 1.0)
	_refresh_timer(hit.victim, duration_sec, stats)


func _refresh_timer(host: Node, sec: float, stats: Stats) -> void:
	# Cancel the previous timer for this debuff type so duration resets instead of stacking.
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
			stats.clear_damage_taken_mult(STAT_KEY)
		_set_visual_effect(host, 0.0)
		if is_instance_valid(host) and host.has_meta(TIMER_META):
			host.remove_meta(TIMER_META)
		if is_instance_valid(t):
			t.queue_free()
	, CONNECT_ONE_SHOT)
	t.start()


func _set_visual_effect(target: Node, amount: float) -> void:
	if target == null:
		return
	var vc: EntityVisualController = null
	if target is Entity:
		vc = (target as Entity).find_component(&"EntityVisualController") as EntityVisualController
	else:
		vc = target.get_node_or_null("EntityVisualController") as EntityVisualController
	if vc == null:
		return
	vc.set_debuff_intensity(amount)
	vc.set_poison_amount(amount)


func _find_stats(root: Node) -> Stats:
	if root is Entity:
		return (root as Entity).find_component(&"Stats") as Stats
	return root.get_node_or_null("Stats") as Stats

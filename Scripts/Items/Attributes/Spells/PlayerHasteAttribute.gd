extends ItemAttribute
class_name PlayerHasteAttribute

const STAT_KEY: StringName = &"buff_haste"
const TIMER_META: StringName = &"_buff_haste_tmr"

@export_range(1.01, 3.0, 0.01) var move_speed_mult: float = 1.25
@export_range(0.1, 20.0, 0.1) var duration_sec: float = 4.0


func default_domains() -> PackedStringArray:
	return PackedStringArray(["cast"])


func on_cast_apply(context: CombatContext, _item_instance: ItemInstance) -> void:
	if context == null or context.owner == null:
		return

	var stats: Stats = _find_stats(context.owner)
	if stats == null:
		return

	stats.set_move_speed_mult(STAT_KEY, move_speed_mult)
	_refresh_timer(context.owner, duration_sec, stats)


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


func _find_stats(root: Node) -> Stats:
	if root is Entity:
		return (root as Entity).find_component(&"Stats") as Stats
	return root.get_node_or_null("Stats") as Stats

extends DebuffSpellAttribute
class_name SlowDebuff

@export_range(0.1, 0.9, 0.05) var move_speed_mult: float = 0.5
@export_range(0.1, 20.0, 0.1) var duration_sec: float = 3.0

func on_hit(context: CombatContext, hit: HitEvent, item_instance: ItemInstance) -> void:
	if hit == null or hit.victim == null:
		return

	var stats: Stats = _find_stats(hit.victim)
	if stats == null:
		return

	var key: StringName = _make_key(item_instance, "slow")
	stats.set_move_speed_mult(key, move_speed_mult)

	_start_clear_timer(hit.victim, duration_sec, stats, key)


func _find_stats(root: Node) -> Stats:
	if root is Entity:
		return (root as Entity).find_component(&"Stats") as Stats
	return root.get_node_or_null("Stats") as Stats


func _make_key(item_instance: ItemInstance, suffix: String) -> StringName:
	var seed: int = 0
	if item_instance != null:
		seed = item_instance.seed
	return StringName("spell_%s_%d" % [suffix, seed])


func _start_clear_timer(host: Node, sec: float, stats: Stats, key: StringName) -> void:
	var t: Timer = Timer.new()
	t.one_shot = true
	t.wait_time = maxf(0.01, sec)
	host.add_child(t)
	t.timeout.connect(Callable(self, "_clear_slow_and_free_timer").bind(stats, key, t), CONNECT_ONE_SHOT)
	t.start()


func _clear_slow_and_free_timer(stats: Stats, key: StringName, timer: Timer) -> void:
	if is_instance_valid(stats):
		stats.clear_move_speed_mult(key)

	if is_instance_valid(timer):
		timer.queue_free()

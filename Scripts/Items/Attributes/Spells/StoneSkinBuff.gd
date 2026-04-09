extends ItemAttribute
class_name StoneSkinBuff

@export_range(0.1, 50.0, 0.5) var flat_damage_reduction: float = 3.0
@export_range(0.5, 1.0, 0.01) var move_speed_mult: float = 0.7
@export_range(0.1, 20.0, 0.1) var duration_sec: float = 6.0


func default_domains() -> PackedStringArray:
	return PackedStringArray([&"cast"])


func on_cast_apply(context: CombatContext, item_instance: ItemInstance) -> void:
	if context == null or context.owner == null:
		return

	var stats: Stats = _find_stats(context.owner)
	if stats == null:
		return

	var key_reduction: StringName = _make_key(item_instance, "stone_skin_reduction")
	var key_speed: StringName = _make_key(item_instance, "stone_skin_speed")
	
	stats.set_flat_damage_reduction(key_reduction, flat_damage_reduction)
	stats.set_move_speed_mult(key_speed, move_speed_mult)

	_start_clear_timer(context.owner, duration_sec, stats, key_reduction, key_speed)


func _find_stats(root: Node) -> Stats:
	if root is Entity:
		return (root as Entity).find_component(&"Stats") as Stats
	return root.get_node_or_null("Stats") as Stats


func _make_key(item_instance: ItemInstance, suffix: String) -> StringName:
	var item_seed: int = 0
	if item_instance != null:
		item_seed = item_instance.seed
	return StringName("spell_%s_%d" % [suffix, item_seed])


func _start_clear_timer(host: Node, sec: float, stats: Stats, key_reduction: StringName, key_speed: StringName) -> void:
	var t: Timer = Timer.new()
	t.one_shot = true
	t.wait_time = maxf(0.01, sec)
	host.add_child(t)
	t.timeout.connect(Callable(self, "_clear_buffs_and_free_timer").bind(stats, key_reduction, key_speed, t), CONNECT_ONE_SHOT)
	t.start()


func _clear_buffs_and_free_timer(stats: Stats, key_reduction: StringName, key_speed: StringName, timer: Timer) -> void:
	if is_instance_valid(stats):
		stats.clear_flat_damage_reduction(key_reduction)
		stats.clear_move_speed_mult(key_speed)
	if is_instance_valid(timer):
		timer.queue_free()

extends ItemAttribute
class_name BattleTranceBuff

@export_range(1.01, 3.0, 0.01) var attack_speed_mult: float = 1.3
@export_range(1.01, 3.0, 0.01) var move_speed_mult: float = 1.25
@export_range(1.01, 3.0, 0.01) var accel_mult: float = 1.25
@export_range(0.1, 20.0, 0.1) var duration_sec: float = 5.0


func default_domains() -> PackedStringArray:
	return PackedStringArray([&"cast"])


func on_cast_apply(context: CombatContext, item_instance: ItemInstance) -> void:
	if context == null or context.owner == null:
		return

	var stats: Stats = _find_stats(context.owner)
	if stats == null:
		return
	
	var key_speed: StringName = _make_key(item_instance, "battle_trance_speed")
	var key_attack: StringName = _make_key(item_instance, "battle_trance_attack")
	var key_accel: StringName = _make_key(item_instance, "battle_trance_accel")
	
	stats.set_move_speed_mult(key_speed, move_speed_mult)
	stats.set_accel_mult(key_accel, accel_mult)
	stats.set_attack_speed_mult(key_attack, attack_speed_mult)
	
	_start_clear_timer(context.owner, duration_sec, stats, [key_speed, key_attack, key_accel])


func _find_stats(root: Node) -> Stats:
	if root == null:
		return null
	if root is Entity:
		return (root as Entity).find_component(&"Stats") as Stats
	return root.get_node_or_null("Stats") as Stats


func _make_key(item_instance: ItemInstance, suffix: String) -> StringName:
	var item_seed: int = 0
	if item_instance != null:
		item_seed = item_instance.seed
	return StringName("spell_%s_%d" % [suffix, item_seed])


func _start_clear_timer(host: Node, sec: float, stats: Stats, keys: Array) -> void:
	var t: Timer = Timer.new()
	t.one_shot = true
	t.wait_time = maxf(0.01, sec)
	host.add_child(t)
	t.timeout.connect(Callable(self, "_clear_buffs_and_free_timer").bind(stats, keys, t), CONNECT_ONE_SHOT)
	t.start()


func _clear_buffs_and_free_timer(stats: Stats, keys: Array, timer: Timer) -> void:
	if is_instance_valid(stats):
		for key: StringName in keys:
			stats.clear_move_speed_mult(key)
			stats.clear_accel_mult(key)
			stats.clear_attack_speed_mult(key)
	if is_instance_valid(timer):
		timer.queue_free()

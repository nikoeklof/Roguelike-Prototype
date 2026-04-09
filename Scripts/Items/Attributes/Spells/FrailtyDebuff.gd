extends DebuffSpellAttribute
class_name FrailtyDebuff

@export_range(1.01, 3.0, 0.01) var damage_taken_mult: float = 1.4
@export_range(0.1, 20.0, 0.1) var duration_sec: float = 4.0

func on_hit(_context: CombatContext, hit: HitEvent, item_instance: ItemInstance) -> void:
	if hit == null or hit.victim == null:
		return

	var stats: Stats = _find_stats(hit.victim)
	if stats == null:
		return

	var key: StringName = _make_key(item_instance, "frailty")
	stats.set_damage_taken_mult(key, damage_taken_mult)
	
	# UPDATE SHADER VISUAL
	_set_visual_effect(hit.victim, 1.0)

	_start_clear_timer(hit.victim, duration_sec, stats, key)


func _start_clear_timer(host: Node, sec: float, stats: Stats, key: StringName) -> void:
	var t: Timer = Timer.new()
	t.one_shot = true
	t.wait_time = maxf(0.01, sec)
	host.add_child(t)
	t.timeout.connect(Callable(self, "_clear_frailty_and_free_timer").bind(stats, key, t, host), CONNECT_ONE_SHOT)
	t.start()


func _clear_frailty_and_free_timer(stats: Stats, key: StringName, timer: Timer, host: Node) -> void:
	if is_instance_valid(stats):
		stats.clear_damage_taken_mult(key)
	
	# CLEAR SHADER VISUAL
	_set_visual_effect(host, 0.0)

	if is_instance_valid(timer):
		timer.queue_free()


func _set_visual_effect(target: Node, amount: float) -> void:
	"""Set the shader visual effect for this debuff"""
	if target == null:
		return
	
	# Get the EntityVisualController component
	var visual_controller: EntityVisualController = null
	if target is Entity:
		visual_controller = (target as Entity).find_component(&"EntityVisualController") as EntityVisualController
	else:
		visual_controller = target.get_node_or_null("EntityVisualController") as EntityVisualController
	
	if visual_controller == null:
		return
	
	# Set debuff intensity (enables the effect) and poison amount
	visual_controller.set_debuff_intensity(amount)
	visual_controller.set_poison_amount(amount)


func _find_stats(root: Node) -> Stats:
	if root is Entity:
		return (root as Entity).find_component(&"Stats") as Stats
	return root.get_node_or_null("Stats") as Stats


func _make_key(item_instance: ItemInstance, suffix: String) -> StringName:
	var item_seed: int = 0
	if item_instance != null:
		item_seed = item_instance.seed
	return StringName("spell_%s_%d" % [suffix, item_seed])

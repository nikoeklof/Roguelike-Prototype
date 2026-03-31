extends ItemAttribute
class_name PhasingAttribute

@export_range(0.1, 2.0, 0.1) var phase_duration_sec: float = 0.5
@export_range(0.5, 5.0, 0.1) var phase_cooldown_sec: float = 3.0
@export_range(0.0, 1.0, 0.1) var damage_reduction_while_phasing: float = 0.9

const META_PHASING: StringName = &"__phasing_active"
const META_PHASE_UNTIL: StringName = &"__phasing_until"
const META_LAST_PHASE: StringName = &"__last_phase_time"

func default_domains() -> PackedStringArray:
	return PackedStringArray(["stats", "block_start"])

func get_stat_additive(context: CombatContext, _item_instance: ItemInstance) -> ItemStats:
	if context == null or context.owner == null:
		return ItemStats.new()

	var owner: Node = context.owner
	var now: float = Time.get_ticks_msec() / 1000.0

	# Apply damage reduction if currently phasing
	var phase_until: float = owner.get_meta(META_PHASE_UNTIL, 0.0)
	if now < phase_until:
		var stats := ItemStats.new()
		stats.damage_taken_mult = 1.0 - damage_reduction_while_phasing
		return stats

	return ItemStats.new()


func on_block_start(context: CombatContext, _item_instance: ItemInstance) -> void:
	"""Initialize phasing when block starts"""
	if context == null or context.owner == null:
		return
	
	var owner: Node = context.owner
	owner.set_meta(META_LAST_PHASE, 0.0)
	owner.set_meta(META_PHASING, false)
	owner.set_meta(META_PHASE_UNTIL, 0.0)


func on_block_end(_context: CombatContext, _item_instance: ItemInstance) -> void:
	"""Stop phasing when block ends"""
	pass


func on_ability_activate(context: CombatContext, _item_instance: ItemInstance) -> void:
	"""Called when block input triggers the ability"""
	if context == null or context.owner == null:
		return
	
	var owner: Node = context.owner
	var now: float = Time.get_ticks_msec() / 1000.0
	
	activate_phasing(owner, now)


func activate_phasing(owner: Node, now: float) -> void:
	"""Start a phasing session"""
	owner.set_meta(META_PHASING, true)
	owner.set_meta(META_PHASE_UNTIL, now + phase_duration_sec)
	owner.set_meta(META_LAST_PHASE, now)

	# Apply visual effect
	var visual_controller: EntityVisualController = null
	if owner is Entity:
		visual_controller = (owner as Entity).find_component(&"EntityVisualController") as EntityVisualController
	else:
		visual_controller = owner.get_node_or_null("EntityVisualController") as EntityVisualController

	if visual_controller != null:
		visual_controller.set_shield_amount(0.8)

	# Clean up after phasing ends
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = phase_duration_sec
	owner.add_child(timer)
	timer.timeout.connect(Callable(self, "_end_phasing").bind(owner, timer), CONNECT_ONE_SHOT)
	timer.start()

	print("[PhasingAttribute] Phasing activated for %.2fs (cooldown: %.2fs)" % [phase_duration_sec, phase_cooldown_sec])


func _end_phasing(owner: Node, timer: Timer) -> void:
	"""End phasing session"""
	if owner == null:
		return

	owner.set_meta(META_PHASING, false)

	var visual_controller: EntityVisualController = null
	if owner is Entity:
		visual_controller = (owner as Entity).find_component(&"EntityVisualController") as EntityVisualController
	else:
		visual_controller = owner.get_node_or_null("EntityVisualController") as EntityVisualController

	if visual_controller != null:
		visual_controller.set_shield_amount(0.0)

	if is_instance_valid(timer):
		timer.queue_free()

	print("[PhasingAttribute] Phasing ended")

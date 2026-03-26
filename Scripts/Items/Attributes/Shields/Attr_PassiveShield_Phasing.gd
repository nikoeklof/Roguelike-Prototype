extends ItemAttribute
class_name PhasingAttribute

@export_range(0.1, 2.0, 0.1) var phase_duration_sec: float = 0.5
@export_range(0.5, 5.0, 0.1) var phase_cooldown_sec: float = 3.0
@export_range(0.0, 1.0, 0.1) var damage_reduction_while_phasing: float = 0.9

const META_PHASING: StringName = &"__phasing_active"
const META_PHASE_UNTIL: StringName = &"__phasing_until"
const META_LAST_PHASE: StringName = &"__last_phase_time"

func default_domains() -> PackedStringArray:
	return PackedStringArray(["stats"])

func get_stat_additive(context: CombatContext, _item_instance: ItemInstance) -> ItemStats:
	if context == null or context.owner == null:
		return ItemStats.new()

	var owner: Node = context.owner
	var now: float = Time.get_ticks_msec() / 1000.0

	# Check if we should activate phasing
	if not owner.get_meta(META_PHASING, false):
		var last_phase: float = owner.get_meta(META_LAST_PHASE, 0.0)
		if now >= last_phase + phase_cooldown_sec:
			_activate_phasing(owner, now)

	# Apply damage reduction if currently phasing
	var phase_until: float = owner.get_meta(META_PHASE_UNTIL, 0.0)
	if now < phase_until:
		var stats := ItemStats.new()
		stats.damage_taken_mult = 1.0 - damage_reduction_while_phasing
		return stats

	return ItemStats.new()


func _activate_phasing(owner: Node, now: float) -> void:
	"""Start a phasing session"""
	owner.set_meta(META_PHASING, true)
	owner.set_meta(META_PHASE_UNTIL, now + phase_duration_sec)
	owner.set_meta(META_LAST_PHASE, now)

	# Apply visual effect (shader)
	var visual_controller: EntityVisualController = null
	if owner is Entity:
		visual_controller = (owner as Entity).find_component(&"EntityVisualController") as EntityVisualController
	else:
		visual_controller = owner.get_node_or_null("EntityVisualController") as EntityVisualController

	if visual_controller != null:
		# Use shield_amount to show phasing effect
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

	# Clear visual effect
	var visual_controller: EntityVisualController = null
	if owner is Entity:
		visual_controller = (owner as Entity).find_component(&"EntityVisualController") as EntityVisualController
	else:
		visual_controller = owner.get_node_or_null("EntityVisualController") as EntityVisualController

	if visual_controller != null:
		visual_controller.set_shield_amount(0.0)

	if is_instance_valid(timer):
		timer.queue_free()

	print("[PhasingAttribute] Phasing ended. Cooldown: %.2fs" % phase_cooldown_sec)

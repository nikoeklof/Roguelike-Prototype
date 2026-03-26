extends ItemAttribute
class_name ShieldRegenerationAttribute

@export_range(0.5, 5.0, 0.5) var tick_interval_sec: float = 1.0
@export_range(1.0, 20.0, 1.0) var hp_per_tick: float = 5.0

const META_REGEN_TIMER: StringName = &"__shield_regen_timer"

func _ready() -> void:
	pass  # Regeneration is passive, no special setup needed

func get_stat_additive(_context: CombatContext, _item_instance: ItemInstance) -> ItemStats:
	# Regeneration doesn't modify stats directly
	return ItemStats.new()

# This would need to be called from Shield.gd's on_equipped
func start_regeneration(owner: Node) -> void:
	if owner == null:
		return

	# Stop existing regen if any
	var old_timer: Variant = owner.get_meta(META_REGEN_TIMER, null)
	if old_timer is Timer and is_instance_valid(old_timer):
		old_timer.queue_free()

	# Start new regen timer
	var timer: Timer = Timer.new()
	timer.wait_time = tick_interval_sec
	owner.add_child(timer)
	owner.set_meta(META_REGEN_TIMER, timer)

	var heal_cb: Callable = Callable(self, "_heal_owner").bind(owner)
	timer.timeout.connect(heal_cb)
	timer.start()

	print("[ShieldRegenerationAttribute] Regeneration started: %.1f HP per %.1fs" % [hp_per_tick, tick_interval_sec])


func stop_regeneration(owner: Node) -> void:
	if owner == null:
		return

	var timer: Variant = owner.get_meta(META_REGEN_TIMER, null)
	if timer is Timer and is_instance_valid(timer):
		timer.queue_free()
	owner.set_meta(META_REGEN_TIMER, null)

	print("[ShieldRegenerationAttribute] Regeneration stopped")


func _heal_owner(owner: Node) -> void:
	if owner == null or not is_instance_valid(owner):
		return

	var health: Health = null
	if owner is Entity:
		health = (owner as Entity).find_component(&"Health") as Health
	else:
		health = owner.get_node_or_null("Health") as Health

	if health != null:
		health.heal(hp_per_tick)

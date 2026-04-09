extends ItemAttribute
class_name ShieldRegenerationAttribute

## Regenerates HP passively when out of combat.
## "Out of combat" = no damage taken for [combat_cooldown_sec] seconds.

@export_range(0.5, 5.0, 0.5) var tick_interval_sec: float = 1.0
@export_range(1.0, 20.0, 1.0) var hp_per_tick: float = 5.0
@export_range(1.0, 15.0, 0.5) var combat_cooldown_sec: float = 5.0

const META_REGEN_TIMER: StringName = &"__shield_regen_timer"
const META_REGEN_TRACKER: StringName = &"__shield_regen_tracker"


func default_domains() -> PackedStringArray:
	return PackedStringArray(["equip", "unequip"])


func on_equip(context: CombatContext, _item_instance: ItemInstance) -> void:
	"""Start tracking combat state when the passive shield is equipped."""
	if context == null or context.owner == null:
		return

	_start_tracking(context.owner)


func on_unequip(context: CombatContext, _item_instance: ItemInstance) -> void:
	"""Clean up when the shield is unequipped."""
	if context == null or context.owner == null:
		return

	_stop_tracking(context.owner)


func _start_tracking(owner_entity: Node) -> void:
	"""Attach a tracker node that monitors damage and manages regen."""
	# Clean up any existing tracker
	_stop_tracking(owner_entity)

	var tracker := RegenTracker.new()
	tracker.name = "PassiveShieldRegenTracker"
	tracker.tick_interval = tick_interval_sec
	tracker.hp_per_tick = hp_per_tick
	tracker.combat_cooldown = combat_cooldown_sec
	tracker.attribute_ref = self
	owner_entity.add_child(tracker)
	owner_entity.set_meta(META_REGEN_TRACKER, tracker)

	print("[ShieldRegen] Tracking started on %s (%.1f HP/%.1fs, combat cooldown %.1fs)" % [
		owner_entity.name, hp_per_tick, tick_interval_sec, combat_cooldown_sec
	])


func _stop_tracking(owner_entity: Node) -> void:
	"""Remove the tracker and regen timer."""
	if owner_entity == null:
		return

	if owner_entity.has_meta(META_REGEN_TRACKER):
		var tracker: Variant = owner_entity.get_meta(META_REGEN_TRACKER)
		if tracker is Node and is_instance_valid(tracker):
			tracker.queue_free()
		owner_entity.remove_meta(META_REGEN_TRACKER)

	if owner_entity.has_meta(META_REGEN_TIMER):
		var timer: Variant = owner_entity.get_meta(META_REGEN_TIMER)
		if timer is Timer and is_instance_valid(timer):
			timer.queue_free()
		owner_entity.remove_meta(META_REGEN_TIMER)

	print("[ShieldRegen] Tracking stopped")


## -------------------------------------------------------
## Inner helper node — lives as a child of the entity
## -------------------------------------------------------
class RegenTracker:
	extends Node

	var tick_interval: float = 1.0
	var hp_per_tick: float = 5.0
	var combat_cooldown: float = 5.0
	var attribute_ref: ShieldRegenerationAttribute = null

	var _time_since_damage: float = 999.0  # Start as "out of combat"
	var _regen_active: bool = false
	var _regen_timer: Timer = null
	var _health: Health = null

	func _ready() -> void:
		var owner_entity: Node = get_parent()
		if owner_entity == null:
			return
		# Find Health component
		if owner_entity is Entity:
			_health = (owner_entity as Entity).find_component(&"Health") as Health
		else:
			_health = owner_entity.get_node_or_null("Health") as Health
		if _health == null:
			print("[ShieldRegen] WARNING: No Health component on %s" % owner_entity.name)
			return
		# Listen for damage
		if not _health.damaged.is_connected(_on_damaged):
			_health.damaged.connect(_on_damaged)
		# If already at full HP, don't start regen
		_time_since_damage = combat_cooldown + 1.0  # Treat as already out of combat
		_check_regen_state()

	func _physics_process(delta: float) -> void:
		_time_since_damage += delta
		_check_regen_state()

	func _on_damaged(_amount: float, _source: Node) -> void:
		_time_since_damage = 0.0
		# Immediately stop regen when hit
		if _regen_active:
			_stop_regen()

	func _check_regen_state() -> void:
		if _health == null:
			return

		var is_out_of_combat: bool = _time_since_damage >= combat_cooldown
		var needs_healing: bool = _health.hp < _health.max_hp

		if is_out_of_combat and needs_healing and not _regen_active:
			_start_regen()
		elif (not is_out_of_combat or not needs_healing) and _regen_active:
			_stop_regen()

	func _start_regen() -> void:
		if _regen_active:
			return

		_regen_active = true

		_regen_timer = Timer.new()
		_regen_timer.wait_time = tick_interval
		_regen_timer.autostart = true
		add_child(_regen_timer)
		_regen_timer.timeout.connect(_on_regen_tick)

		# Heal immediately on first tick
		_on_regen_tick()

		print("[ShieldRegen] Regen STARTED (%.1f HP every %.1fs)" % [hp_per_tick, tick_interval])

	func _stop_regen() -> void:
		if not _regen_active:
			return

		_regen_active = false

		if _regen_timer != null and is_instance_valid(_regen_timer):
			_regen_timer.queue_free()
			_regen_timer = null

		print("[ShieldRegen] Regen STOPPED")

	func _on_regen_tick() -> void:
		if _health == null or not is_instance_valid(_health):
			_stop_regen()
			return

		if _health.hp >= _health.max_hp:
			_stop_regen()
			return

		var healed: float = _health.heal(hp_per_tick)
		if healed > 0.0:
			print("[ShieldRegen] Healed %.1f HP (%.1f/%.1f)" % [healed, _health.hp, _health.max_hp])

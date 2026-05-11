extends Area2D
class_name StatUpPickup

@export var pickup_def: StatUpDef

static var _apply_counter: int = 0


func _ready() -> void:
	monitoring = false
	monitorable = true
	add_to_group("interactable")


func can_interact(_interactor: Node) -> bool:
	return pickup_def != null


func interact(interactor: Node) -> void:
	if pickup_def == null:
		return
	var stats: Stats = interactor.get_node_or_null("Stats") as Stats
	if stats == null:
		return
	_apply_counter += 1
	var key_prefix: String = "statup_%d" % _apply_counter
	for entry: StatModEntry in pickup_def.modifiers:
		_apply_modifier(stats, entry, key_prefix)
	queue_free()


func on_interactor_entered(_interactor_owner: Node) -> void:
	pass


func on_interactor_exited(_interactor_owner: Node) -> void:
	pass


func _apply_modifier(stats: Stats, entry: StatModEntry, key_prefix: String) -> void:
	var key: StringName = StringName("%s_%d" % [key_prefix, entry.stat])
	match entry.stat:
		StatModEntry.StatTarget.MOVE_SPEED_MULT:
			stats.set_move_speed_mult(key, entry.value)
		StatModEntry.StatTarget.ATTACK_SPEED_MULT:
			stats.set_attack_speed_mult(key, entry.value)
		StatModEntry.StatTarget.DAMAGE_TAKEN_MULT:
			stats.set_damage_taken_mult(key, entry.value)
		StatModEntry.StatTarget.FLAT_DAMAGE_REDUCTION:
			stats.set_flat_damage_reduction(key, entry.value)
		StatModEntry.StatTarget.MELEE_DAMAGE_MULT:
			stats.set_melee_damage_mult(key, entry.value)
		StatModEntry.StatTarget.RANGED_DAMAGE_MULT:
			stats.set_ranged_damage_mult(key, entry.value)
		StatModEntry.StatTarget.COOLDOWN_REDUCTION:
			stats.set_cooldown_reduction(key, entry.value)
		StatModEntry.StatTarget.ACCEL_MULT:
			stats.set_accel_mult(key, entry.value)

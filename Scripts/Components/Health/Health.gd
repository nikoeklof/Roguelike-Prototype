extends Node
class_name Health

signal hp_changed(hp: float, max_hp: float)
signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal max_hp_changed(max_hp: float)
signal died()

@export_range(1.0, 99999.0, 1.0) var max_hp: float = 5.0
@export var start_full: bool = true

# Small invuln helps prevent accidental multi-hit spam.
# This now starts at the end of the current frame, so simultaneous hits
# from the same attack burst can still all apply.
@export_range(0.0, 5.0, 0.01) var invuln_sec_on_hit: float = 0.0

var hp: float = 0.0
var _invuln_t: float = 0.0
var _pending_invuln: bool = false

func _ready() -> void:
	hp = max_hp if start_full else clampf(hp, 0.0, max_hp)
	hp_changed.emit(hp, max_hp)

func _physics_process(delta: float) -> void:
	if _invuln_t > 0.0:
		_invuln_t = maxf(_invuln_t - delta, 0.0)

func is_dead() -> bool:
	return hp <= 0.0

func can_take_damage() -> bool:
	return _invuln_t <= 0.0 and not is_dead()

func take_damage(amount: float, source: Node = null) -> bool:
	if amount <= 0.0:
		return false
	if not can_take_damage():
		return false

	# Apply Stats-based damage modification (if Stats component exists).
	var stats := get_parent().get_node_or_null("Stats") as Stats
	if stats:
		amount *= stats.damage_taken_mult()
		amount -= stats.flat_damage_reduction()

	# If damage is reduced to nothing, treat as "no damage dealt".
	if amount <= 0.0:
		return false

	var applied := amount
	hp = maxf(hp - applied, 0.0)

	# Defer invulnerability activation so multiple hits that land in the same
	# frame / burst can all apply before the grace period begins.
	if invuln_sec_on_hit > 0.0 and not _pending_invuln:
		_pending_invuln = true
		call_deferred("_activate_pending_invuln")

	damaged.emit(applied, source)
	hp_changed.emit(hp, max_hp)

	if hp <= 0.0:
		died.emit()
	return true

func _activate_pending_invuln() -> void:
	if not _pending_invuln:
		return
	if is_dead():
		_pending_invuln = false
		return

	_pending_invuln = false
	_invuln_t = invuln_sec_on_hit

func heal(amount: float) -> float:
	if amount <= 0.0 or is_dead():
		return 0.0

	var before := hp
	hp = minf(hp + amount, max_hp)
	var applied := hp - before

	if applied > 0.0:
		healed.emit(applied)
		hp_changed.emit(hp, max_hp)

	return applied

func full_heal() -> void:
	heal(max_hp)

# Upgrade-friendly API:

func set_max_hp(new_max: float, keep_ratio: bool = false) -> void:
	new_max = maxf(new_max, 1.0)
	if is_equal_approx(new_max, max_hp):
		return

	var old_max := max_hp
	max_hp = new_max
	max_hp_changed.emit(max_hp)

	if keep_ratio and old_max > 0.0:
		var ratio := hp / old_max
		hp = clampf(ratio * max_hp, 0.0, max_hp)
	else:
		hp = minf(hp, max_hp)

	hp_changed.emit(hp, max_hp)

func add_max_hp(delta: float, heal_amount: float = 0.0, keep_ratio: bool = false) -> void:
	set_max_hp(max_hp + delta, keep_ratio)
	if heal_amount > 0.0:
		heal(heal_amount)

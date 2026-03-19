extends Node
class_name Stats

signal changed()

# =====================================
# BASE VALUES (authoring knobs)
# =====================================

# Movement base values
@export_range(0.0, 2000.0, 1.0) var base_move_speed: float = 250.0
@export_range(0.0, 10000.0, 1.0) var base_acceleration: float = 800.0
@export_range(0.0, 10000.0, 1.0) var base_friction: float = 900.0
@export_range(0.0, 50.0, 0.1) var base_deadzone: float = 5.0

# Movement multipliers
@export_range(0.0, 5.0, 0.01) var base_move_speed_mult: float = 1.0
@export_range(0.0, 5.0, 0.01) var base_accel_mult: float = 1.0
@export_range(0.0, 5.0, 0.01) var base_friction_mult: float = 1.0

# Attack speed
@export_range(0.0, 10.0, 0.01) var base_attack_speed_mult: float = 1.0

# Damage-related
@export_range(0.0, 10.0, 0.01) var base_damage_taken_mult: float = 1.0
@export_range(0.0, 9999.0, 0.1) var base_flat_damage_reduction: float = 0.0

@export_range(0.0, 10.0, 0.01) var base_melee_damage_mult: float = 1.0
@export_range(0.0, 10.0, 0.01) var base_ranged_damage_mult: float = 1.0

@export_range(0.0, 0.9, 0.01) var base_cooldown_reduction: float = 0.0 # 0..0.9 recommended cap


# =====================================
# INTERNAL MODIFIER STORAGE (stacking)
# =====================================
var _move_speed_mult_mods: Dictionary = {}        # key -> mult
var _accel_mult_mods: Dictionary = {}             # key -> mult
var _friction_mult_mods: Dictionary = {}          # key -> mult

var _attack_speed_mult_mods: Dictionary = {}      # key -> mult

var _damage_taken_mult_mods: Dictionary = {}       # key -> mult
var _flat_damage_reduction_mods: Dictionary = {}   # key -> flat

var _melee_damage_mult_mods: Dictionary = {}       # key -> mult
var _ranged_damage_mult_mods: Dictionary = {}      # key -> mult

var _cooldown_reduction_mods: Dictionary = {}      # key -> add

# Global spell cooldown (time-based)
var _global_spell_cooldown_until: float = 0.0


# =====================================
# PUBLIC GETTERS - EFFECTIVE VALUES
# =====================================

# Movement - effective values with all modifiers applied
func effective_move_speed() -> float:
	return base_move_speed * move_speed_mult()

func effective_acceleration() -> float:
	return base_acceleration * accel_mult()

func effective_friction() -> float:
	return base_friction * friction_mult()

func get_deadzone() -> float:
	return base_deadzone

# Movement multipliers (stacking modifiers)
func move_speed_mult() -> float:
	return _mult(base_move_speed_mult, _move_speed_mult_mods)

func accel_mult() -> float:
	return _mult(base_accel_mult, _accel_mult_mods)

func friction_mult() -> float:
	return _mult(base_friction_mult, _friction_mult_mods)

# Attack speed multiplier
func attack_speed_mult() -> float:
	return _mult(base_attack_speed_mult, _attack_speed_mult_mods)

# Damage-related getters
func damage_taken_mult() -> float:
	return _mult(base_damage_taken_mult, _damage_taken_mult_mods)

func flat_damage_reduction() -> float:
	return _add(base_flat_damage_reduction, _flat_damage_reduction_mods)

func melee_damage_mult() -> float:
	return _mult(base_melee_damage_mult, _melee_damage_mult_mods)

func ranged_damage_mult() -> float:
	return _mult(base_ranged_damage_mult, _ranged_damage_mult_mods)

# Returns 0..0.9 (clamped). Use this as: effective_cd = base_cd * (1 - cdr)
func cooldown_reduction() -> float:
	var cdr := _add(base_cooldown_reduction, _cooldown_reduction_mods)
	return clampf(cdr, 0.0, 0.9)

# Convenience: apply CDR to a base cooldown
func apply_cooldown(base_cd: float) -> float:
	return maxf(0.0, base_cd * (1.0 - cooldown_reduction()))


# =====================================
# PUBLIC GETTERS - SPELL COOLDOWN
# =====================================

func get_spell_cooldown_remaining() -> float:
	"""Returns seconds remaining on global spell cooldown. 0.0 if ready."""
	var now := Time.get_ticks_msec() / 1000.0
	return maxf(0.0, _global_spell_cooldown_until - now)

func is_spell_ready() -> bool:
	"""Check if a spell can be cast right now."""
	return get_spell_cooldown_remaining() <= 0.0


# =====================================
# MODIFIER API (set/clear)
# =====================================

# Movement modifiers
func set_move_speed_mult(key: StringName, mult: float) -> void:
	_set_mult(_move_speed_mult_mods, key, mult)

func clear_move_speed_mult(key: StringName) -> void:
	_clear(_move_speed_mult_mods, key)

func set_accel_mult(key: StringName, mult: float) -> void:
	_set_mult(_accel_mult_mods, key, mult)

func clear_accel_mult(key: StringName) -> void:
	_clear(_accel_mult_mods, key)

func set_friction_mult(key: StringName, mult: float) -> void:
	_set_mult(_friction_mult_mods, key, mult)

func clear_friction_mult(key: StringName) -> void:
	_clear(_friction_mult_mods, key)

# Attack speed modifier
func set_attack_speed_mult(key: StringName, mult: float) -> void:
	_set_mult(_attack_speed_mult_mods, key, mult)

func clear_attack_speed_mult(key: StringName) -> void:
	_clear(_attack_speed_mult_mods, key)

# Damage modifiers
func set_damage_taken_mult(key: StringName, mult: float) -> void:
	_set_mult(_damage_taken_mult_mods, key, mult)

func clear_damage_taken_mult(key: StringName) -> void:
	_clear(_damage_taken_mult_mods, key)

func set_flat_damage_reduction(key: StringName, amount: float) -> void:
	_set_add(_flat_damage_reduction_mods, key, amount)

func clear_flat_damage_reduction(key: StringName) -> void:
	_clear(_flat_damage_reduction_mods, key)

func set_melee_damage_mult(key: StringName, mult: float) -> void:
	_set_mult(_melee_damage_mult_mods, key, mult)

func clear_melee_damage_mult(key: StringName) -> void:
	_clear(_melee_damage_mult_mods, key)

func set_ranged_damage_mult(key: StringName, mult: float) -> void:
	_set_mult(_ranged_damage_mult_mods, key, mult)

func clear_ranged_damage_mult(key: StringName) -> void:
	_clear(_ranged_damage_mult_mods, key)

func set_cooldown_reduction(key: StringName, add: float) -> void:
	_set_add(_cooldown_reduction_mods, key, add)

func clear_cooldown_reduction(key: StringName) -> void:
	_clear(_cooldown_reduction_mods, key)


# =====================================
# SPELL COOLDOWN API
# =====================================

func apply_spell_cooldown(duration_sec: float) -> void:
	"""Apply a global spell cooldown (blocks all spells for this duration)."""
	var now := Time.get_ticks_msec() / 1000.0
	_global_spell_cooldown_until = now + maxf(0.01, duration_sec)
	changed.emit()


# =====================================
# HELPERS
# =====================================

func _mult(base: float, mods: Dictionary) -> float:
	var v := base
	for k in mods.keys():
		v *= float(mods[k])
	return v

func _add(base: float, mods: Dictionary) -> float:
	var v := base
	for k in mods.keys():
		v += float(mods[k])
	return v

func _set_mult(mods: Dictionary, key: StringName, mult: float) -> void:
	mods[key] = maxf(mult, 0.0)
	changed.emit()

func _set_add(mods: Dictionary, key: StringName, add: float) -> void:
	mods[key] = add
	changed.emit()

func _clear(mods: Dictionary, key: StringName) -> void:
	if mods.erase(key):
		changed.emit()

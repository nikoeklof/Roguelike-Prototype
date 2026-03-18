extends Node
class_name Stats

signal changed()

# -----------------------------
# Base values (authoring knobs)
# -----------------------------
@export_range(0.0, 5.0, 0.01) var base_move_speed_mult: float = 1.0
@export_range(0.0, 5.0, 0.01) var base_accel_mult: float = 1.0
@export_range(0.0, 5.0, 0.01) var base_friction_mult: float = 1.0

@export_range(0.0, 10.0, 0.01) var base_attack_speed_mult: float = 1.0

@export_range(0.0, 10.0, 0.01) var base_damage_taken_mult: float = 1.0
@export_range(0.0, 9999.0, 0.1) var base_flat_damage_reduction: float = 0.0

@export_range(0.0, 10.0, 0.01) var base_melee_damage_mult: float = 1.0
@export_range(0.0, 10.0, 0.01) var base_ranged_damage_mult: float = 1.0

@export_range(0.0, 0.9, 0.01) var base_cooldown_reduction: float = 0.0 # 0..0.9 recommended cap


# -----------------------------------
# Internal modifier storage (stacking)
# Keys are StringName so callers can add/remove by a stable id.
# -----------------------------------
var _move_speed_mult_mods: Dictionary = {}        # key -> mult
var _accel_mult_mods: Dictionary = {}             # key -> mult
var _friction_mult_mods: Dictionary = {}          # key -> mult

var _attack_speed_mult_mods: Dictionary = {}      # key -> mult

var _damage_taken_mult_mods: Dictionary = {}       # key -> mult
var _flat_damage_reduction_mods: Dictionary = {}   # key -> flat

var _melee_damage_mult_mods: Dictionary = {}       # key -> mult
var _ranged_damage_mult_mods: Dictionary = {}      # key -> mult

var _cooldown_reduction_mods: Dictionary = {}      # key -> add


# -----------------------------
# Public getters (resolved stats)
# -----------------------------
func move_speed_mult() -> float:
	return _mult(base_move_speed_mult, _move_speed_mult_mods)

func accel_mult() -> float:
	return _mult(base_accel_mult, _accel_mult_mods)

func friction_mult() -> float:
	return _mult(base_friction_mult, _friction_mult_mods)

func attack_speed_mult() -> float:
	return _mult(base_attack_speed_mult, _attack_speed_mult_mods)

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


# -----------------------------
# Modifier API (set/clear)
# -----------------------------
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

func set_attack_speed_mult(key: StringName, mult: float) -> void:
	_set_mult(_attack_speed_mult_mods, key, mult)

func clear_attack_speed_mult(key: StringName) -> void:
	_clear(_attack_speed_mult_mods, key)

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


# -----------------------------
# Helpers
# -----------------------------
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
	print("Setting multiplier to %s" % mult)
	mods[key] = maxf(mult, 0.0)
	changed.emit()

func _set_add(mods: Dictionary, key: StringName, add: float) -> void:
	mods[key] = add
	changed.emit()

func _clear(mods: Dictionary, key: StringName) -> void:
	if mods.erase(key):
		changed.emit()

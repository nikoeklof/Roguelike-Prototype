extends Node
class_name PassiveShield

var _entity: Entity
var _shield_def: ShieldItemDef
var _stats_key: StringName = &"passive_shield"


func _ready() -> void:
	_entity = get_parent() as Entity


func set_shield_def(def: ShieldItemDef) -> void:
	"""Set the shield definition when equipped"""
	# Clear old effects
	_clear_buffs()
	
	if def == null or def.shield_type != ShieldItemDef.ShieldType.PASSIVE:
		_shield_def = null
		return
	
	_shield_def = def
	_apply_buffs()


func _apply_buffs() -> void:
	if _shield_def == null or _entity == null:
		return
	
	var stats: Stats = _entity.find_component(&"Stats") as Stats
	if stats == null:
		return
	
	print("[PassiveShield] Applying passive buffs")
	
	# Apply movement speed buff
	stats.set_move_speed_mult(_stats_key, _shield_def.passive_movement_speed_mult)
	
	# Apply damage reduction
	if _shield_def.passive_damage_reduction_mult > 0.0:
		stats.set_damage_taken_mult(_stats_key, 1.0 - _shield_def.passive_damage_reduction_mult)
	
	# Apply flat damage reduction
	if _shield_def.flat_damage_reduction > 0.0:
		stats.set_flat_damage_reduction(_stats_key, _shield_def.flat_damage_reduction)


func _clear_buffs() -> void:
	if _entity == null:
		return
	
	var stats: Stats = _entity.find_component(&"Stats") as Stats
	if stats == null:
		return
	
	print("[PassiveShield] Removing passive buffs")
	
	stats.clear_move_speed_mult(_stats_key)
	stats.clear_damage_taken_mult(_stats_key)
	stats.clear_flat_damage_reduction(_stats_key)


func get_shield_def() -> ShieldItemDef:
	return _shield_def

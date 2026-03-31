extends Node
class_name PassiveShield

var _entity: Entity
var _shield_def: ShieldItemDef


func _ready() -> void:
	_entity = get_parent() as Entity


func set_shield_def(def: ShieldItemDef) -> void:
	"""Set the shield definition when equipped"""
	if def == null or def.shield_type != ShieldItemDef.ShieldType.PASSIVE:
		_shield_def = null
		return
	
	print("[PassiveShield] Shield equipped: %s" % def.display_name)
	_shield_def = def


func on_block_start(shield_instance: ItemInstance) -> void:
	"""Called when Block state is entered"""
	if _entity == null or shield_instance == null:
		return
	
	print("[PassiveShield] Block started - activating attributes")
	
	# Let the executor handle attribute activation
	ShieldBlockExecutor.execute_block_start(_entity, shield_instance as Shield, shield_instance)


func on_block_end() -> void:
	"""Called when Block state is exited"""
	if _entity == null:
		return
	
	print("[PassiveShield] Block ended - deactivating attributes")
	
	# The executor will handle cleanup via on_block_end hooks in attributes
	# This is a placeholder for any passive-shield-specific cleanup

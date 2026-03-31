extends Node
class_name PassiveShield

var _entity: Entity
var _shield: Shield
var _activator: PassiveShieldAttributeActivator


func _ready() -> void:
	_entity = get_parent() as Entity
	if _entity != null:
		_activator = _entity.find_component(&"PassiveShieldAttributeActivator") as PassiveShieldAttributeActivator
		print("[PassiveShield] Ready, activator found: %s" % (_activator != null))


func set_shield_def(def: ShieldItemDef) -> void:
	"""Set the shield definition when equipped"""
	if def == null or def.shield_type != ShieldItemDef.ShieldType.PASSIVE:
		_shield = null
		return
	
	print("[PassiveShield] Shield equipped: %s" % def.display_name)


func on_block_start(shield_instance: ItemInstance) -> void:
	"""Called when passive shield blocking starts (not used for passive shields, kept for compatibility)"""
	# Passive shields don't enter a block state, so this is mainly for attribute initialization
	if _entity == null or shield_instance == null:
		return
	
	print("[PassiveShield] Initializing passive shield")
	
	# Set the shield instance on the activator
	if _activator != null:
		_activator.set_shield_instance(shield_instance)
		print("[PassiveShield] Shield instance set on activator")


func on_block_end() -> void:
	"""Called when passive shield blocking ends (not used for passive shields, kept for compatibility)"""
	pass

extends EquipmentSlot
class_name ShieldSlot

var _active_shield: ActiveShield
var _passive_shield: PassiveShield


func _ready() -> void:
	super._ready()
	
	# Find or create shield components on parent entity
	var entity: Entity = get_parent().get_parent() as Entity
	if entity == null:
		return
	
	_active_shield = entity.find_component(&"ActiveShield") as ActiveShield
	if _active_shield == null:
		_active_shield = ActiveShield.new()
		_active_shield.name = "ActiveShield"
		entity.add_child(_active_shield)
	
	_passive_shield = entity.find_component(&"PassiveShield") as PassiveShield
	if _passive_shield == null:
		_passive_shield = PassiveShield.new()
		_passive_shield.name = "PassiveShield"
		entity.add_child(_passive_shield)


func _on_item_equipped(item: ItemInstance) -> void:
	super._on_item_equipped(item)
	
	if item == null or item.def == null:
		_active_shield.set_shield_def(null)
		_passive_shield.set_shield_def(null)
		return
	
	var shield_def: ShieldItemDef = item.def as ShieldItemDef
	if shield_def == null:
		return
	
	print("[ShieldSlot] Equipped shield: %s (type: %s)" % [shield_def.name, ShieldItemDef.ShieldType.keys()[shield_def.shield_type]])
	
	# Set appropriate shield component
	match shield_def.shield_type:
		ShieldItemDef.ShieldType.ACTIVE:
			_active_shield.set_shield_def(shield_def)
			_passive_shield.set_shield_def(null)
		ShieldItemDef.ShieldType.PASSIVE:
			_passive_shield.set_shield_def(shield_def)
			_active_shield.set_shield_def(null)


func _on_item_unequipped(item: ItemInstance) -> void:
	super._on_item_unequipped(item)
	
	_active_shield.set_shield_def(null)
	_passive_shield.set_shield_def(null)

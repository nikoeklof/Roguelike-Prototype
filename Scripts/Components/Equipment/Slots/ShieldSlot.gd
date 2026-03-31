extends EquipmentSlot
class_name ShieldSlot

var _active_shield: ActiveShield
var _passive_shield: PassiveShield
var _passive_shield_activator: PassiveShieldAttributeActivator


func _ready() -> void:
	super._ready()
	
	# Connect to item changed signal
	if not changed.is_connected(_on_item_changed):
		changed.connect(_on_item_changed)
	
	# Defer component creation to avoid "busy setting up children" error
	call_deferred("_setup_shield_components")


func _setup_shield_components() -> void:
	"""Setup shield components after parent is ready"""
	var entity: Entity = get_parent().get_parent() as Entity
	if entity == null:
		print("[ShieldSlot] ERROR: Could not find parent entity")
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
	
	_passive_shield_activator = entity.find_component(&"PassiveShieldAttributeActivator") as PassiveShieldAttributeActivator
	if _passive_shield_activator == null:
		_passive_shield_activator = PassiveShieldAttributeActivator.new()
		_passive_shield_activator.name = "PassiveShieldAttributeActivator"
		entity.add_child(_passive_shield_activator)
	
	# Apply initial shield if one is already equipped
	_on_item_changed(get_item(), null)


func _on_item_changed(new_item: Node, old_item: Node) -> void:
	"""Called when item changes in this slot"""
	print("[ShieldSlot] Item changed: %s -> %s" % [old_item, new_item])
	
	if _active_shield == null or _passive_shield == null or _passive_shield_activator == null:
		print("[ShieldSlot] WARNING: Shield components not initialized yet")
		return
	
	# Handle unequip
	if old_item != null:
		var old_shield: Shield = old_item as Shield
		if old_shield != null:
			_active_shield.set_shield_def(null)
			_passive_shield.set_shield_def(null)
	
	# Handle equip
	if new_item == null:
		print("[ShieldSlot] No item equipped")
		return
	
	if not new_item is Shield:
		print("[ShieldSlot] ERROR: Equipped item is not a Shield")
		return
	
	var shield_item: Shield = new_item as Shield
	var shield_instance: ItemInstance = shield_item.get_item_instance()
	
	if shield_instance == null:
		print("[ShieldSlot] ERROR: Shield has no ItemInstance")
		return
	
	var shield_def: ShieldItemDef = shield_instance.def as ShieldItemDef
	
	if shield_def == null:
		print("[ShieldSlot] ERROR: Shield ItemDef is not a ShieldItemDef")
		return
	
	print("[ShieldSlot] Equipped shield: %s (type: %s)" % [shield_def.display_name, ShieldItemDef.ShieldType.keys()[shield_def.shield_type]])
	
	# Set appropriate shield component based on type
	match shield_def.shield_type:
		ShieldItemDef.ShieldType.ACTIVE:
			print("[ShieldSlot] Setting up ACTIVE shield")
			_active_shield.set_shield_def(shield_def)
			_passive_shield.set_shield_def(null)  # FIXED: null instead of None
		
		ShieldItemDef.ShieldType.PASSIVE:
			print("[ShieldSlot] Setting up PASSIVE shield")
			_passive_shield.set_shield_def(shield_def)
			_active_shield.set_shield_def(null)  # FIXED: null instead of None
			
			# Initialize passive shield abilities
			_passive_shield.on_block_start(shield_instance)

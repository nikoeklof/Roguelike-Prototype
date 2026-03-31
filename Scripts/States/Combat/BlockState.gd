extends State
class_name BlockState

var _active_shield: ActiveShield
var _passive_shield: PassiveShield


func enter(_msg: Dictionary = {}) -> void:
	if entity == null:
		return
	
	print("[BlockState] Entered block state")
	
	# Get shield components
	_active_shield = entity.find_component(&"ActiveShield") as ActiveShield
	_passive_shield = entity.find_component(&"PassiveShield") as PassiveShield
	
	# Get currently equipped shield
	var equipment: Equipment = entity.find_component(&"Equipment") as Equipment
	if equipment == null:
		state_handler.change_state("Idle")
		return
	
	var shield_slot: ShieldSlot = equipment.get_node_or_null("ShieldSlot") as ShieldSlot
	if shield_slot == null:
		state_handler.change_state("Idle")
		return
	
	var shield: Shield = shield_slot.get_item() as Shield
	if shield == null:
		state_handler.change_state("Idle")
		return
	
	var shield_instance: ItemInstance = shield.get_item_instance()
	if shield_instance == null:
		state_handler.change_state("Idle")
		return
	
	# Just notify components - they handle their own behavior
	match (shield_instance.def as ShieldItemDef).shield_type:
		ShieldItemDef.ShieldType.ACTIVE:
			if _active_shield != null:
				_active_shield.on_block_start()
		
		ShieldItemDef.ShieldType.PASSIVE:
			if _passive_shield != null:
				_passive_shield.on_block_start(shield_instance)


func exit() -> void:
	print("[BlockState] Exited block state")
	
	if _active_shield != null:
		_active_shield.on_block_end()
	
	if _passive_shield != null:
		_passive_shield.on_block_end()


func physics_update(_delta: float) -> void:
	if entity == null:
		return
	
	var control: ControlSource = entity.find_component(&"ControlSource") as ControlSource
	if control == null or not control.wants_block():
		state_handler.change_state("Idle")

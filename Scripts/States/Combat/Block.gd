extends State
class_name BlockState

var _shield: Shield
var _active_shield: ActiveShield


func enter(_msg: Dictionary = {}) -> void:
	if entity == null:
		return
	
	print("[BlockState] Entered block state")
	
	# Get shield components
	_active_shield = entity.find_component(&"ActiveShield") as ActiveShield
	
	# Get currently equipped shield
	var equipment: Equipment = entity.find_component(&"Equipment") as Equipment
	if equipment == null:
		print("[BlockState] ERROR: No Equipment component found")
		state_handler.change_state("Idle")
		return
	
	var shield_slot: ShieldSlot = equipment.get_node_or_null("ShieldSlot") as ShieldSlot
	if shield_slot == null:
		print("[BlockState] ERROR: No ShieldSlot found")
		state_handler.change_state("Idle")
		return
	
	_shield = shield_slot.get_item() as Shield
	if _shield == null:
		print("[BlockState] ERROR: No shield equipped")
		state_handler.change_state("Idle")
		return
	
	var shield_instance: ItemInstance = _shield.get_item_instance()
	if shield_instance == null:
		print("[BlockState] ERROR: Shield has no ItemInstance")
		state_handler.change_state("Idle")
		return
	
	# Check shield type and execute appropriate blocking
	var shield_def: ShieldItemDef = shield_instance.def as ShieldItemDef
	if shield_def == null:
		print("[BlockState] ERROR: Shield has no ShieldItemDef")
		state_handler.change_state("Idle")
		return
	
	match shield_def.shield_type:
		ShieldItemDef.ShieldType.ACTIVE:
			if _active_shield != null:
				_active_shield.start_blocking()
		
		ShieldItemDef.ShieldType.PASSIVE:
			# Use executor to activate all block_start attributes
			ShieldBlockExecutor.execute_block_start(entity, _shield, shield_instance)


func exit() -> void:
	print("[BlockState] Exited block state")
	
	# Stop active shield blocking if it was active
	if _active_shield != null and _active_shield.is_blocking():
		_active_shield.stop_blocking()
	
	# Get shield for passive cleanup
	if _shield == null:
		return
	
	var shield_instance: ItemInstance = _shield.get_item_instance()
	if shield_instance == null:
		return
	
	var shield_def: ShieldItemDef = shield_instance.def as ShieldItemDef
	if shield_def == null:
		return
	
	# Cleanup passive shield attributes
	if shield_def.shield_type == ShieldItemDef.ShieldType.PASSIVE:
		ShieldBlockExecutor.execute_block_end(entity, _shield, shield_instance)


func physics_update(_delta: float) -> void:
	if entity == null:
		return
	
	# Get control source
	var control: ControlSource = entity.find_component(&"ControlSource") as ControlSource
	if control == null:
		state_handler.change_state("Idle")
		return
	
	# Exit block if input released
	if not control.wants_block():
		state_handler.change_state("Idle")
		return

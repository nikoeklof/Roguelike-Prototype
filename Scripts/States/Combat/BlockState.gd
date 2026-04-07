extends State
class_name BlockState

var _shield: Shield
var _shield_instance: ItemInstance
var _mover: Mover


func enter(_msg: Dictionary = {}) -> void:
	if entity == null:
		return
	
	print("[BlockState] Entered block state")
	
	# Get mover component for movement
	_mover = entity.find_component(&"Mover") as Mover if entity is Entity else null
	
	# Get currently equipped shield
	var equipment: Equipment = entity.find_component(&"Equipment") as Equipment
	if equipment == null:
		state_handler.change_state("Idle")
		return
	
	var shield_slot: ShieldSlot = equipment.get_node_or_null("ShieldSlot") as ShieldSlot
	if shield_slot == null:
		state_handler.change_state("Idle")
		return
	
	_shield = shield_slot.get_item() as Shield
	if _shield == null:
		state_handler.change_state("Idle")
		return
	
	_shield_instance = _shield.get_item_instance()
	if _shield_instance == null:
		state_handler.change_state("Idle")
		return
	
	var shield_def: ShieldItemDef = _shield_instance.def as ShieldItemDef
	if shield_def == null:
		state_handler.change_state("Idle")
		return
	
	# Only handle ACTIVE shields
	if shield_def.shield_type != ShieldItemDef.ShieldType.ACTIVE:
		print("[BlockState] Not an active shield, exiting")
		state_handler.change_state("Idle")
		return
	
	print("[BlockState] Activating active shield")
	var active_shield: ActiveShield = entity.find_component(&"ActiveShield") as ActiveShield
	if active_shield != null:
		active_shield.on_block_start()


func exit() -> void:
	print("[BlockState] Exited block state")
	
	if _shield_instance == null:
		return
	
	var shield_def: ShieldItemDef = _shield_instance.def as ShieldItemDef
	if shield_def == null or shield_def.shield_type != ShieldItemDef.ShieldType.ACTIVE:
		return
	
	var active_shield: ActiveShield = entity.find_component(&"ActiveShield") as ActiveShield
	if active_shield != null:
		active_shield.on_block_end()


func physics_update(delta: float) -> void:
	if entity == null:
		return
	
	var control: ControlSource = entity.find_component(&"ControlSource") as ControlSource
	if control == null or not control.wants_block():
		state_handler.change_state("Idle")
		return
	
	# ALLOW MOVEMENT WHILE BLOCKING
	var move_input: Vector2 = control.move_intent()
	
	if _mover != null and entity is CharacterBody2D:
		_mover.intent = move_input
		_mover.apply(entity as CharacterBody2D, delta)

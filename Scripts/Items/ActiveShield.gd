extends Node
class_name ActiveShield

signal blocking_started
signal blocking_stopped

@export_node_path("Node2D") var shield_visual_path: NodePath

var _entity: Entity
var _is_blocking: bool = false
var _shield_def: ShieldItemDef
var _shield_visual: Node2D


func _ready() -> void:
	_entity = get_parent() as Entity
	
	# Try to find shield visual
	if shield_visual_path != NodePath():
		_shield_visual = get_node_or_null(shield_visual_path) as Node2D
	
	if _shield_visual == null:
		_shield_visual = get_parent().get_node_or_null("ShieldVisual") as Node2D
	
	# Disable shield visual by default
	if _shield_visual != null:
		_shield_visual.visible = false


func _physics_process(_delta: float) -> void:
	if _entity == null or _shield_def == null:
		return
	
	# Only handle blocking for active shields
	if _shield_def.shield_type != ShieldItemDef.ShieldType.ACTIVE:
		return
	
	# Get control source to check for block input
	var control: ControlSource = _entity.find_component(&"ControlSource") as ControlSource
	if control == null:
		return
	
	var wants_block: bool = control.wants_block()
	
	if wants_block and not _is_blocking:
		# Trigger Block state
		if _entity.state_machine != null:
			_entity.state_machine.change_state("Block")
	elif not wants_block and _is_blocking:
		# Exit block state
		if _entity.state_machine != null:
			_entity.state_machine.change_state("Idle")


func set_shield_def(def: ShieldItemDef) -> void:
	"""Set the shield definition when equipped"""
	if def == null or def.shield_type != ShieldItemDef.ShieldType.ACTIVE:
		if _is_blocking:
			stop_blocking()
		_shield_def = null
		return
	
	_shield_def = def


func start_blocking() -> void:
	if _shield_def == null or _is_blocking:
		return
	
	print("[ActiveShield] Started blocking")
	_is_blocking = true
	
	# Show shield visual
	if _shield_visual != null:
		_shield_visual.visible = true
	
	# Apply movement penalty and damage reduction
	var stats: Stats = _entity.find_component(&"Stats") as Stats
	if stats != null:
		stats.set_move_speed_mult(&"shield_block", _shield_def.movement_speed_mult_while_blocking)
		stats.set_flat_damage_reduction(&"shield_block", _shield_def.block_damage_reduction)
	
	blocking_started.emit()


func stop_blocking() -> void:
	if not _is_blocking:
		return
	
	print("[ActiveShield] Stopped blocking")
	_is_blocking = false
	
	# Hide shield visual
	if _shield_visual != null:
		_shield_visual.visible = false
	
	# Remove movement penalty
	var stats: Stats = _entity.find_component(&"Stats") as Stats
	if stats != null:
		stats.clear_move_speed_mult(&"shield_block")
		stats.clear_flat_damage_reduction(&"shield_block")
	
	blocking_stopped.emit()


func is_blocking() -> bool:
	return _is_blocking


func get_block_damage_reduction() -> float:
	if _shield_def != null:
		return _shield_def.block_damage_reduction
	return 0.0

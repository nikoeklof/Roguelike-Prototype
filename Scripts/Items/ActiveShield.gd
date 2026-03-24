extends Node
class_name ActiveShield

signal blocking_started
signal blocking_stopped

@export_node_path("Node2D") var shield_visual_path: NodePath  # Visual representation of shield

var _entity: Entity
var _is_blocking: bool = false
var _shield_def: ShieldItemDef
var _shield_visual: Node2D
var _block_collider: Area2D  # Collider for blocking projectiles


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
	if _entity == null:
		return
	
	# Check for block input
	var control: ControlSource = _entity.get_node_or_null("ControlSource") as ControlSource
	if control != null:
		var is_block_pressed = control.is_blocking()
		
		if is_block_pressed and not _is_blocking:
			start_blocking()
		elif not is_block_pressed and _is_blocking:
			stop_blocking()


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
	
	print("[ActiveShield] Player started blocking")
	_is_blocking = true
	
	# Show shield visual
	if _shield_visual != null:
		_shield_visual.visible = true
	
	# Apply movement penalty
	var stats: Stats = _entity.find_component(&"Stats") as Stats
	if stats != null:
		stats.set_move_speed_mult(&"shield_block", _shield_def.movement_speed_mult_while_blocking)
	
	# Apply damage reduction
	if stats != null:
		stats.set_flat_damage_reduction(&"shield_block", _shield_def.block_damage_reduction)
	
	blocking_started.emit()


func stop_blocking() -> void:
	if not _is_blocking:
		return
	
	print("[ActiveShield] Player stopped blocking")
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

extends Node
class_name ActiveShield

signal blocking_started
signal blocking_stopped

@export_node_path("Node2D") var shield_visual_path: NodePath

var _entity: Entity
var _is_blocking: bool = false
var _shield_def: ShieldItemDef
var _shield_visual: Node2D
var _active_blocking_collider: Node = null


func _ready() -> void:
	_entity = get_parent() as Entity
	if _entity == null:
		print("[ActiveShield] ERROR: Parent is not an Entity")
		return
	
	if shield_visual_path != NodePath():
		_shield_visual = get_node_or_null(shield_visual_path) as Node2D
	
	if _shield_visual == null:
		_shield_visual = get_parent().get_node_or_null("ShieldVisual") as Node2D
	
	if _shield_visual != null:
		_shield_visual.visible = false


func _physics_process(_delta: float) -> void:
	if _entity == null or _shield_def == null:
		return
	
	if _shield_def.shield_type != ShieldItemDef.ShieldType.ACTIVE:
		return
	
	var control: ControlSource = _entity.find_component(&"ControlSource") as ControlSource
	if control == null:
		return
	
	var wants_block: bool = control.wants_block()
	
	if wants_block and not _is_blocking:
		if _entity.state_machine != null:
			_entity.state_machine.change_state("Block")
		_is_blocking = true
	
	elif not wants_block and _is_blocking:
		if _entity.state_machine != null:
			_entity.state_machine.change_state("Idle")
		_is_blocking = false


func set_shield_def(def: ShieldItemDef) -> void:
	"""Set the shield definition when equipped"""
	if def == null or def.shield_type != ShieldItemDef.ShieldType.ACTIVE:
		_shield_def = null
		return
	
	print("[ActiveShield] Shield equipped: %s" % def.display_name)
	_shield_def = def


func on_block_start() -> void:
	"""Called when Block state is entered"""
	if _shield_def == null:
		return
	
	print("[ActiveShield] Block started")
	_is_blocking = true
	
	if _shield_visual != null:
		_shield_visual.visible = true
	
	_create_blocking_collider()
	
	var stats: Stats = _entity.find_component(&"Stats") as Stats
	if stats != null:
		stats.set_move_speed_mult(&"shield_block", _shield_def.movement_speed_mult_while_blocking)
		stats.set_flat_damage_reduction(&"shield_block", _shield_def.flat_damage_reduction)
	
	blocking_started.emit()


func on_block_end() -> void:
	"""Called when Block state is exited"""
	if not _is_blocking:
		return
	
	print("[ActiveShield] Block ended")
	_is_blocking = false
	
	if _shield_visual != null:
		_shield_visual.visible = false
	
	if _active_blocking_collider != null and is_instance_valid(_active_blocking_collider):
		_active_blocking_collider.queue_free()
		_active_blocking_collider = null
	
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


func _create_blocking_collider() -> void:
	"""Create blocking collider for this active shield"""
	if _shield_def == null:
		return
	
	if _active_blocking_collider != null and is_instance_valid(_active_blocking_collider):
		_active_blocking_collider.queue_free()
	
	var parent := _entity.get_node_or_null("FacingPointer/AimRay") as Node2D
	if parent == null:
		parent = _entity as Node2D
	
	var pc := ParryCollider.new()
	pc.name = "ActiveShieldBlockCollider"
	pc.reflect = false
	pc.reflect_speed_mult = 1.0
	
	parent.add_child(pc)
	pc.position = Vector2.ZERO
	pc.rotation = 0.0
	pc.setup(
		_entity,
		_shield_def.blocking_collider_size,
		_shield_def.blocking_collider_offset,
		_shield_def.blocking_collider_duration,
		false
	)
	
	_active_blocking_collider = pc
	print("[ActiveShield] Blocking collider created")

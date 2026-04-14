extends Node
class_name ActiveShield

signal blocking_started
signal blocking_stopped
signal shield_hp_changed(current: float, max_hp: float)
signal shield_broken
signal shield_restored

@export_node_path("Node2D") var shield_visual_path: NodePath

var _entity: Entity
var _is_blocking: bool = false
var _shield_def: ShieldItemDef
var _shield_visual: Node2D
var _active_blocking_collider: Node = null

# Shield HP
var _shield_hp: float = 0.0
var _shield_max_hp: float = 0.0
var _regen_timer: float = 0.0
var _is_broken: bool = false


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


func _physics_process(delta: float) -> void:
	if _entity == null or _shield_def == null:
		return

	if _shield_def.shield_type != ShieldItemDef.ShieldType.ACTIVE:
		return

	# Shield HP regeneration (only when not actively blocking)
	if not _is_blocking and _shield_max_hp > 0.0:
		if _regen_timer > 0.0:
			_regen_timer = maxf(_regen_timer - delta, 0.0)
		elif _shield_hp < _shield_max_hp:
			_shield_hp = minf(_shield_hp + _shield_def.shield_regen_rate * delta, _shield_max_hp)
			shield_hp_changed.emit(_shield_hp, _shield_max_hp)
			if _is_broken and _shield_hp >= _shield_max_hp:
				_is_broken = false
				shield_restored.emit()
				print("[ActiveShield] Shield restored")

	var control: ControlSource = _entity.find_component(&"ControlSource") as ControlSource
	if control == null:
		return

	var wants_block: bool = control.wants_block()

	if wants_block and not _is_blocking and not _is_broken:
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
	_init_shield_hp()


func on_block_start() -> void:
	"""Called when Block state is entered"""
	if _shield_def == null:
		return

	if _is_broken:
		print("[ActiveShield] Block refused — shield is broken")
		return

	print("[ActiveShield] Block started")
	_is_blocking = true
	
	if _shield_visual != null:
		_shield_visual.visible = true
	
	# Create persistent blocking collider
	_create_blocking_collider()
	
	# Apply movement penalty and damage reduction
	var stats: Stats = _entity.find_component(&"Stats") as Stats
	if stats != null:
		stats.set_move_speed_mult(&"shield_block", _shield_def.movement_speed_mult_while_blocking)
		stats.set_flat_damage_reduction(&"shield_block", _shield_def.flat_damage_reduction)
		print("[ActiveShield] Applied blocking penalties")
	
	blocking_started.emit()


func on_block_end() -> void:
	"""Called when Block state is exited"""
	if not _is_blocking:
		return
	
	print("[ActiveShield] Block ended")
	_is_blocking = false
	
	if _shield_visual != null:
		_shield_visual.visible = false
	
	# Remove blocking collider
	if _active_blocking_collider != null and is_instance_valid(_active_blocking_collider):
		_active_blocking_collider.queue_free()
		_active_blocking_collider = null
	
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


func is_broken() -> bool:
	return _is_broken


func get_shield_hp() -> float:
	return _shield_hp


func get_shield_max_hp() -> float:
	return _shield_max_hp


func consume_shield_hp(damage: float) -> void:
	"""Called by ParryCollider each time a hit is absorbed."""
	if _shield_max_hp <= 0.0:
		return  # HP system disabled — infinite shield
	_shield_hp = maxf(0.0, _shield_hp - damage)
	_regen_timer = _shield_def.shield_regen_delay
	shield_hp_changed.emit(_shield_hp, _shield_max_hp)
	print("[ActiveShield] Shield took %.1f damage, HP: %.1f/%.1f" % [damage, _shield_hp, _shield_max_hp])
	if _shield_hp <= 0.0:
		_break_shield()


func _break_shield() -> void:
	print("[ActiveShield] Shield broken!")
	_is_broken = true
	on_block_end()
	shield_broken.emit()
	if _entity != null and _entity.state_machine != null:
		_entity.state_machine.change_state("Idle")


func _init_shield_hp() -> void:
	if _shield_def == null:
		return
	_shield_max_hp = _shield_def.shield_max_hp
	_shield_hp = _shield_max_hp
	_is_broken = false
	_regen_timer = 0.0
	shield_hp_changed.emit(_shield_hp, _shield_max_hp)


func _create_blocking_collider() -> void:
	"""Create blocking collider that persists while holding block (no duration limit)"""
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
	
	# Use VERY LONG duration so it lasts as long as block is held
	# It will be removed in on_block_end()
	var long_duration: float = 999999.0
	pc.setup(
		_entity,
		_shield_def.blocking_collider_size,
		_shield_def.blocking_collider_offset,
		long_duration,
		false
	)
	
	_active_blocking_collider = pc
	print("[ActiveShield] Blocking collider created (persistent)")

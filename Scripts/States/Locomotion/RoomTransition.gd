extends State
class_name RoomTransition

@export_range(0.5, 2.5, 0.1) var speed_mult: float = 1.25
@export_range(2.0, 20.0, 1.0) var arrival_distance: float = 7.0

const BLOCK_REASON: StringName = &"room_transition"

var _target_position: Vector2 = Vector2.ZERO
var _mover: Mover = null
var _capabilities: Capabilities = null


func enter(msg: Dictionary = {}) -> void:
	if entity == null or not msg.has("target_position"):
		state_handler.change_state("Idle")
		return
	_target_position = msg["target_position"]
	_mover = entity.find_component(&"Mover") as Mover
	_capabilities = entity.find_component(&"Capabilities") as Capabilities
	if _capabilities != null:
		_capabilities.block(Capabilities.CAN_ATTACK, BLOCK_REASON)
		_capabilities.block(Capabilities.CAN_CAST, BLOCK_REASON)


func physics_update(delta: float) -> void:
	var body := entity as CharacterBody2D
	if body == null or _mover == null:
		state_handler.change_state("Idle")
		return

	var offset: Vector2 = _target_position - body.global_position
	if offset.length() <= arrival_distance:
		_mover.intent = Vector2.ZERO
		_mover.apply(body, delta)
		if body.velocity.length() <= 12.0:
			state_handler.change_state("Idle")
		return

	var intent_scale: float = minf(1.0, offset.length() / 72.0) * speed_mult
	_mover.intent = offset.normalized() * intent_scale
	_mover.apply(body, delta)


func exit() -> void:
	if _mover != null:
		_mover.intent = Vector2.ZERO
	if _capabilities != null:
		_capabilities.unblock(Capabilities.CAN_ATTACK, BLOCK_REASON)
		_capabilities.unblock(Capabilities.CAN_CAST, BLOCK_REASON)
	_mover = null
	_capabilities = null

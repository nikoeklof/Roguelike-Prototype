extends State
class_name Attack

var _combat: Combat = null
var _controls: ControlSource = null
var _mover: Mover = null
var _attack_kind: Combat.AttackKind = Combat.AttackKind.NONE
var _ai_initiated: bool = false
var _ai_aim_dir: Vector2 = Vector2.ZERO
var _ai_aim_pos: Vector2 = Vector2.ZERO


func enter(_msg: Dictionary = {}) -> void:
	"""
	Enter the Attack state.

	If incoming message contains 'attack_kind' (AI-initiated), prefer that and use stored aim_dir/aim_pos.
	This removes reliance on transient Control pressed frames.
	"""
	_combat = _get_combat()
	_controls = _get_control()
	_mover = _get_mover()
	_attack_kind = Combat.AttackKind.NONE
	_ai_initiated = false
	_ai_aim_dir = Vector2.ZERO
	_ai_aim_pos = Vector2.ZERO

	# Prefer explicit attack_kind from the state change message (from AI).
	if _msg.has("attack_kind"):
		@warning_ignore("int_as_enum_without_cast")
		_attack_kind = int(_msg["attack_kind"])
		_ai_initiated = bool(_msg.get("from_ai", false))
		if _msg.has("aim_dir"):
			_ai_aim_dir = _msg["aim_dir"]
		if _msg.has("aim_pos"):
			_ai_aim_pos = _msg["aim_pos"]
		print("[Attack] enter: AI-initiated attack kind=", _attack_kind, " entity=", entity, " aim_dir=", _ai_aim_dir, " aim_pos=", _ai_aim_pos)
	else:
		_resolve_attack_kind()
		print("[Attack] enter: resolved kind=", _attack_kind, " entity=", entity)

	_try_fire_now()


func physics_update(delta: float) -> void:
	if _controls == null:
		state_handler.change_state("Idle")
		return

	_apply_movement(delta)

	if _combat == null:
		state_handler.change_state("Idle")
		return

	if _attack_kind == Combat.AttackKind.NONE:
		state_handler.change_state("Idle")
		return

	if not _is_attack_still_held_for_kind(_attack_kind):
		_transition_after_attack_release()
		return

	# If AI-initiated and we have stored aim, use that, otherwise use controls.
	var aim_dir: Vector2 = Vector2.RIGHT
	if _ai_initiated and _ai_aim_dir != Vector2.ZERO:
		aim_dir = _ai_aim_dir
	elif _controls != null:
		aim_dir = _controls.aim_dir(Vector2.RIGHT)

	_combat.try_attack(_attack_kind, aim_dir)


func exit() -> void:
	_combat = null
	_controls = null
	_mover = null
	_attack_kind = Combat.AttackKind.NONE
	_ai_initiated = false
	_ai_aim_dir = Vector2.ZERO
	_ai_aim_pos = Vector2.ZERO


func _apply_movement(delta: float) -> void:
	var body: CharacterBody2D = _get_body()
	if body == null:
		return

	if _controls == null:
		return

	var move_input: Vector2 = _controls.move_intent()

	# Always use Mover - it handles both acceleration and friction
	if _mover != null:
		_mover.intent = move_input
		_mover.apply(body, delta)


func _resolve_attack_kind() -> void:
	# This only runs when we didn't receive an explicit attack_kind message.
	if _controls == null:
		_attack_kind = Combat.AttackKind.NONE
		return

	var pressed_kind: Combat.AttackKind = _controls.attack_kind_pressed()
	if pressed_kind != Combat.AttackKind.NONE:
		_attack_kind = pressed_kind
		return

	var peek_kind: Combat.AttackKind = _controls.attack_kind_peek()
	if peek_kind != Combat.AttackKind.NONE:
		_attack_kind = peek_kind
		return

	_attack_kind = Combat.AttackKind.NONE


func _try_fire_now() -> void:
	if _combat == null:
		return

	if _attack_kind == Combat.AttackKind.NONE:
		return

	# Prefer AI-provided aim if present
	var aim_dir: Vector2 = Vector2.RIGHT
	if _ai_initiated and _ai_aim_dir != Vector2.ZERO:
		aim_dir = _ai_aim_dir
	elif _controls != null:
		aim_dir = _controls.aim_dir(Vector2.RIGHT)

	_combat.try_attack(_attack_kind, aim_dir)


func _is_attack_still_held_for_kind(kind: Combat.AttackKind) -> bool:
	if _controls == null:
		return false

	# If the attack was AI-initiated, still check Control.attack_is_down so
	# the attack release semantics remain consistent with player input.
	if not _controls.attack_is_down():
		return false

	var held_kind: Combat.AttackKind = _controls.attack_kind_held()
	if held_kind != Combat.AttackKind.NONE:
		return held_kind == kind

	# If attack_kind_held is NONE but attack_is_down is true, conservatively treat as still held.
	return true


func _transition_after_attack_release() -> void:
	if _controls == null:
		state_handler.change_state("Idle")
		return

	var move_input: Vector2 = _controls.move_intent()
	if move_input != Vector2.ZERO:
		state_handler.change_state("Walk")
	else:
		state_handler.change_state("Idle")


func _get_control() -> ControlSource:
	if entity == null:
		return null

	return entity.get_node_or_null("ControlSource") as ControlSource


func _get_combat() -> Combat:
	if entity == null:
		return null

	return entity.get_node_or_null("Combat") as Combat


func _get_mover() -> Mover:
	if entity == null:
		return null

	return entity.get_node_or_null("Mover") as Mover


func _get_body() -> CharacterBody2D:
	return entity as CharacterBody2D

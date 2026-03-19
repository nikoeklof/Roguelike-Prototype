extends State
class_name Attack

var _combat: Combat = null
var _controls: ControlSource = null
var _mover: Mover = null
var _attack_kind: Combat.AttackKind = Combat.AttackKind.NONE


func enter(_msg: Dictionary = {}) -> void:
	_combat = _get_combat()
	_controls = _get_control()
	_mover = _get_mover()
	_attack_kind = Combat.AttackKind.NONE

	_resolve_attack_kind()
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

	var aim_dir: Vector2 = _controls.aim_dir(Vector2.RIGHT)
	_combat.try_attack(_attack_kind, aim_dir)


func exit() -> void:
	_combat = null
	_controls = null
	_mover = null
	_attack_kind = Combat.AttackKind.NONE


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
	if _combat == null or _controls == null:
		return

	if _attack_kind == Combat.AttackKind.NONE:
		return

	var aim_dir: Vector2 = _controls.aim_dir(Vector2.RIGHT)
	_combat.try_attack(_attack_kind, aim_dir)


func _is_attack_still_held_for_kind(kind: Combat.AttackKind) -> bool:
	if _controls == null:
		return false

	if not _controls.attack_is_down():
		return false

	var held_kind: Combat.AttackKind = _controls.attack_kind_held()
	if held_kind != Combat.AttackKind.NONE:
		return held_kind == kind

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

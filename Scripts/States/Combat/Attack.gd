extends State

# Weapon/spell decides movement policy for the attack.
# (This export remains only so existing scenes don't break; it's ignored.)
@export var stop_movement := true
@export var melee_damage: float = 1.0

var _blocked_move := false


func _get_control() -> ControlSource:
	# Prefer resolver if present
	var control := entity.find_component(&"ControlSource") as ControlSource
	if control: return control

	# Standard node name
	control = entity.get_node_or_null("ControlSource") as ControlSource
	if control: return control

	# Legacy fallback
	return entity.get_node_or_null("Control") as ControlSource


func _get_mover() -> Mover:
	var m := entity.find_component(&"Mover") as Mover
	if m: return m
	return entity.get_node_or_null("Mover") as Mover


func enter() -> void:
	var control := _get_control()
	if control == null:
		push_warning("Attack state requires ControlSource component.")
		state_handler.change_state("Idle")
		return

	var combat := entity.get_node_or_null("Combat") as Combat
	if combat == null:
		push_warning("Attack state requires Combat node.")
		state_handler.change_state("Idle")
		return

	var kind := control.attack_kind_pressed()
	if kind == Combat.AttackKind.NONE:
		state_handler.change_state("Idle")
		return

	# Movement policy comes from the weapon/spell for this kind.
	var allow_move := combat.allows_movement_for(kind)

	# Capabilities: lock switch/attack always. Lock move only if weapon/spell disallows movement.
	var caps := entity.get_node_or_null("Capabilities") as Capabilities
	if caps:
		_blocked_move = not allow_move
		if _blocked_move:
			caps.block(Capabilities.CAN_MOVE, &"attack")
		caps.block(Capabilities.CAN_SWITCH, &"attack")
		caps.block(Capabilities.CAN_ATTACK, &"attack") # prevents re-entry spam

	var fp := entity.get_node_or_null("FacingPointer") as FacingPointer
	var fallback := fp.facing_vector if fp else Vector2.RIGHT
	var dir := control.attack_dir(fallback)

	# During attack, face the attack direction (eg. mouse aim)
	if fp:
		fp.set_manual_facing(dir)

	# Connect BEFORE try_attack so instant-finish attacks can't be missed
	var cb := Callable(self, "_on_attack_finished")
	if not combat.attack_finished.is_connected(cb):
		combat.attack_finished.connect(cb, CONNECT_ONE_SHOT)

	if not combat.try_attack(kind, dir):
		# Undo connection we made, since nothing started.
		if combat.attack_finished.is_connected(cb):
			combat.attack_finished.disconnect(cb)

		if fp:
			fp.clear_manual_facing()

		_exit_unlocks()
		state_handler.change_state("Idle")
		return


func physics_update(delta: float) -> void:
	# Always run mover so friction applies.
	# If CAN_MOVE is blocked, Mover ignores input but preserves momentum and decelerates by friction.
	var mover := _get_mover()
	if mover:
		mover.apply(entity, delta)


func exit() -> void:
	var fp := entity.get_node_or_null("FacingPointer") as FacingPointer
	if fp:
		fp.clear_manual_facing()

	var combat := entity.get_node_or_null("Combat") as Combat
	if combat:
		# Ensure we don't leave stale connections around if state changes early
		var cb := Callable(self, "_on_attack_finished")
		if combat.attack_finished.is_connected(cb):
			combat.attack_finished.disconnect(cb)

	_exit_unlocks()

	# NOTE: combat.stop_all() was referenced in your project but may not exist yet.
	# Leave it out here to avoid "method not found" until we implement the Combat cleanup contract.
	# combat.stop_all()


func _exit_unlocks() -> void:
	var caps := entity.get_node_or_null("Capabilities") as Capabilities
	if caps:
		if _blocked_move:
			caps.unblock(Capabilities.CAN_MOVE, &"attack")
		caps.unblock(Capabilities.CAN_SWITCH, &"attack")
		caps.unblock(Capabilities.CAN_ATTACK, &"attack")
	_blocked_move = false


func _on_attack_finished(_kind: int) -> void:
	# Optional nicer feel: if still moving, go Walk
	var control := _get_control()
	if control and control.move_intent() != Vector2.ZERO:
		state_handler.change_state("Walk")
	else:
		state_handler.change_state("Idle")

extends State

func _get_control() -> ControlSource:
	var c := entity.find_component(&"ControlSource") as ControlSource
	if c: return c
	c = entity.get_node_or_null("ControlSource") as ControlSource
	if c: return c
	return entity.get_node_or_null("Control") as ControlSource # legacy fallback


func _get_mover() -> Mover:
	var m := entity.find_component(&"Mover") as Mover
	if m: return m
	return entity.get_node_or_null("Mover") as Mover


func physics_update(delta: float) -> void:
	var control := _get_control()
	if control == null:
		return

	# Attack is a one-shot trigger now
	if control.attack_pressed():
		state_handler.change_state("Attack")
		return

	var intent := control.move_intent()
	if intent != Vector2.ZERO:
		state_handler.change_state("Walk")
		return

	# Crucial: apply friction / deceleration while idle
	var mover := _get_mover()
	if mover:
		mover.intent = Vector2.ZERO
		mover.apply(entity, delta)

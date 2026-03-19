extends State
class_name Idle


func physics_update(delta: float) -> void:
	var control: ControlSource = _get_control()
	if control == null:
		return

	if control.attack_pressed():
		state_handler.change_state("Attack")
		return

	var intent: Vector2 = control.move_intent()
	if intent != Vector2.ZERO:
		state_handler.change_state("Walk")
		return

	# Use Mover to decelerate with friction instead of forcing velocity to zero
	var mover: Mover = _get_mover()
	var body: CharacterBody2D = _get_body()

	if mover != null and body != null:
		mover.intent = Vector2.ZERO  # Zero intent = friction applies
		mover.apply(body, delta)


func _get_control() -> ControlSource:
	if entity == null:
		return null

	return entity.get_node_or_null("ControlSource") as ControlSource


func _get_mover() -> Mover:
	if entity == null:
		return null

	return entity.get_node_or_null("Mover") as Mover


func _get_body() -> CharacterBody2D:
	return entity as CharacterBody2D

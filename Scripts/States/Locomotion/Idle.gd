extends State
class_name Idle


func enter(_msg: Dictionary = {}) -> void:
	pass


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

	var body: CharacterBody2D = _get_body()
	if body == null:
		return

	body.velocity.x = move_toward(body.velocity.x, 0.0, 2000.0 * delta)
	body.velocity.y = move_toward(body.velocity.y, 0.0, 2000.0 * delta)


func _get_control() -> ControlSource:
	if entity == null:
		return null

	return entity.get_node_or_null("ControlSource") as ControlSource


func _get_body() -> CharacterBody2D:
	return entity as CharacterBody2D

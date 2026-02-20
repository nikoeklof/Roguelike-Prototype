extends State

@export var duration_sec: float = 0.25
@export var stop_movement: bool = true

var _t := 0.0

func enter() -> void:
	_t = 0.0
	if stop_movement:
		entity.velocity = Vector2.ZERO

	# Play shader flash if component exists
	var flash := entity.get_node_or_null("HurtFlash") as HurtFlash
	if flash:
		flash.play(duration_sec)

	# Optional: play hurt animation
	var anim := entity.get_node_or_null("AnimDriver") as AnimDriver
	if anim:
		anim.request("hurt", duration_sec, 50)

func physics_update(delta: float) -> void:
	_t += delta
	if _t >= duration_sec:
		entity.state_machine.change_state("Idle")

extends State
class_name Hurt

@export var duration_sec: float = 0.25
@export var stop_movement: bool = true

var _t: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	
	_t = 0.0

	if stop_movement and entity != null:
		entity.velocity = Vector2.ZERO

	var flash: HurtFlash = null
	if entity != null:
		flash = entity.get_node_or_null("HurtFlash") as HurtFlash

		
	if flash != null:
		flash.play(duration_sec)

	var anim: AnimDriver = null
	if entity != null:
		anim = entity.get_node_or_null("AnimDriver") as AnimDriver
	if anim != null:
		anim.request("hurt", duration_sec, 50)


func physics_update(delta: float) -> void:
	_t += delta
	if _t >= duration_sec and state_handler != null:
		state_handler.change_state("Idle")

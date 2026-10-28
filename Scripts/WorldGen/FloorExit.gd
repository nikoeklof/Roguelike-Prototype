extends Area2D
class_name FloorExit

var _transition_started: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 22.0, Color(0.08, 0.7, 0.72, 0.35))
	draw_arc(Vector2.ZERO, 29.0, 0.0, TAU, 40, Color(0.35, 0.95, 0.88, 0.95), 4.0, true)
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 32, Color(0.65, 1.0, 0.92, 0.8), 2.0, true)


func _on_body_entered(body: Node) -> void:
	if _transition_started or not body.is_in_group("player"):
		return
	_transition_started = true
	set_deferred("monitoring", false)
	GameManager.advance_floor()

extends StaticBody2D
class_name ParryCollider

@export var duration_sec: float = 0.15
@export var reflect: bool = false
@export var reflect_speed_mult: float = 1.0

var _owner: Node = null


func setup(owner_entity: Node, shape_size: Vector2, local_offset: Vector2, duration: float, do_reflect: bool) -> void:
	_owner = owner_entity
	duration_sec = duration
	reflect = do_reflect

	var cs: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = shape_size
	cs.shape = rect
	cs.position = local_offset
	add_child(cs)

	var t: Timer = Timer.new()
	t.one_shot = true
	t.wait_time = maxf(0.01, duration_sec)
	add_child(t)
	t.timeout.connect(Callable(self, "_on_lifetime_timeout"), CONNECT_ONE_SHOT)
	t.start()


func _on_lifetime_timeout() -> void:
	queue_free()


func on_projectile_hit(p: Projectile) -> bool:
	if p == null:
		return false

	if reflect:
		p.velocity = -p.velocity * maxf(0.01, reflect_speed_mult)
		p.set_projectile_owner(_owner)
		return true

	p.queue_free()
	return true

extends Area2D
class_name Projectile

var velocity: Vector2 = Vector2.ZERO
var _gravity: float = 0.0
var lifetime_sec: float = 2.0
var damage: int = 1
var pierce: int = 0

var _owner: Node = null
var _age: float = 0.0
var _hits: int = 0


func _ready() -> void:
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func setup(v: Vector2, g: float, life: float, dmg: int, prc: int, own: Node) -> void:
	velocity = v
	_gravity = g
	lifetime_sec = life
	damage = dmg
	pierce = prc
	_owner = own


func get_projectile_owner() -> Node:
	return _owner


func set_projectile_owner(new_owner: Node) -> void:
	_owner = new_owner


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime_sec:
		queue_free()
		return

	velocity.y += _gravity * delta
	global_position += velocity * delta

	if velocity.length() > 0.01:
		rotation = velocity.angle()


func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if body == _owner:
		return

	if body.has_method(&"on_projectile_hit"):
		var res: Variant = body.call(&"on_projectile_hit", self)
		if res is bool and bool(res):
			return

	var target_health: Health = null
	if body is Entity:
		target_health = (body as Entity).find_component(&"Health") as Health
	else:
		var h_node: Node = body.get_node_or_null("Health")
		if h_node is Health:
			target_health = h_node as Health

	if target_health != null:
		target_health.take_damage(damage, _owner)

	_hits += 1
	if _hits > pierce:
		queue_free()

extends Area2D
class_name Projectile

@export var velocity: Vector2 = Vector2.ZERO
@export var _gravity: float = 0.0
@export var lifetime_sec: float = 2.0
@export var damage: int = 1
@export var pierce: int = 0

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

	# Interception hook (parry/reflect)
	if body.has_method(&"on_projectile_hit"):
		var res: Variant = body.call(&"on_projectile_hit", self)
		if res is bool and bool(res):
			return

	# Faction check
	if _owner != null:
		var owner_faction: Faction = null
		if _owner is Entity:
			owner_faction = (_owner as Entity).find_component(&"Faction") as Faction
		else:
			var f := _owner.get_node_or_null("Faction")
			if f is Faction:
				owner_faction = f as Faction

		if owner_faction != null and not owner_faction.can_damage(body):
			return

	# Apply damage
	var target_health: Health = null
	if body is Entity:
		target_health = (body as Entity).find_component(&"Health") as Health
	else:
		var h := body.get_node_or_null("Health")
		if h is Health:
			target_health = h as Health

	if target_health != null:
		target_health.take_damage(damage, _owner)

	_hits += 1
	if _hits > pierce:
		queue_free()

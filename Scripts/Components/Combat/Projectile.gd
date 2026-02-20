extends Area2D
class_name Projectile

@export var velocity: Vector2 = Vector2.ZERO
@export var _gravity := 0.0
@export var lifetime_sec := 2.0
@export var damage := 1
@export var pierce := 0

var _owner: Node = null
var _age := 0.0
var _hits := 0

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

	# ---- FACTION CHECK ----
	if _owner != null:
		var owner_faction: Faction = null
		var owner_ent := _owner as Entity
		if owner_ent != null:
			owner_faction = owner_ent.find_component(&"Faction") as Faction
		else:
			owner_faction = _owner.get_node_or_null("Faction") as Faction

		if owner_faction != null and not owner_faction.can_damage(body):
			return

	# ---- APPLY DAMAGE ----
	var target_health: Health = null
	var target_ent := body as Entity
	if target_ent != null:
		target_health = target_ent.find_component(&"Health") as Health
	else:
		target_health = body.get_node_or_null("Health") as Health

	if target_health:
		target_health.take_damage(damage, _owner)

	_hits += 1
	if _hits > pierce:
		queue_free()

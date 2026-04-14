extends Area2D
class_name ParryCollider

@export var duration_sec: float = 0.15
@export var reflect: bool = false
@export var reflect_speed_mult: float = 1.0

var _owner: Node = null
var _collision_shape: CollisionShape2D


func setup(owner_entity: Node, shape_size: Vector2, local_offset: Vector2, duration: float, do_reflect: bool) -> void:
	_owner = owner_entity
	duration_sec = duration
	reflect = do_reflect

	# Create collision shape
	_collision_shape = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = shape_size
	_collision_shape.shape = rect
	_collision_shape.position = local_offset
	add_child(_collision_shape)

	# Configure Area2D for detection
	monitoring = false  # Don't check collisions actively
	monitorable = true  # Allow others to detect us

	# Layer 6 (value 32) — "Shield". Projectiles use mask 0x7FFFFFFF so they
	# overlap us automatically. Raycasts with collide_with_areas=true also hit us.
	collision_layer = 32
	collision_mask = 0

	print("[ParryCollider] Setup: size=%s, offset=%s, duration=%.2fs, reflect=%s" % [shape_size, local_offset, duration_sec, do_reflect])

	# Set lifetime
	var t: Timer = Timer.new()
	t.one_shot = true
	t.wait_time = maxf(0.01, duration_sec)
	add_child(t)
	t.timeout.connect(Callable(self, "_on_lifetime_timeout"), CONNECT_ONE_SHOT)
	t.start()


func get_owner_entity() -> Node:
	return _owner


func on_shot_blocked(damage: float, attacker: Node = null) -> void:
	print("[ParryCollider] Hitscan blocked by shield (%.1f dmg, reflect=%s)" % [damage, str(reflect)])
	_notify_shield_damage(damage)
	if reflect and attacker != null:
		_reflect_damage_to_attacker(damage, attacker)


func _on_lifetime_timeout() -> void:
	print("[ParryCollider] Lifetime expired, removing collider")
	queue_free()


func on_projectile_hit(p: Projectile) -> bool:
	if p == null:
		return false

	var absorbed_damage: float = p.damage

	if reflect:
		print("[ParryCollider] Reflecting projectile")
		p.velocity = -p.velocity * maxf(0.01, reflect_speed_mult)
		p.set_projectile_owner(_owner)
	else:
		print("[ParryCollider] Destroying projectile")
		p.queue_free()

	_notify_shield_damage(absorbed_damage)
	return true


func _notify_shield_damage(damage: float) -> void:
	if _owner == null:
		return
	var active_shield: ActiveShield
	if _owner is Entity:
		active_shield = (_owner as Entity).find_component(&"ActiveShield") as ActiveShield
	else:
		active_shield = _owner.get_node_or_null("ActiveShield") as ActiveShield
	if active_shield != null:
		active_shield.consume_shield_hp(damage)


func _reflect_damage_to_attacker(damage: float, attacker: Node) -> void:
	var health: Health = null
	if attacker is Entity:
		health = (attacker as Entity).find_component(&"Health") as Health
	else:
		health = attacker.get_node_or_null("Health") as Health
	if health != null:
		health.take_damage(damage, _owner)
		print("[ParryCollider] Reflected %.1f hitscan damage back to %s" % [damage, attacker.name])

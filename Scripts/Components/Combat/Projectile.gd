extends Area2D
class_name Projectile

var velocity: Vector2 = Vector2.ZERO
var _gravity: float = 0.0
var lifetime_sec: float = 2.0
var damage: float = 1.0
var pierce: int = 0

var _owner: Node = null
var _age: float = 0.0
var _distance_travelled: float = 0.0
var _max_range: float = 0.0

var _context: CombatContext = null
var _snapshot: AttackSnapshot = null

var _remaining_hits: int = 1
var _hit_ids: Dictionary = {}


func _ready() -> void:
	monitoring = true
	monitorable = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func setup(
	data_or_velocity: Variant,
	g: float = 0.0,
	life: float = 2.0,
	dmg: int = 1,
	prc: int = 0,
	own: Node = null
) -> void:
	# New universal launch-data path.
	if data_or_velocity is ProjectileLaunchData:
		var launch: ProjectileLaunchData = data_or_velocity as ProjectileLaunchData
		_setup_from_launch(launch)
		return

	# Backwards-compatible legacy path.
	if data_or_velocity is Vector2:
		velocity = data_or_velocity as Vector2
		_gravity = g
		lifetime_sec = life
		damage = float(dmg)
		pierce = prc
		_owner = own
		_remaining_hits = maxi(1, pierce + 1)
		return

	push_warning("Projectile.setup(): unsupported payload.")


func _setup_from_launch(launch: ProjectileLaunchData) -> void:
	if launch == null:
		return

	_context = launch.context
	_snapshot = launch.snapshot
	_owner = launch.owner

	global_position = launch.origin

	var dir: Vector2 = launch.direction
	if dir.length() < 0.001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()

	velocity = launch.velocity
	if velocity.length() < 0.001:
		velocity = dir * 450.0

	_gravity = launch.gravity
	lifetime_sec = max(0.01, launch.lifetime_sec)
	damage = launch.damage
	pierce = maxi(0, launch.pierce)
	_remaining_hits = maxi(1, pierce + 1)
	_max_range = max(0.0, launch.max_range)

	collision_mask = launch.collision_mask

	_apply_radius(max(1.0, launch.radius))
	_apply_visuals(launch.sprite_texture, launch.sprite_tint)

	if velocity.length() > 0.01:
		rotation = velocity.angle()


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

	var step: Vector2 = velocity * delta
	global_position += step
	_distance_travelled += step.length()

	if _max_range > 0.0 and _distance_travelled >= _max_range:
		queue_free()
		return

	if velocity.length() > 0.01:
		rotation = velocity.angle()


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _try_hit(other: Node) -> void:
	if other == null:
		return

	if _owner != null:
		if other == _owner:
			return
		if _owner.is_ancestor_of(other):
			return

	var victim_root: Node = CombatQuery.resolve_victim_root(other)
	if victim_root == null:
		victim_root = other

	var victim_id: int = victim_root.get_instance_id()
	if _hit_ids.has(victim_id):
		return

	var hit_dir: Vector2 = velocity.normalized()
	if hit_dir.length() < 0.001:
		hit_dir = Vector2.RIGHT

	# New unified hit path.
	if _context != null and _snapshot != null:
		var applied: bool = AttackImpactResolver.apply_hit(
			_context,
			_snapshot,
			victim_root,
			other,
			hit_dir,
			damage
		)

		if applied:
			_hit_ids[victim_id] = true
			_remaining_hits -= 1
			if _remaining_hits <= 0:
				queue_free()
			return

	# Legacy fallback.
	var hp: Health = CombatQuery.find_health(victim_root)
	if hp != null and (_owner == null or CombatQuery.can_damage(_owner, victim_root)):
		_hit_ids[victim_id] = true
		hp.take_damage(damage, _owner)
		_remaining_hits -= 1
		if _remaining_hits <= 0:
			queue_free()
		return

	# If it was not a valid victim, treat solid world as an impact.
	if other is PhysicsBody2D or other is TileMap:
		queue_free()


func _apply_radius(radius: float) -> void:
	var root_shape: CollisionShape2D = get_node_or_null("Shape") as CollisionShape2D
	if root_shape != null:
		var circle: CircleShape2D = root_shape.shape as CircleShape2D
		if circle == null:
			circle = CircleShape2D.new()
			root_shape.shape = circle
		circle.radius = radius

	var hitbox_shape: CollisionShape2D = get_node_or_null("Hitbox/HitBoxCollider") as CollisionShape2D
	if hitbox_shape != null:
		var hit_circle: CircleShape2D = hitbox_shape.shape as CircleShape2D
		if hit_circle == null:
			hit_circle = CircleShape2D.new()
			hitbox_shape.shape = hit_circle
		hit_circle.radius = radius
		hitbox_shape.disabled = false

	var sprite: Node2D = get_node_or_null("Hitbox/Sprite2D") as Node2D
	if sprite != null:
		var scale_val: float = max(0.25, radius / 8.0)
		sprite.scale = Vector2.ONE * scale_val


func _apply_visuals(texture: Texture2D, tint: Color) -> void:
	var sprite: Sprite2D = get_node_or_null("Hitbox/Sprite2D") as Sprite2D
	if sprite == null:
		sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return

	sprite.texture = texture
	sprite.modulate = tint
	sprite.visible = true

extends Area2D
class_name PlaceholderProjectile

@export var debug_print: bool = false

# Physics layer bits (your project settings)
const LAYER_WORLD: int = 1 << 0   # Layer 1
const LAYER_HITBOX: int = 1 << 3  # Layer 4
const LAYER_HURTBOX: int = 1 << 4 # Layer 5

var _owner_entity: Node
var _dir: Vector2 = Vector2.RIGHT
var _speed: float = 600.0
var _damage: float = 1.0
var _lifetime: float = 1.5
var _radius: float = 4.0
var _knockback: float = 0.0
var _remaining_hits: int = 1

var _hit_ids: Dictionary = {}
var _age: float = 0.0
var _prev_global_pos: Vector2


func setup(
	owner_entity: Node,
	dir: Vector2,
	damage: float,
	speed: float,
	lifetime: float,
	radius: float,
	knockback: float,
	max_hits: int
) -> void:
	_owner_entity = owner_entity

	_dir = dir
	if _dir.length() < 0.001:
		_dir = Vector2.RIGHT
	else:
		_dir = _dir.normalized()

	_damage = damage
	_speed = speed
	_lifetime = lifetime
	_radius = radius
	_knockback = knockback
	_remaining_hits = max(1, max_hits)


func _ready() -> void:
	monitoring = true
	monitorable = false

	# We ARE a hitbox.
	collision_layer = LAYER_HITBOX

	# We should overlap hurtboxes.
	# World collision will be handled via swept raycast to prevent tunneling.
	collision_mask = LAYER_HURTBOX

	# Shape
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = maxf(1.0, _radius)

	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	_prev_global_pos = global_position


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= _lifetime:
		queue_free()
		return

	# --- Swept collision against World (prevents tunneling) ---
	var from_pos: Vector2 = _prev_global_pos
	var to_pos: Vector2 = from_pos + _dir * _speed * delta

	if _check_world_hit(from_pos, to_pos):
		# _check_world_hit moves us to impact point and frees if needed
		return

	# No wall hit → move
	global_position = to_pos
	_prev_global_pos = global_position


func _check_world_hit(from_pos: Vector2, to_pos: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state

	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.new()
	q.from = from_pos
	q.to = to_pos
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.collision_mask = LAYER_WORLD

	# Exclude self and owner so we don't immediately hit our shooter
	var ex: Array[RID] = [get_rid()]
	if _owner_entity != null and _owner_entity is CollisionObject2D:
		ex.append((_owner_entity as CollisionObject2D).get_rid())
	q.exclude = ex

	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return false

	# Hit world or solid prop: place at impact and die
	var hit_pos: Vector2 = hit.get("position", to_pos)
	global_position = hit_pos
	if debug_print:
		print("[Projectile] hit WORLD at ", hit_pos)

	# Push solid movable props (RigidBody2D on World layer).
	var collider: Object = hit.get("collider")
	if collider != null and collider.has_method(&"receive_projectile_impulse"):
		collider.receive_projectile_impulse(_dir, _knockback)

	queue_free()
	return true


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _try_hit(other: Node) -> void:
	if other == null:
		return
	if _owner_entity == null:
		return

	# Don't hit self or own children
	if other == _owner_entity or _owner_entity.is_ancestor_of(other):
		return

	var victim_root: Node = _resolve_victim_root(other)

	var id: int = victim_root.get_instance_id()
	if _hit_ids.has(id):
		return
	_hit_ids[id] = true

	if not _can_damage(_owner_entity, victim_root):
		return

	var hp: Health = _find_health(victim_root)
	if hp == null:
		return

	var applied: bool = hp.take_damage(_damage, _owner_entity)
	if applied and _knockback > 0.0:
		if victim_root is RigidBody2D:
			var rb := victim_root as RigidBody2D
			rb.apply_central_impulse(_dir * _knockback * rb.mass)
		elif victim_root is CharacterBody2D:
			(victim_root as CharacterBody2D).velocity += _dir * _knockback

	_remaining_hits -= 1
	if debug_print:
		print("[Projectile] hit=", victim_root.name, " remaining=", _remaining_hits)

	if _remaining_hits <= 0:
		queue_free()


func _resolve_victim_root(n: Node) -> Node:
	var cur: Node = n
	for _i in 6:
		if cur == null:
			break
		if cur is Entity:
			return cur
		if _find_health(cur) != null:
			return cur
		cur = cur.get_parent()
	return n


func _find_health(root: Node) -> Health:
	if root == null:
		return null
	if root is Entity:
		var h: Health = (root as Entity).find_component(&"Health") as Health
		if h != null:
			return h
	return root.get_node_or_null("Health") as Health


func _find_faction(root: Node) -> Faction:
	if root == null:
		return null
	if root is Entity:
		var f: Faction = (root as Entity).find_component(&"Faction") as Faction
		if f != null:
			return f
	return root.get_node_or_null("Faction") as Faction


func _can_damage(attacker_root: Node, victim_root: Node) -> bool:
	var src_f: Faction = _find_faction(attacker_root)
	if src_f == null:
		return true
	return src_f.can_damage(victim_root)

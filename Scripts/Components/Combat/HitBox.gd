@tool
extends Area2D
class_name Hitbox

@export_range(0.0, 9999.0, 0.1) var damage: float = 1.0
@export var can_hit_self: bool = false # enable later for bombs/aoe if desired

# LOS: set this to your wall/world collision layer mask in the inspector.
# If 0, LOS check is disabled.
@export_flags_2d_physics var los_block_mask := 0

# Optional: where the LOS ray starts, relative to the source entity.
# Example: ^"VisualRoot/WeaponSocket" to raycast from the weapon.
@export_node_path("Node2D") var los_origin_from_source: NodePath = NodePath("")

var source: Node = null

var _already_hit: Dictionary = {} # entity_root -> true
var _shape: CollisionShape2D = null
var _source_root: Node = null

func _ready() -> void:
	area_entered.connect(_on_area_entered)

	# Find the first CollisionShape2D child (works even if named HitBoxCollider).
	for c in get_children():
		if c is CollisionShape2D:
			_shape = c
			break

	monitoring = false
	monitorable = false
	if _shape:
		_shape.disabled = true


func _get_configuration_warnings() -> PackedStringArray:
	var w: PackedStringArray = []
	if los_origin_from_source != NodePath("") and owner != null:
		# Can't fully validate without a source entity, but we can sanity check relative-to-owner setups.
		if owner.get_node_or_null(los_origin_from_source) == null and not str(los_origin_from_source).begins_with("../"):
			w.append("Hitbox: los_origin_from_source doesn't resolve relative to this Hitbox's owner. (This is optional; leave empty to raycast from entity root.)")
	return w

func begin_swing(dmg: float, src: Node) -> void:
	damage = dmg
	source = src
	_source_root = _find_entity_root(src) if src != null else null
	_already_hit.clear()

	if _shape:
		_shape.disabled = false

	monitoring = true
	monitorable = true

func end_swing() -> void:
	# Deferred avoids "Function blocked during in/out signal" issues.
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if _shape:
		_shape.set_deferred("disabled", true)

	_already_hit.clear()

func _on_area_entered(area: Area2D) -> void:
	# Find target entity root (node that has a child named "Health").
	var target_root := _find_entity_root(area)
	if target_root == null:
		return

	# Never hit ourselves for melee hitboxes (prevents self-damage when overlapping).
	if not can_hit_self and _source_root != null and target_root == _source_root:
		return

	# One hit per swing per target.
	if _already_hit.has(target_root):
		return

	# FACTION CHECK: attacker must be allowed to damage the target.
	if source != null:
		var f := source.get_node_or_null("Faction") as Faction
		if f != null and not f.can_damage(target_root):
			return

	# LOS block (e.g. walls). If ray hits something on los_block_mask, block damage.
	if los_block_mask != 0 and not _has_clear_los(target_root):
		return

	var health := target_root.get_node_or_null("Health") as Health
	if health == null:
		return

	if health.take_damage(damage, source):
		_already_hit[target_root] = true

func _has_clear_los(target_root: Node) -> bool:
	if _source_root == null:
		return true
	if not (_source_root is Node2D) or not (target_root is Node2D):
		return true

	var from := _get_los_origin()
	var to := (target_root as Node2D).global_position

	if from.distance_squared_to(to) < 0.0001:
		return true

	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to, los_block_mask)

	query.collide_with_areas = false
	query.collide_with_bodies = true

	# Exclude attacker and target bodies (so the ray doesn't immediately hit them).
	var exc: Array[RID] = []
	if _source_root is CollisionObject2D:
		exc.append((_source_root as CollisionObject2D).get_rid())
	if target_root is CollisionObject2D:
		exc.append((target_root as CollisionObject2D).get_rid())
	query.exclude = exc

	var hit := space.intersect_ray(query)
	return hit.is_empty()

func _get_los_origin() -> Vector2:
	if los_origin_from_source != NodePath("") and _source_root != null:
		var n := _source_root.get_node_or_null(los_origin_from_source) as Node2D
		if n:
			return n.global_position

	if _source_root is Node2D:
		return (_source_root as Node2D).global_position
	return global_position

func _find_entity_root(n: Node) -> Node:
	var cur: Node = n
	while cur != null:
		# Your entity roots have a child named "Health".
		if cur.get_node_or_null("Health") != null:
			return cur
		cur = cur.get_parent()
	return null

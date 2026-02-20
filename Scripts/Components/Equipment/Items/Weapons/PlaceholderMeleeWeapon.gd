extends Weapon
class_name PlaceholderMeleeWeapon

@export var label: String = "PlaceholderMelee"

# Damage + timings
@export var damage: float = 1.0
@export var windup_time: float = 0.0
@export var active_time: float = 0.10
@export var recovery_time: float = 0.10

# Hitbox geometry (LOCAL to owner; hitbox node is rotated to aim dir)
@export var hitbox_offset: Vector2 = Vector2(18, 0)
@export var hitbox_size: Vector2 = Vector2(26, 18)

# Optional extras
@export var one_hit_per_target: bool = true
@export var knockback: float = 0.0

# Safety
@export_range(0, 64, 1) var max_unique_hits: int = 16

var _hitbox: Area2D
var _hit_ids: Dictionary = {}


func try_attack(dir: Vector2, owner_entity: Node) -> bool:
	if owner_entity == null or not can_attack():
		return false

	_commit_cooldown()

	var d: Vector2 = dir
	if d.length() < 0.001:
		d = Vector2.RIGHT
	else:
		d = d.normalized()

	_run_attack(owner_entity, d)
	return true


func _run_attack(owner_entity: Node, dir: Vector2) -> void:
	if windup_time > 0.0:
		await get_tree().create_timer(windup_time).timeout

	_spawn_hitbox(owner_entity, dir)
	await get_tree().create_timer(maxf(0.01, active_time)).timeout
	_cleanup_hitbox()

	if recovery_time > 0.0:
		await get_tree().create_timer(recovery_time).timeout

	print("[%s] attack_finished" % label)
	attack_finished.emit()


func _spawn_hitbox(owner_entity: Node, dir: Vector2) -> void:
	_hit_ids.clear()

	_hitbox = Area2D.new()
	_hitbox.name = "PlaceholderMeleeHitbox"
	_hitbox.monitoring = true
	_hitbox.monitorable = false

	# Placeholder-friendly default: detect anything.
	_hitbox.collision_layer = 1 << 3 # Hitbox
	_hitbox.collision_mask = 1 << 4  # Hurtbox only

	# ✅ IMPORTANT: local space so it stays attached to the owner as it moves
	_hitbox.position = Vector2.ZERO
	_hitbox.rotation = dir.angle()

	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = hitbox_size

	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.shape = shape
	cs.position = hitbox_offset
	_hitbox.add_child(cs)

	_hitbox.body_entered.connect(func(body: Node) -> void:
		_try_damage(owner_entity, body, dir)
	)
	_hitbox.area_entered.connect(func(area: Area2D) -> void:
		_try_damage(owner_entity, area, dir)
	)

	owner_entity.add_child(_hitbox)


func _cleanup_hitbox() -> void:
	if is_instance_valid(_hitbox):
		_hitbox.queue_free()
	_hitbox = null


func _try_damage(owner_entity: Node, other: Node, dir: Vector2) -> void:
	if other == null or owner_entity == null:
		return

	# Don’t hit self or children
	if other == owner_entity or owner_entity.is_ancestor_of(other):
		return

	var victim_root: Node = _resolve_victim_root(other)

	if one_hit_per_target:
		var id: int = victim_root.get_instance_id()
		if _hit_ids.has(id):
			return
		if max_unique_hits > 0 and _hit_ids.size() >= max_unique_hits:
			return
		_hit_ids[id] = true

	if not _can_damage(owner_entity, victim_root):
		return

	var hp: Health = _find_health(victim_root)
	if hp == null:
		return

	if not hp.take_damage(damage, owner_entity):
		return

	if knockback > 0.0 and victim_root is CharacterBody2D:
		var cb: CharacterBody2D = victim_root as CharacterBody2D
		cb.velocity += dir.normalized() * knockback


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

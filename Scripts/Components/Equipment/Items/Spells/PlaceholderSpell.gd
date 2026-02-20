extends Spell
class_name PlaceholderSpell

@export var label: String = "PlaceholderSpell"

# OFFENSIVE = projectile
# DEFENSIVE = heal self
@export var damage: float = 2.0
@export var heal_amount: float = 2.0

# Projectile tuning
@export var projectile_speed: float = 520.0
@export var projectile_lifetime: float = 1.6
@export var projectile_radius: float = 5.0
@export var knockback: float = 0.0
@export_range(1, 16, 1) var max_hits: int = 1


func _do_cast(owner_entity: Node, dir: Vector2) -> void:
	if owner_entity == null:
		return

	if spell_type == SpellType.DEFENSIVE:
		_cast_heal(owner_entity)
		return

	_cast_projectile(owner_entity, dir)


func _cast_heal(owner_entity: Node) -> void:
	var hp: Health = _find_health(owner_entity)
	if hp != null:
		var applied: float = hp.heal(heal_amount)
		print("[%s] heal %s" % [label, str(applied)])
	else:
		print("[%s] heal (no Health found)" % label)


func _cast_projectile(owner_entity: Node, dir: Vector2) -> void:
	var d: Vector2 = dir
	if d.length() < 0.001:
		d = Vector2.RIGHT
	else:
		d = d.normalized()

	var origin: Vector2 = Vector2.ZERO
	if owner_entity is Node2D:
		origin = (owner_entity as Node2D).global_position

	var parent_for_proj: Node = owner_entity.get_parent()
	if parent_for_proj == null:
		parent_for_proj = owner_entity

	var p: PlaceholderProjectile = PlaceholderProjectile.new()
	p.global_position = origin
	p.rotation = d.angle()
	p.setup(owner_entity, d, damage, projectile_speed, projectile_lifetime, projectile_radius, knockback, max_hits)
	parent_for_proj.add_child(p)

	print("[%s] cast projectile dmg=%s" % [label, str(damage)])


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

extends RefCounted
class_name CombatQuery


static func resolve_victim_root(node: Node) -> Node:
	var cur: Node = node

	for _i: int in range(8):
		if cur == null:
			return null

		if cur is Entity:
			return cur

		if find_health(cur) != null:
			return cur

		cur = cur.get_parent()

	return node


static func find_health(root: Node) -> Health:
	if root == null:
		return null

	if root is Entity:
		var entity: Entity = root as Entity
		var h: Health = entity.find_component(&"Health") as Health
		if h != null:
			return h

	return root.get_node_or_null("Health") as Health


static func find_faction(root: Node) -> Faction:
	if root == null:
		return null

	if root is Entity:
		var entity: Entity = root as Entity
		var f: Faction = entity.find_component(&"Faction") as Faction
		if f != null:
			return f

	return root.get_node_or_null("Faction") as Faction


static func can_damage(attacker: Node, victim_root: Node) -> bool:
	if victim_root == null:
		return false

	var src_faction: Faction = find_faction(attacker)
	if src_faction == null:
		return true

	return src_faction.can_damage(victim_root)

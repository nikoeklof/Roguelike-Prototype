extends RefCounted
class_name ItemPickupRoller

# Deterministically rolls/assigns ItemInstance to an item node inside a pickup.
# Uses: floor_seed + room_coord + pickup_tree_path + salt.
#
# Requirements:
# - item node should implement get_item_instance() and set_item_instance(ItemInstance)
#   (we add safe defaults to Weapon.gd, and implement in MeleeWeapon.gd)

static func apply_roll_if_possible(
	pickup_node: Node,
	item_node: Node,
	attribute_count: int,
	seed_salt: int = 0
) -> void:
	if pickup_node == null or item_node == null:
		return

	# Only roll if the item supports instances
	if not item_node.has_method(&"get_item_instance") or not item_node.has_method(&"set_item_instance"):
		return

	# If it already has an instance, do nothing (preserve)
	var existing: Variant = item_node.call(&"get_item_instance")
	if existing is ItemInstance and (existing as ItemInstance) != null:
		return

	# Need ItemDef to roll attributes
	var def := _extract_item_def(item_node)
	if def == null:
		return

	var floor_seed := _resolve_floor_seed(pickup_node)
	var room_coord := _resolve_room_coord(pickup_node)
	var pickup_key := String(pickup_node.get_path())

	var inst := ItemInstance.new()
	inst.def = def
	inst.seed = compute_pickup_item_seed(floor_seed, room_coord, pickup_key, seed_salt)
	inst.ensure_initialized()

	if attribute_count > 0:
		inst.roll_attributes(attribute_count)

	item_node.call(&"set_item_instance", inst)


static func compute_pickup_item_seed(
	floor_seed: int,
	room_coord: Vector2i,
	pickup_tree_path: String,
	seed_salt: int
) -> int:
	# Hash is deterministic in Godot and perfect for this.
	return int(hash("%d|%d|%d|%s|%d" % [
		floor_seed,
		room_coord.x,
		room_coord.y,
		pickup_tree_path,
		seed_salt
	]))


static func _extract_item_def(item_node: Node) -> ItemDef:
	# Convention: items that support the new system expose `item_def`
	if item_node == null:
		return null

	# Prefer property if present
	if "item_def" in item_node:
		var v: Variant = item_node.get("item_def")
		if v is ItemDef:
			return v as ItemDef

	# Or method if you later add one
	if item_node.has_method(&"get_item_def"):
		var v2: Variant = item_node.call(&"get_item_def")
		if v2 is ItemDef:
			return v2 as ItemDef

	return null


static func _resolve_floor_seed(from_node: Node) -> int:
	var spawner := _find_floor_spawner(from_node)
	if spawner == null:
		return 0
	if "runtime_seed" in spawner:
		return int(spawner.get("runtime_seed"))
	if "seed" in spawner:
		return int(spawner.get("seed"))
	return 0


static func _resolve_room_coord(from_node: Node) -> Vector2i:
	# Walk up until we find a Node2D whose parent is the FloorSpawner.
	var spawner := _find_floor_spawner(from_node)
	if spawner == null:
		return Vector2i.ZERO

	var cur: Node = from_node
	var room_root: Node2D = null

	while cur != null:
		if cur is Node2D and cur.get_parent() == spawner:
			room_root = cur as Node2D
			break
		cur = cur.get_parent()

	if room_root == null:
		return Vector2i.ZERO

	# FloorSpawner uses ROOM_SIZE grid.
	var room_size := Vector2i(528, 528)
	if "ROOM_SIZE" in spawner:
		var rs: Variant = spawner.get("ROOM_SIZE")
		if rs is Vector2i:
			room_size = rs as Vector2i

	var px := room_root.position
	return Vector2i(
		int(round(px.x / float(room_size.x))),
		int(round(px.y / float(room_size.y)))
	)


static func _find_floor_spawner(from_node: Node) -> Node:
	if from_node == null:
		return null
	var tree := from_node.get_tree()
	if tree == null:
		return null

	var spawners := tree.get_nodes_in_group("floor_spawner")
	if spawners.size() > 0:
		return spawners[0] as Node

	return null

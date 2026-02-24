extends Node
class_name ComponentLocator

# Finds the first direct child of `owner` whose script class matches `cls`.
# Works with script `cls` types (e.g. "EnemyControl", "Equipment", etc.)
static func find_child_by_class(owner: Node, cls: StringName) -> Node:
	if owner == null:
		return null
	for c: Node in owner.get_children():
		if c != null and c.is_class(cls):
			return c
	return null


# Finds the first node (BFS) under `owner` matching `cls`.
static func find_in_tree_by_class(owner: Node, cls: StringName) -> Node:
	if owner == null:
		return null

	var q: Array[Node] = [owner]

	while not q.is_empty():
		var v: Variant = q.pop_front()
		var n: Node = v as Node
		if n == null:
			continue

		if n != owner and n.is_class(cls):
			return n

		for ch_v: Variant in n.get_children():
			var ch: Node = ch_v as Node
			if ch != null:
				q.append(ch)

	return null

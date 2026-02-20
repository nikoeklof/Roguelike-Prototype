extends Node
class_name EntityComponents

# entity_id -> { class_name : WeakRef }
static var _cache: Dictionary = {}

static func _key(entity: Object) -> int:
	return entity.get_instance_id()

static func clear_cache(entity: Object) -> void:
	if entity == null:
		return
	_cache.erase(_key(entity))

static func resolve_child(entity: Node, cls: StringName) -> Node:
	if entity == null:
		return null

	var id: int = _key(entity)

	var bucket: Dictionary
	if _cache.has(id):
		bucket = _cache[id] as Dictionary
	else:
		bucket = {}

	if bucket.has(cls):
		var ref: WeakRef = bucket[cls] as WeakRef
		var cached: Object = ref.get_ref()
		if cached != null and is_instance_valid(cached):
			return cached as Node
		bucket.erase(cls)

	for c: Node in entity.get_children():
		if c != null and c.is_class(cls):
			bucket[cls] = weakref(c)
			_cache[id] = bucket
			return c

	return null

static func resolve_in_tree(entity: Node, cls: StringName) -> Node:
	if entity == null:
		return null

	var direct: Node = resolve_child(entity, cls)
	if direct != null:
		return direct

	var queue: Array[Node] = []
	for c: Node in entity.get_children():
		queue.append(c)

	while not queue.is_empty():
		var n: Node = queue.pop_front()
		if n != null and n.is_class(cls):
			return n
		for ch: Node in n.get_children():
			queue.append(ch)

	return null

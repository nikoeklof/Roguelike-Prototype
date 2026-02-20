extends Area2D
class_name Interactor

@export var action_name: StringName = &"Interact"
@export var prefer_closest: bool = true

@export var require_group: bool = true
@export var interactable_group: StringName = &"interactable"

var _candidates: Array[Node] = []


func _ready() -> void:
	monitoring = true
	monitorable = false

	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	area_entered.connect(_on_entered)
	area_exited.connect(_on_exited)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(action_name):
		var target: Node = get_best_interactable()
		if target != null:
			_do_interact(target)


func get_best_interactable() -> Node:
	_candidates = _candidates.filter(func(n: Node) -> bool:
		return is_instance_valid(n)
	)

	if _candidates.is_empty():
		return null

	if not prefer_closest:
		return _candidates[0]

	var owner2d: Node2D = get_parent() as Node2D
	if owner2d == null:
		return _candidates[0]

	var best: Node = null
	var best_d2: float = INF
	var p: Vector2 = owner2d.global_position

	for n: Node in _candidates:
		var n2d: Node2D = n as Node2D
		if n2d == null:
			continue
		var d2: float = p.distance_squared_to(n2d.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = n

	return best if best != null else _candidates[0]


func _do_interact(target: Node) -> void:
	var interactor_owner: Node = get_parent()

	# Respect can_interact if present
	if target.has_method(&"can_interact"):
		var res: Variant = target.call(&"can_interact", interactor_owner)
		if res is bool and (res as bool) == false:
			return

	if target.has_method(&"interact"):
		target.call(&"interact", interactor_owner)


func _on_entered(node: Node) -> void:
	var n: Node = _resolve_interactable(node)
	if n == null:
		return
	if _candidates.has(n):
		return
	_candidates.append(n)


func _on_exited(node: Node) -> void:
	var n: Node = _resolve_interactable(node)
	if n == null:
		return
	_candidates.erase(n)


func _resolve_interactable(node: Node) -> Node:
	if node == null:
		return null

	var cur: Node = node
	for _i in 5:
		if cur == null:
			break

		if require_group:
			if cur.is_in_group(interactable_group):
				return cur
		else:
			if cur.has_method(&"interact"):
				return cur

		cur = cur.get_parent()

	if not require_group and node.has_method(&"interact"):
		return node

	return null

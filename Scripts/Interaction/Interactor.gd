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

	print("[Interactor] READY:", get_parent(), "action=", action_name, "require_group=", require_group, "group=", interactable_group)

	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	area_entered.connect(_on_entered)
	area_exited.connect(_on_exited)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(action_name):
		print("\n[Interactor] interact pressed")
		print("[Interactor] raw candidates:", _candidates)
		var target: Node = get_best_interactable()
		print("[Interactor] best target:", target)
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
	print("[Interactor] _do_interact target:", target, "owner:", interactor_owner)

	# Respect can_interact if present
	if target.has_method(&"can_interact"):
		var res: Variant = target.call(&"can_interact", interactor_owner)
		print("[Interactor] can_interact?", res)
		if res is bool and (res as bool) == false:
			print("[Interactor] blocked by can_interact")
			return

	if target.has_method(&"interact"):
		print("[Interactor] calling interact()")
		target.call(&"interact", interactor_owner)
	else:
		print("[Interactor] target has no interact()")


func _on_entered(node: Node) -> void:
	print("[Interactor] entered:", node)
	var n: Node = _resolve_interactable(node)
	if n == null:
		return
	if _candidates.has(n):
		return
	_candidates.append(n)
	print("[Interactor] +candidate:", n, "count=", _candidates.size())

	# NEW: notify interactable so it can show UI / highlight
	var interactor_owner := get_parent()
	if interactor_owner != null and n.has_method(&"on_interactor_entered"):
		n.call(&"on_interactor_entered", interactor_owner)


func _on_exited(node: Node) -> void:
	print("[Interactor] exited:", node)
	var n: Node = _resolve_interactable(node)
	if n == null:
		return
	_candidates.erase(n)
	print("[Interactor] -candidate:", n, "count=", _candidates.size())

	# NEW: notify interactable so it can hide UI / highlight
	var interactor_owner := get_parent()
	if interactor_owner != null and n.has_method(&"on_interactor_exited"):
		n.call(&"on_interactor_exited", interactor_owner)


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

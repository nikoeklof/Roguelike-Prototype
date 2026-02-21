extends CharacterBody2D
class_name Entity

@export var initial_faction: Faction.Id = Faction.Id.NEUTRAL
@export var initial_friendly_fire: bool = false
@export var start_state: StringName = &"Idle"

var state_machine: Node
var _faction: Faction
var _health: Health

static var _engine_normalized: bool = false


func _ready() -> void:
	# --- NEW: one-time normalization for capture / movie maker / low render FPS ---
	if not _engine_normalized:
		_engine_normalized = true

		# Keep simulation stable even when rendering is capped/slower.
		# Movie Maker can stress rendering; this prevents physics falling behind.
		Engine.physics_ticks_per_second = 60
		Engine.max_physics_steps_per_frame = 32

	# Faction
	_faction = find_component(&"Faction") as Faction
	if _faction:
		_faction.faction = initial_faction
		_faction.friendly_fire = initial_friendly_fire

	# State machine (robust)
	state_machine = _resolve_state_machine()
	if state_machine == null:
		push_error("Entity: Missing StateHandler component (expected node named 'StateHandler' or script StateHandler.gd).")
	else:
		if state_machine.has_method("init"):
			state_machine.call("init", self, String(start_state))
		else:
			push_error("Entity: Found '%s' but it has no init(entity, start_state)." % state_machine.name)

	# Health
	_health = find_component(&"Health") as Health
	if _health:
		if not _health.damaged.is_connected(_on_damaged):
			_health.damaged.connect(_on_damaged)
		if not _health.died.is_connected(_on_died):
			_health.died.connect(_on_died)


func _resolve_state_machine() -> Node:
	# 1) Resolver by class_name (best case)
	var sm := find_component(&"StateHandler")
	if sm != null:
		return sm

	# 2) Stable node names in your pipeline
	sm = get_node_or_null("StateHandler")
	if sm != null:
		return sm
	sm = get_node_or_null("StateMachine")
	if sm != null:
		return sm

	# 3) Script filename fallback
	return _find_node_with_script_ending(self, "StateHandler.gd")


func _find_node_with_script_ending(root: Node, filename: String) -> Node:
	var q: Array[Node] = [root]

	while not q.is_empty():
		var n: Node = q.pop_front()
		var s: Variant = n.get_script()
		if s is Script:
			var path: String = (s as Script).resource_path
			if path.ends_with(filename):
				return n
		for c in n.get_children():
			q.append(c)
	return null


func _physics_process(delta: float) -> void:
	var local_delta := delta
	var time := find_component(&"LocalTimeScale") as LocalTimeScale
	if time:
		local_delta = time.get_scaled_delta(delta)
	if state_machine != null and state_machine.has_method("physics_update"):
		state_machine.call("physics_update", local_delta)
	move_and_slide()


func _on_damaged(_amount: float, _source: Node) -> void:
	if state_machine != null and state_machine.has_method("change_state"):
		state_machine.call("change_state", "Hurt")


func _on_died() -> void:
	queue_free()


func get_component(cls: StringName) -> Node:
	return EntityComponents.resolve_child(self, cls)


func find_component(cls: StringName) -> Node:
	return EntityComponents.resolve_in_tree(self, cls)


func _exit_tree() -> void:
	EntityComponents.clear_cache(self)

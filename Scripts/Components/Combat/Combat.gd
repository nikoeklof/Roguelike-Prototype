extends Node
class_name Combat

signal attack_finished(kind: int)

enum AttackKind {
	NONE,
	MELEE,
	RANGED,
	SPELL,
}

@export var attack_executor_root_path: NodePath

var _cooldowns: Dictionary = {}
var _spread_roll_counter: int = 0
var _running_executors: Array[AttackExecutor] = []


func _ready() -> void:
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _cooldowns.is_empty():
		return

	var keys: Array = _cooldowns.keys()
	for key in keys:
		var remain: float = float(_cooldowns.get(key, 0.0)) - delta
		if remain <= 0.0:
			_cooldowns.erase(key)
		else:
			_cooldowns[key] = remain


func can_attack(item: Node) -> bool:
	if item == null:
		return false
	return not _cooldowns.has(item)


func can_attack_kind(kind: int) -> bool:
	var owner_entity: Node = _resolve_owner_entity()
	if owner_entity == null:
		return false

	var item: Node = _resolve_item_for_kind(owner_entity, kind)
	if item == null:
		return false

	return can_attack(item)


func allows_movement_for(kind: int) -> bool:
	var owner_entity: Node = _resolve_owner_entity()
	if owner_entity == null:
		return false

	var item: Node = _resolve_item_for_kind(owner_entity, kind)
	if item == null:
		return false

	if "allow_move_during_attack" in item:
		return bool(item.get("allow_move_during_attack"))

	return false


func try_attack(kind: int, aim_dir: Vector2 = Vector2.RIGHT) -> bool:
	if kind == AttackKind.NONE:
		return false

	var owner_entity: Node = _resolve_owner_entity()
	if owner_entity == null:
		return false

	var item: Node = _resolve_item_for_kind(owner_entity, kind)
	if item == null:
		return false

	if not can_attack(item):
		return false

	if not item.has_method("get_attack_variant"):
		return false

	var ctx: CombatContext = CombatContext.new()
	ctx.owner = owner
	ctx.item = item

	if aim_dir.length() > 0.001:
		ctx.aim_dir = aim_dir.normalized()
	else:
		ctx.aim_dir = Vector2.RIGHT

	if item.has_method("get_item_instance"):
		ctx.item_instance = item.get_item_instance()

	ctx.equipment = _resolve_equipment(owner)
	ctx.stats = _resolve_component(owner, &"Stats")
	ctx.tags = _resolve_component(owner, &"Tags")
	ctx.faction = _resolve_component(owner, &"Faction")
	ctx.capabilities = _resolve_component(owner, &"Capabilities")

	# Small per-attack salt so spread changes each shot.
	_spread_roll_counter = (_spread_roll_counter % 64) + 1
	ctx.spread_roll = _spread_roll_counter

	var variant: AttackVariant = item.get_attack_variant(ctx)
	if variant == null:
		return false

	var snap: AttackSnapshot = AttackResolver.resolve(ctx, variant)

	# For beam weapons, lock out re-fire with a sentinel cooldown so a second
	# executor cannot stack while the continuous beam is running.
	# The executor clears this via clear_cooldown() when the beam ends.
	var commit_cooldown: float = snap.cooldown_sec
	var is_beam: bool = snap.ranged_mode == RangedShotData.ShotMode.BEAM
	if not is_beam and ctx.item_instance != null:
		for attr: ItemAttribute in ctx.item_instance.attributes:
			if attr is BeamModeAttribute:
				is_beam = true
				break
	if is_beam:
		commit_cooldown = 9999.0
	_commit_cooldown(item, commit_cooldown)

	var executor: AttackExecutor = variant.create_executor(ctx)
	if executor == null:
		return false

	var parent: Node = _resolve_executor_parent(owner)
	parent.add_child(executor)

	_running_executors.append(executor)

	if not executor.finished.is_connected(_on_executor_finished.bind(kind, executor)):
		executor.finished.connect(_on_executor_finished.bind(kind, executor), CONNECT_ONE_SHOT)

	executor.start()
	return true


func get_cooldown_remaining(item: Node) -> float:
	if item == null:
		return 0.0
	return float(_cooldowns.get(item, 0.0))


func clear_cooldown(item: Node) -> void:
	if item == null:
		return
	_cooldowns.erase(item)


func stop_all() -> void:
	var to_stop: Array[AttackExecutor] = _running_executors.duplicate()
	_running_executors.clear()

	for executor in to_stop:
		if executor != null and is_instance_valid(executor):
			executor.queue_free()


func _commit_cooldown(item: Node, cooldown_sec: float) -> void:
	if item == null:
		return
	_cooldowns[item] = max(0.0, cooldown_sec)


func _resolve_owner_entity() -> Node:
	var p: Node = get_parent()
	while p != null:
		if p is Entity:
			return p
		if p is CharacterBody2D:
			return p
		p = p.get_parent()
	return null


func _resolve_equipment(owner_entity: Node) -> Equipment:
	if owner_entity == null:
		return null

	if owner_entity is Entity:
		var eq_component: Node = (owner_entity as Entity).get_component(&"Equipment")
		if eq_component is Equipment:
			return eq_component as Equipment

	var eq_node: Node = owner.get_node_or_null("Equipment")
	if eq_node is Equipment:
		return eq_node as Equipment

	return null


func _resolve_item_for_kind(owner_entity: Node, kind: int) -> Node:
	var equipment: Equipment = _resolve_equipment(owner_entity)
	if equipment == null:
		return null
	return equipment.get_item_for_kind(kind)


func _resolve_component(owner_entity: Node, class_name_value: StringName) -> Node:
	if owner_entity == null:
		return null

	if owner_entity is Entity:
		return (owner_entity as Entity).get_component(class_name_value)

	return owner.get_node_or_null(String(class_name_value))


func _resolve_executor_parent(owner_entity: Node) -> Node:
	if attack_executor_root_path != NodePath():
		var explicit: Node = get_node_or_null(attack_executor_root_path)
		if explicit != null:
			return explicit

	if owner_entity != null and owner_entity.get_parent() != null:
		return owner_entity.get_parent()

	return self


func _on_executor_finished(_success: bool, kind: int, executor: AttackExecutor) -> void:
	_running_executors.erase(executor)
	attack_finished.emit(kind)

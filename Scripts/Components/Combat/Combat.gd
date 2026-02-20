@tool
extends Node
class_name Combat
signal attack_finished(kind: int)
enum AttackKind { NONE, MELEE, RANGED, SPELL }
@export_node_path("Equipment") var equipment_path: NodePath = ^"Equipment"
var _equipment: Equipment

var _active_executor: AttackExecutor

func _ready() -> void:
	_equipment = _resolve_equipment()
	if Engine.is_editor_hint():
		update_configuration_warnings()

func _notification(what: int) -> void:
	if Engine.is_editor_hint() and (what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_READY):
		update_configuration_warnings()

func _resolve_equipment() -> Equipment:
	var e := get_node_or_null(equipment_path) as Equipment
	if e != null:
		return e
	var entity := get_parent() as Entity
	if entity == null:
		return null
	return entity.get_component(&"Equipment") as Equipment


func equipment() -> Equipment:
	if _equipment == null or not is_instance_valid(_equipment):
		_equipment = _resolve_equipment()
	return _equipment

func allows_movement_for(kind: int) -> bool:
	var e := equipment()
	if e == null:
		return true
	var item := e.get_item_for_kind(kind)
	if item == null:
		return true
	if item is Weapon:
		return (item as Weapon).allow_move_during_attack
	if item is Spell:
		return (item as Spell).allow_move_during_cast
	return true


func try_attack(kind: int, dir: Vector2) -> bool:
	# Compatibility wrapper used by the current Attack state.
	# Preferred path:
	#   item.get_attack_variant(context) -> spawn AttackExecutor
	# Legacy fallback:
	#   Weapon.try_attack / Spell.try_cast
	var e := equipment()
	if e == null:
		return false
	var owner_entity := get_parent()
	if owner_entity == null:
		return false
	# If something is already executing, don't start a new one.
	if _active_executor != null and is_instance_valid(_active_executor):
		return false
	var item := e.get_item_for_kind(kind)
	if item == null:
		return false
	var d := dir
	if d.length() < 0.001:
		d = Vector2.RIGHT
	else:
		d = d.normalized()
	# --- New executor path ---
	var variant := _get_variant_from_item(item, owner_entity, d)
	if variant != null:
		return _run_variant(kind, variant, owner_entity, d)
	# --- Legacy path (kept for gradual migration) ---
	if item is Weapon:
		var w := item as Weapon
		if not w.attack_finished.is_connected(_on_weapon_attack_finished):
			w.attack_finished.connect(_on_weapon_attack_finished.bind(kind), CONNECT_ONE_SHOT)
		return w.try_attack(d, owner_entity)
	if item is Spell:
		var s := item as Spell
		if not s.cast_finished.is_connected(_on_spell_cast_finished):
			s.cast_finished.connect(_on_spell_cast_finished.bind(kind), CONNECT_ONE_SHOT)
		return s.try_cast(owner_entity, d)
	return false


func stop_all() -> void:
	# Optional cleanup hook for interrupts/staggers.
	# Safe to call even if nothing is running.
	if _active_executor != null and is_instance_valid(_active_executor):
		_active_executor.queue_free()
	_active_executor = null


func _on_weapon_attack_finished(kind: int) -> void:
	attack_finished.emit(kind)


func _on_spell_cast_finished(_success: bool, kind: int) -> void:
	attack_finished.emit(kind)


func _get_variant_from_item(item: Node, owner_entity: Node, dir: Vector2) -> AttackVariant:
	# Build a lightweight context for variant selection.
	# Keep this robust: entities may not have all components.
	var ctx := CombatContext.new()
	ctx.owner = owner_entity
	ctx.aim_dir = dir
	ctx.equipment = equipment()
	ctx.stats = _resolve_component(owner_entity, &"Stats")
	ctx.tags = _resolve_component(owner_entity, &"Tags")
	ctx.faction = _resolve_component(owner_entity, &"Faction")
	ctx.capabilities = _resolve_component(owner_entity, &"Capabilities")
	if item.has_method("get_attack_variant"):
		var v : AttackVariant = item.call("get_attack_variant", ctx)
		if v is AttackVariant:
			return v
	return null


func _run_variant(kind: int, variant: AttackVariant, owner_entity: Node, dir: Vector2) -> bool:
	var ctx := CombatContext.new()
	ctx.owner = owner_entity
	ctx.aim_dir = dir
	ctx.equipment = equipment()
	ctx.stats = _resolve_component(owner_entity, &"Stats")
	ctx.tags = _resolve_component(owner_entity, &"Tags")
	ctx.faction = _resolve_component(owner_entity, &"Faction")
	ctx.capabilities = _resolve_component(owner_entity, &"Capabilities")
	var exec := variant.create_executor(ctx)
	if exec == null:
		return false
	_active_executor = exec
	owner_entity.add_child(exec)
	exec.finished.connect(func(_success: bool):
		_active_executor = null
		attack_finished.emit(kind)
	, CONNECT_ONE_SHOT)
	# Ensure we can't miss instant-finish executors.
	exec.start()
	return true


func _resolve_component(owner_entity: Node, cls: StringName) -> Node:
	if owner_entity is Entity:
		return (owner_entity as Entity).find_component(cls)
	# Fallback: try direct child.
	return owner_entity.get_node_or_null(String(cls))


func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if _resolve_equipment() == null:
		w.append("Combat: Missing Equipment. Add an Equipment node as a direct child of the entity, or set equipment_path.")
	return w

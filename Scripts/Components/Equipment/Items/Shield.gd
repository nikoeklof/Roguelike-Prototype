extends Node
class_name Shield

@export var pickup_slot_kind: Equipment.SlotKind = Equipment.SlotKind.SHIELD
@export var pickup_icon: Texture2D

# ---- New data-driven item system ----
@export var item_def: ItemDef
@export var item_seed: int = 0
@export_range(0, 8, 1) var editor_attribute_count: int = 0

var _instance: ItemInstance = null
var _owner: Node = null
var _key: StringName = &"shield_passive"


func _ready() -> void:
	_refresh_key()

	# If hand-authored, create an instance here.
	# If injected via pickup roller, set_item_instance() will run first.
	if _instance == null and item_def != null:
		_instance = ItemInstance.new()
		_instance.def = item_def
		_instance.seed = item_seed
		_instance.ensure_initialized()
		if editor_attribute_count > 0:
			_instance.roll_attributes(editor_attribute_count)


func get_pickup_slot_kind() -> int:
	return int(pickup_slot_kind)


func get_pickup_icon() -> Texture2D:
	return pickup_icon


func get_item_instance() -> ItemInstance:
	return _instance


func set_item_instance(inst: ItemInstance) -> void:
	_instance = inst
	if _instance != null and _instance.def != null:
		item_def = _instance.def
		item_seed = _instance.seed
	_refresh_key()


func on_equipped(owner_entity: Node) -> void:
	_owner = owner_entity
	if owner_entity == null:
		return
	_apply_passives(owner_entity)


func on_unequipped(owner_entity: Node) -> void:
	var target := owner_entity if owner_entity != null else _owner
	if target == null:
		return
	_clear_passives(target)
	_owner = null


# ------------------------------------------------------------
# Internals
# ------------------------------------------------------------
func _refresh_key() -> void:
	var def_id := "none"
	if item_def != null and item_def.id != &"":
		def_id = String(item_def.id)
	_key = StringName("shield_%s_%d" % [def_id, int(item_seed)])


func _apply_passives(owner_entity: Node) -> void:
	if _instance == null or _instance.def == null:
		return

	var ctx := CombatContext.new()
	ctx.owner = owner_entity
	ctx.aim_dir = Vector2.RIGHT
	ctx.item = self
	ctx.item_instance = _instance

	if owner_entity is Entity:
		var ent := owner_entity as Entity
		ctx.stats = ent.find_component(&"Stats")
		ctx.faction = ent.find_component(&"Faction")
		ctx.tags = ent.find_component(&"Tags")
		ctx.capabilities = ent.find_component(&"Capabilities")
	else:
		ctx.stats = owner_entity.get_node_or_null("Stats")

	var stats_res := _instance.compute_stats(ctx)

	var hp := _find_health(owner_entity)
	if hp != null:
		if not is_equal_approx(stats_res.bonus_max_hp, 0.0):
			# Signature used by your existing TestShield: add_max_hp(amount, heal, clamp_to_max?)
			hp.add_max_hp(stats_res.bonus_max_hp, stats_res.heal_on_equip, false)
		elif not is_equal_approx(stats_res.heal_on_equip, 0.0):
			hp.heal(stats_res.heal_on_equip)

	var stats := _find_stats(owner_entity)
	if stats != null:
		# Multipliers: only set if meaningful to avoid noise
		if not is_equal_approx(stats_res.move_speed_mult, 1.0):
			stats.set_move_speed_mult(_key, stats_res.move_speed_mult)

		if not is_equal_approx(stats_res.damage_taken_mult, 1.0):
			stats.set_damage_taken_mult(_key, stats_res.damage_taken_mult)

		if not is_equal_approx(stats_res.flat_damage_reduction, 0.0):
			stats.set_flat_damage_reduction(_key, stats_res.flat_damage_reduction)


func _clear_passives(owner_entity: Node) -> void:
	var hp := _find_health(owner_entity)
	if hp != null and _instance != null:
		# Remove max HP bonus if applied
		var ctx := CombatContext.new()
		ctx.owner = owner_entity
		ctx.aim_dir = Vector2.RIGHT
		ctx.item = self
		ctx.item_instance = _instance
		var stats_res := _instance.compute_stats(ctx)
		if not is_equal_approx(stats_res.bonus_max_hp, 0.0):
			hp.add_max_hp(-stats_res.bonus_max_hp, 0.0, false)

	var stats := _find_stats(owner_entity)
	if stats != null:
		stats.clear_move_speed_mult(_key)
		stats.clear_damage_taken_mult(_key)
		stats.clear_flat_damage_reduction(_key)


func _find_health(root: Node) -> Health:
	if root is Entity:
		return (root as Entity).find_component(&"Health") as Health
	return root.get_node_or_null("Health") as Health


func _find_stats(root: Node) -> Stats:
	if root is Entity:
		return (root as Entity).find_component(&"Stats") as Stats
	return root.get_node_or_null("Stats") as Stats

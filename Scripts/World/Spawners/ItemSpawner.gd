extends Node2D
class_name ItemSpawner

enum SpawnCategory { ANY, MELEE, RANGED, SPELL, SHIELD }

## Which category to roll from the registry. ANY picks across all categories.
@export var spawn_category: SpawnCategory = SpawnCategory.ANY

## Optional: pin to a specific base type instead of rolling from the registry.
## When set, spawn_category is ignored.
@export var base_type_override: BaseItemType = null

@export_group("Spawn Control")
@export var auto_spawn_when_no_floor_spawner: bool = true

@export_group("Seeding")
@export var spawn_id: StringName = &""
@export var drop_index: int = 0
@export var use_auto_id_if_empty: bool = true
@export var auto_room_coord: Vector2i = Vector2i.ZERO
@export var auto_room_local_index: int = -1
@export var run_seed_override_enabled: bool = false
@export var run_seed_override: int = 0

var _spawned: bool = false

const MELEE_TEMPLATE:          PackedScene = preload("res://Scenes/Templates/EquipmentItems/Melee_Weapon_Template.tscn")
const RANGED_TEMPLATE:         PackedScene = preload("res://Scenes/Templates/EquipmentItems/Ranged_Weapon_template.tscn")
const SPELL_BUFF_TEMPLATE:     PackedScene = preload("res://Scenes/Items/Spells/Spell_Buff_Template.tscn")
const SPELL_DEBUFF_TEMPLATE:   PackedScene = preload("res://Scenes/Items/Spells/Spell_Debuff_Template.tscn")
const SHIELD_ACTIVE_TEMPLATE:  PackedScene = preload("res://Scenes/Items/Shields/Shield_Active_Template.tscn")
const SHIELD_PASSIVE_TEMPLATE: PackedScene = preload("res://Scenes/Items/Shields/Shield_Passive_Template.tscn")


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if _spawned or not auto_spawn_when_no_floor_spawner:
		return
	if get_tree().get_first_node_in_group("floor_spawner") != null:
		return
	spawn()


# ------------------------------------------------------------------ #
#  Public API
# ------------------------------------------------------------------ #

func spawn_with_run_seed(run_seed: int) -> Node:
	if _spawned:
		return null
	_spawned = true

	var sid: StringName = _resolve_spawn_id()
	var final_seed: int  = run_seed_override if run_seed_override_enabled else run_seed
	var item_seed: int   = _make_drop_seed(final_seed, sid, drop_index)

	var base_type: BaseItemType = _resolve_base_type(item_seed)
	if base_type == null or base_type.item_def == null:
		push_warning("[ItemSpawner] No base type resolved (category=%s, override=%s)." % [
			SpawnCategory.keys()[spawn_category],
			str(base_type_override)
		])
		return null

	var inst := _roll_instance(base_type, item_seed)
	if inst == null:
		return null

	var pickup_scene: PackedScene = load("res://Scenes/Templates/World/GroundItemPickup.tscn")
	if pickup_scene == null:
		push_warning("[ItemSpawner] GroundItemPickup.tscn not found.")
		return null

	var pickup_node: Node = pickup_scene.instantiate()
	if not (pickup_node is EquipmentSwapPickup):
		pickup_node.queue_free()
		push_warning("[ItemSpawner] GroundItemPickup root is not EquipmentSwapPickup.")
		return null

	var pickup: EquipmentSwapPickup = pickup_node as EquipmentSwapPickup
	var equip_item: Node = _make_equipment_item(inst)
	if equip_item == null:
		pickup.queue_free()
		push_warning("[ItemSpawner] _make_equipment_item returned null for '%s'." % str(base_type.item_def.id))
		return null

	pickup.set_item(equip_item)
	get_parent().add_child.call_deferred(pickup)
	pickup.set_deferred("global_position", global_position)
	return pickup


func spawn() -> Node:
	if run_seed_override_enabled:
		return spawn_with_run_seed(run_seed_override)
	# Use the current run seed from WorldSeed so items reroll each run.
	# Call WorldSeed.randomize_seed() (or set_seed) when starting a new run.
	var ws := get_node_or_null("/root/WorldSeed")
	var run_seed: int = int(ws.current_seed) if (ws != null and "current_seed" in ws) else 0
	return spawn_with_run_seed(run_seed)


# ------------------------------------------------------------------ #
#  Static preview (used by the inspector plugin)
# ------------------------------------------------------------------ #

static func roll_preview(bt: BaseItemType, item_seed: int) -> ItemInstance:
	if bt == null or bt.item_def == null:
		return null
	return _static_roll_instance(bt, item_seed)


## Roll a full item from the registry, filtered by SpawnCategory enum value.
## Returns { "base_type": BaseItemType, "instance": ItemInstance } or {} on failure.
static func roll_preview_from_seed(category_enum: int, item_seed: int) -> Dictionary:
	var registry: ItemTypeRegistry = ItemTypeRegistry.load_registry()
	if registry == null:
		return {}

	var pool: Array[BaseItemType] = (
		registry.get_for_category(_category_to_int(category_enum))
		if category_enum != SpawnCategory.ANY
		else _preview_all_valid(registry.entries)
	)
	if pool.is_empty():
		return {}

	var rng := RandomNumberGenerator.new()
	rng.seed = int((item_seed * 2654435761) & 0x7fffffff)
	var bt: BaseItemType = pool[rng.randi_range(0, pool.size() - 1)]

	var inst: ItemInstance = _static_roll_instance(bt, item_seed)
	if inst == null:
		return {}
	return { "base_type": bt, "instance": inst }


static func _preview_all_valid(src: Array[BaseItemType]) -> Array[BaseItemType]:
	var out: Array[BaseItemType] = []
	for bt: BaseItemType in src:
		if bt != null and bt.item_def != null:
			out.append(bt)
	return out


# ------------------------------------------------------------------ #
#  Base-type resolution
# ------------------------------------------------------------------ #

func _resolve_base_type(item_seed: int) -> BaseItemType:
	if base_type_override != null:
		return base_type_override

	var registry: ItemTypeRegistry = ItemTypeRegistry.load_registry()
	if registry == null:
		return null

	var pool: Array[BaseItemType] = (
		registry.get_for_category(_category_to_int(int(spawn_category)))
		if spawn_category != SpawnCategory.ANY
		else _all_valid(registry.entries)
	)

	if pool.is_empty():
		push_warning("[ItemSpawner] Registry has no entries for category: %s" % SpawnCategory.keys()[spawn_category])
		return null

	var rng := RandomNumberGenerator.new()
	rng.seed = int((item_seed * 2654435761) & 0x7fffffff)
	return pool[rng.randi_range(0, pool.size() - 1)]


func _all_valid(src: Array[BaseItemType]) -> Array[BaseItemType]:
	var out: Array[BaseItemType] = []
	for bt: BaseItemType in src:
		if bt != null and bt.item_def != null:
			out.append(bt)
	return out


static func _category_to_int(cat: int) -> int:
	match cat:
		SpawnCategory.MELEE:  return ItemDef.Category.MELEE
		SpawnCategory.RANGED: return ItemDef.Category.RANGED
		SpawnCategory.SPELL:  return ItemDef.Category.SPELL
		SpawnCategory.SHIELD: return ItemDef.Category.SHIELD
		_: return -1


# ------------------------------------------------------------------ #
#  Instance rolling (instance method + shared static core)
# ------------------------------------------------------------------ #

func _roll_instance(bt: BaseItemType, item_seed: int) -> ItemInstance:
	return _static_roll_instance(bt, item_seed)


static func _static_roll_instance(bt: BaseItemType, item_seed: int) -> ItemInstance:
	if bt == null or bt.item_def == null:
		return null

	var inst := ItemInstance.new()
	inst.def      = bt.item_def
	inst.item_seed = item_seed
	inst.ensure_initialized()

	_static_apply_starting_stat_levels(inst, bt)

	var attr_count: int = _static_roll_attr_count(item_seed, bt.min_attribute_count, bt.max_attribute_count)

	var chosen_mode: int = -1
	if int(bt.item_def.category) == ItemDef.Category.RANGED and bt.use_ranged_mode_roll:
		chosen_mode = _static_roll_ranged_mode(item_seed, bt)
		inst.ranged_mode = chosen_mode

	if int(bt.item_def.category) == ItemDef.Category.SPELL:
		var spell_def: SpellItemDef = bt.item_def as SpellItemDef
		if spell_def != null and spell_def.spell_type == SpellItemDef.SpellType.DEBUFF:
			inst.spell_delivery_mode = _static_roll_spell_delivery_mode(item_seed, spell_def)

	_static_roll_attributes(inst, bt, item_seed, attr_count, chosen_mode)
	return inst


# ------------------------------------------------------------------ #
#  Equipment node creation
# ------------------------------------------------------------------ #

func _make_equipment_item(inst: ItemInstance) -> Node:
	if inst == null or inst.def == null:
		return null

	var scene: PackedScene = _scene_for_instance(inst)
	if scene == null:
		return null

	var node: Node = scene.instantiate()
	if node.has_method(&"set_item_instance"):
		node.call(&"set_item_instance", inst)
	else:
		if "item_def"  in node: node.set("item_def",  inst.def)
		if "item_seed" in node: node.set("item_seed", inst.item_seed)
	return node


func _scene_for_instance(inst: ItemInstance) -> PackedScene:
	match int(inst.def.category):
		ItemDef.Category.MELEE:
			return MELEE_TEMPLATE
		ItemDef.Category.RANGED:
			return RANGED_TEMPLATE
		ItemDef.Category.SPELL:
			var sd: SpellItemDef = inst.def as SpellItemDef
			if sd != null:
				return SPELL_DEBUFF_TEMPLATE if sd.spell_type == SpellItemDef.SpellType.DEBUFF else SPELL_BUFF_TEMPLATE
			return SPELL_BUFF_TEMPLATE
		ItemDef.Category.SHIELD:
			var sd: ShieldItemDef = inst.def as ShieldItemDef
			if sd != null:
				return SHIELD_PASSIVE_TEMPLATE if sd.shield_type == ShieldItemDef.ShieldType.PASSIVE else SHIELD_ACTIVE_TEMPLATE
			return SHIELD_ACTIVE_TEMPLATE
	return null


# ------------------------------------------------------------------ #
#  Seeding helpers
# ------------------------------------------------------------------ #

func _resolve_spawn_id() -> StringName:
	if spawn_id != StringName() and not String(spawn_id).is_empty():
		return spawn_id
	if use_auto_id_if_empty:
		var auto_id: StringName = _compute_auto_spawn_id()
		if auto_id != StringName() and not String(auto_id).is_empty():
			return auto_id
	return StringName(String(get_path()))


func _compute_auto_spawn_id() -> StringName:
	if auto_room_local_index < 0:
		return &""
	return StringName("room_%d_%d_pickup_%d" % [auto_room_coord.x, auto_room_coord.y, auto_room_local_index])


static func _make_drop_seed(run_seed: int, id: StringName, idx: int) -> int:
	var h: int = int(hash(id))
	var s: int = run_seed
	s = int((s * 1103515245 + 12345) & 0x7fffffff)
	s = int((s ^ h)               & 0x7fffffff)
	s = int((s + idx * 1013)      & 0x7fffffff)
	return s


# ------------------------------------------------------------------ #
#  Rolling helpers (static so roll_preview can share them)
# ------------------------------------------------------------------ #

static func _static_apply_starting_stat_levels(inst: ItemInstance, bt: BaseItemType) -> void:
	for k: Variant in bt.start_stat_levels.keys():
		inst.stat_levels[StringName(k)] = int(bt.start_stat_levels[k])


static func _static_roll_attr_count(item_seed: int, min_c: int, max_c: int) -> int:
	var lo := mini(min_c, max_c)
	var hi := maxi(min_c, max_c)
	if hi <= lo:
		return lo
	var rng := RandomNumberGenerator.new()
	rng.seed = item_seed
	return rng.randi_range(lo, hi)


static func _static_roll_ranged_mode(item_seed: int, bt: BaseItemType) -> int:
	if bt.locked_ranged_mode >= 0:
		return bt.locked_ranged_mode
	var rng := RandomNumberGenerator.new()
	rng.seed = int((item_seed * 2246822519 + 3266489917) & 0x7fffffff)
	var w_proj: float = maxf(0.0, bt.weight_projectile)
	var w_hit:  float = maxf(0.0, bt.weight_hitscan)
	var w_beam: float = maxf(0.0, bt.weight_beam)
	var total: float  = w_proj + w_hit + w_beam
	if total <= 0.0:
		return RangedShotData.ShotMode.PROJECTILE
	var r: float = rng.randf() * total
	if r < w_proj: return RangedShotData.ShotMode.PROJECTILE
	r -= w_proj
	if r < w_hit:  return RangedShotData.ShotMode.HITSCAN
	return RangedShotData.ShotMode.BEAM


static func _static_roll_spell_delivery_mode(item_seed: int, spell_def: SpellItemDef) -> int:
	if spell_def.locked_delivery_mode >= 0:
		return spell_def.locked_delivery_mode
	var rng := RandomNumberGenerator.new()
	rng.seed = int((item_seed * 2246822519 + 3266489917) & 0x7fffffff)
	var w_proj: float = maxf(0.0, spell_def.weight_projectile)
	var w_aoe:  float = maxf(0.0, spell_def.weight_aoe)
	var total: float  = w_proj + w_aoe
	if total <= 0.0:
		return SpellItemDef.DeliveryMode.PROJECTILE
	var r: float = rng.randf() * total
	if r < w_proj:
		return SpellItemDef.DeliveryMode.PROJECTILE
	return SpellItemDef.DeliveryMode.AOE


static func _static_roll_attributes(inst: ItemInstance, bt: BaseItemType, item_seed: int, count: int, chosen_mode: int) -> void:
	if count <= 0:
		return
	if bt.pool_def == null:
		push_warning("[ItemSpawner] BaseItemType '%s' has no pool_def — skipping attributes." % str(bt.id))
		return

	var category: int = int(inst.def.category) if inst.def != null else int(bt.item_def.category)
	var pool: Array[ItemAttribute] = AttributePoolBuilder.build_pool(bt, category, chosen_mode, bt.get_weapon_token())

	var filtered: Array[ItemAttribute] = []
	for a: ItemAttribute in pool:
		if a != null and a.resource_path != "":
			filtered.append(a)
	if filtered.is_empty():
		return

	var remaining: int = mini(count, filtered.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = int((item_seed * 1664525 + 1013904223) & 0x7fffffff)

	while inst.attributes.size() < count and filtered.size() > 0 and remaining > 0:
		var i: int = rng.randi_range(0, filtered.size() - 1)
		var chosen: ItemAttribute = filtered[i]
		filtered.remove_at(i)
		if chosen == null:
			continue
		var dup: ItemAttribute = chosen.duplicate(true) as ItemAttribute
		if dup == null:
			continue
		inst.attributes.append(dup)
		remaining -= 1

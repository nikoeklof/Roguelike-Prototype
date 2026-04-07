extends Node
class_name LoadoutAssigner

## Assigns equipment to an entity at spawn time using the world seed.
## Attach as a child of any Entity. Works for both player and enemies.
##
## Pools take BaseItemType resources (.tres), NOT scenes.
## The system uses ItemSpawner's logic to resolve the correct scene template
## and roll attributes/stats automatically.

## BaseItemType resource pools — drag your .tres files here in the inspector.
@export var melee_pool: Array[BaseItemType] = []
@export var ranged_pool: Array[BaseItemType] = []
@export var spell_pool: Array[BaseItemType] = []
@export var shield_pool: Array[BaseItemType] = []

## Guaranteed slots — if true, this slot ALWAYS gets an item.
@export var guarantee_melee: bool = false
@export var guarantee_ranged: bool = false
@export var guarantee_spell: bool = false
@export var guarantee_shield: bool = false

## Chance to equip from each pool (0.0 to 1.0). Ignored if guarantee is true.
@export_range(0.0, 1.0, 0.01) var melee_chance: float = 1.0
@export_range(0.0, 1.0, 0.01) var ranged_chance: float = 0.5
@export_range(0.0, 1.0, 0.01) var spell_chance: float = 0.3
@export_range(0.0, 1.0, 0.01) var shield_chance: float = 0.3

## If true, only assigns to empty slots (won't replace existing items).
@export var only_if_empty: bool = true

## Optional: override seed instead of using WorldSeed autoload.
## Set to -1 to use WorldSeed (default).
@export var seed_override: int = -1

@export var equipment_path: NodePath = NodePath("../Equipment")

# Scene templates — same ones ItemSpawner uses
const MELEE_TEMPLATE: PackedScene = preload("res://Scenes/Templates/EquipmentItems/Melee_Weapon_Template.tscn")
const RANGED_TEMPLATE: PackedScene = preload("res://Scenes/Templates/EquipmentItems/Ranged_Weapon_template.tscn")
const SPELL_BUFF_TEMPLATE: PackedScene = preload("res://Scenes/Items/Spells/Spell_Buff_Template.tscn")
const SPELL_DEBUFF_TEMPLATE: PackedScene = preload("res://Scenes/Items/Spells/Spell_Debuff_Template.tscn")
const SHIELD_ACTIVE_TEMPLATE: PackedScene = preload("res://Scenes/Items/Shields/Shield_Active_Template.tscn")
const SHIELD_PASSIVE_TEMPLATE: PackedScene = preload("res://Scenes/Items/Shields/Shield_Passive_Template.tscn")


func _ready() -> void:
	# Defer to ensure Equipment slots have finished their _ready()
	call_deferred("_assign_loadout")


func _assign_loadout() -> void:
	var equipment: Equipment = get_node_or_null(equipment_path) as Equipment
	if equipment == null:
		push_warning("[LoadoutAssigner] Equipment not found at %s" % equipment_path)
		return
	
	# Build a deterministic seed from the world seed + this entity's path
	var base_seed: int = seed_override
	if base_seed == -1:
		var world_seed_node: Node = get_node_or_null("/root/WorldSeed")
		if world_seed_node != null and world_seed_node.has_method("derive"):
			base_seed = world_seed_node.derive("loadout", str(get_parent().get_path()))
		else:
			base_seed = hash(str(get_parent().get_path()))
			push_warning("[LoadoutAssigner] WorldSeed autoload not found, using path hash as seed")
	
	var rng := RandomNumberGenerator.new()
	rng.seed = base_seed
	
	# Roll each slot
	_try_assign_slot(equipment, "MeleeSlot", melee_pool, guarantee_melee, melee_chance, rng)
	_try_assign_slot(equipment, "RangedSlot", ranged_pool, guarantee_ranged, ranged_chance, rng)
	_try_assign_slot(equipment, "SpellSlot", spell_pool, guarantee_spell, spell_chance, rng)
	_try_assign_slot(equipment, "ShieldSlot", shield_pool, guarantee_shield, shield_chance, rng)
	
	print("[LoadoutAssigner] Loadout assigned for %s" % get_parent().name)


func _try_assign_slot(
	equipment: Equipment,
	slot_name: String,
	pool: Array[BaseItemType],
	guaranteed: bool,
	chance: float,
	rng: RandomNumberGenerator
) -> void:
	if pool.is_empty():
		return
	
	var slot: Node = equipment.get_node_or_null(slot_name)
	if slot == null:
		return
	
	# Check if slot already has an item
	if only_if_empty and slot.has_method("get_item"):
		var existing: Node = slot.call("get_item") as Node
		if existing != null:
			return
	
	# Roll whether to equip
	if not guaranteed:
		var roll: float = rng.randf()
		if roll > chance:
			return
	
	# Pick a BaseItemType from the pool
	var base_type: BaseItemType = pool[rng.randi_range(0, pool.size() - 1)]
	if base_type == null or base_type.item_def == null:
		push_warning("[LoadoutAssigner] BaseItemType or its item_def is null in %s pool" % slot_name)
		return
	
	# Generate a unique item seed for this slot
	var item_seed: int = _make_item_seed(rng)
	
	# Roll a full ItemInstance (stats, attributes, ranged mode — same as ItemSpawner)
	var inst: ItemInstance = _roll_instance(base_type, item_seed, rng)
	if inst == null:
		push_warning("[LoadoutAssigner] Failed to roll ItemInstance for %s" % str(base_type.id))
		return
	
	# Create the equipment node from the correct scene template
	var item_node: Node = _make_equipment_item(inst, base_type)
	if item_node == null:
		push_warning("[LoadoutAssigner] Failed to create equipment node for %s" % str(base_type.id))
		return
	
	# Equip it
	if slot.has_method("set_item"):
		slot.call("set_item", item_node, true)
		print("[LoadoutAssigner] Equipped %s in %s (%d attributes)" % [
			base_type.item_def.display_name, slot_name, inst.attributes.size()
		])
	else:
		push_warning("[LoadoutAssigner] Slot %s has no set_item method" % slot_name)
		item_node.queue_free()


func _roll_instance(base_type: BaseItemType, item_seed: int, rng: RandomNumberGenerator) -> ItemInstance:
	"""Roll a complete ItemInstance from a BaseItemType — mirrors ItemSpawner logic."""
	var inst := ItemInstance.new()
	inst.def = base_type.item_def
	inst.seed = item_seed
	inst.ensure_initialized()
	
	# Apply starting stat levels from the BaseItemType
	_apply_starting_stat_levels(inst, base_type)
	
	# Roll attribute count
	var attr_count: int = _roll_attr_count(rng, base_type.min_attribute_count, base_type.max_attribute_count)
	
	# Roll ranged mode if applicable
	var chosen_mode: int = -1
	if int(base_type.item_def.category) == ItemDef.Category.RANGED and base_type.use_ranged_mode_roll:
		chosen_mode = _roll_ranged_mode(rng, base_type)
		inst.ranged_mode = chosen_mode
	
	# Roll attributes from the BaseItemType's pool
	_roll_attributes(inst, base_type, rng, attr_count, chosen_mode)
	
	return inst


func _make_equipment_item(inst: ItemInstance, base_type: BaseItemType) -> Node:
	"""Create the correct scene node and inject the ItemInstance — mirrors ItemSpawner logic."""
	if inst == null or inst.def == null:
		return null
	
	var cat := int(inst.def.category)
	var scene: PackedScene = null
	
	match cat:
		ItemDef.Category.MELEE:
			scene = MELEE_TEMPLATE
		ItemDef.Category.RANGED:
			scene = RANGED_TEMPLATE
		ItemDef.Category.SPELL:
			var spell_def: SpellItemDef = inst.def as SpellItemDef
			if spell_def != null:
				match spell_def.spell_type:
					SpellItemDef.SpellType.BUFF:
						scene = SPELL_BUFF_TEMPLATE
					SpellItemDef.SpellType.DEBUFF:
						scene = SPELL_DEBUFF_TEMPLATE
			else:
				scene = SPELL_BUFF_TEMPLATE
		ItemDef.Category.SHIELD:
			var shield_def: ShieldItemDef = inst.def as ShieldItemDef
			if shield_def != null:
				match shield_def.shield_type:
					ShieldItemDef.ShieldType.ACTIVE:
						scene = SHIELD_ACTIVE_TEMPLATE
					ShieldItemDef.ShieldType.PASSIVE:
						scene = SHIELD_PASSIVE_TEMPLATE
			else:
				scene = SHIELD_ACTIVE_TEMPLATE
	
	if scene == null:
		return null
	
	var node: Node = scene.instantiate()
	
	# Inject the fully rolled instance BEFORE the node enters the tree
	# This prevents _ready() from creating a plain instance
	if node.has_method(&"set_item_instance"):
		node.call(&"set_item_instance", inst)
	else:
		# Fallback for older nodes
		if "item_def" in node:
			node.set("item_def", inst.def)
		if "item_seed" in node:
			node.set("item_seed", inst.seed)
	
	return node


# --- Rolling helpers (mirrors ItemSpawner) ---

func _apply_starting_stat_levels(inst: ItemInstance, bt: BaseItemType) -> void:
	if bt.start_stat_levels.is_empty():
		return
	for k: Variant in bt.start_stat_levels.keys():
		var key: StringName = StringName(k)
		inst.stat_levels[key] = int(bt.start_stat_levels[k])


func _roll_attr_count(rng: RandomNumberGenerator, min_c: int, max_c: int) -> int:
	var lo: int = mini(min_c, max_c)
	var hi: int = maxi(min_c, max_c)
	if hi <= lo:
		return lo
	return rng.randi_range(lo, hi)


func _roll_ranged_mode(rng: RandomNumberGenerator, bt: BaseItemType) -> int:
	if bt.locked_ranged_mode >= 0:
		return bt.locked_ranged_mode
	
	var w_proj: float = maxf(0.0, bt.weight_projectile)
	var w_hit: float = maxf(0.0, bt.weight_hitscan)
	var w_beam: float = maxf(0.0, bt.weight_beam)
	
	var total: float = w_proj + w_hit + w_beam
	if total <= 0.0:
		return RangedShotData.ShotMode.PROJECTILE
	
	var r: float = rng.randf() * total
	if r < w_proj:
		return RangedShotData.ShotMode.PROJECTILE
	r -= w_proj
	if r < w_hit:
		return RangedShotData.ShotMode.HITSCAN
	return RangedShotData.ShotMode.BEAM


func _roll_attributes(inst: ItemInstance, bt: BaseItemType, rng: RandomNumberGenerator, count: int, chosen_mode: int) -> void:
	if count <= 0:
		return
	
	var pool: Array[ItemAttribute] = []
	
	if bt.pool_def != null:
		var category: int = int(inst.def.category) if inst.def != null else int(bt.item_def.category)
		var weapon_token: String = bt.get_weapon_token()
		pool = AttributePoolBuilder.build_pool(bt, category, chosen_mode, weapon_token)
	else:
		push_warning("[LoadoutAssigner] BaseItemType '%s' has no pool_def. Skipping attributes." % str(bt.id))
		return
	
	if pool.is_empty():
		return
	
	# Filter out placeholders
	var filtered: Array[ItemAttribute] = []
	for a: ItemAttribute in pool:
		if a == null:
			continue
		if a.resource_path == "":
			continue
		filtered.append(a)
	pool = filtered
	
	if pool.is_empty():
		return
	
	var remaining_budget: int = mini(count, pool.size())
	
	while inst.attributes.size() < count and pool.size() > 0 and remaining_budget > 0:
		var pick_i: int = rng.randi_range(0, pool.size() - 1)
		var chosen: ItemAttribute = pool[pick_i]
		pool.remove_at(pick_i)
		
		if chosen == null:
			continue
		
		var dup_res: Resource = chosen.duplicate(true)
		var dup_attr: ItemAttribute = dup_res as ItemAttribute
		if dup_attr == null:
			continue
		
		inst.attributes.append(dup_attr)
		remaining_budget -= 1


func _make_item_seed(rng: RandomNumberGenerator) -> int:
	return rng.randi() & 0x7fffffff

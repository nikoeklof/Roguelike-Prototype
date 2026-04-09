extends Node
class_name InitialLoadoutRoller

@export var equipment_path: NodePath = NodePath("../Equipment")

# Curated starter pools (BaseItemType .tres resources).
@export var starter_melee: Array[BaseItemType] = []
@export var starter_ranged: Array[BaseItemType] = []
@export var starter_spell: Array[BaseItemType] = []
@export var starter_shield: Array[BaseItemType] = []

# If you have a run manager, set run_seed from there (or call roll_and_equip(run_seed)).
@export var fallback_run_seed: int = 12345

@export var melee_slot_id: StringName = &"melee"
@export var ranged_slot_id: StringName = &"ranged"
@export var spell_slot_id: StringName = &"spell"
@export var shield_slot_id: StringName = &"shield"

# Optional: if true, only rolls when slots are empty.
@export var only_if_empty: bool = true

func _ready() -> void:
	roll_and_equip()

func roll_and_equip(run_seed: int = -1) -> void:
	var eq: Node = get_node_or_null(equipment_path)
	if eq == null:
		push_error("InitialLoadoutRoller: Equipment node not found at %s" % [equipment_path])
		return

	var seed: int = run_seed if run_seed != -1 else fallback_run_seed

	_equip_from_pool(eq, melee_slot_id, starter_melee, _slot_seed(seed, "melee"))
	_equip_from_pool(eq, ranged_slot_id, starter_ranged, _slot_seed(seed, "ranged"))
	_equip_from_pool(eq, spell_slot_id, starter_spell, _slot_seed(seed, "spell"))
	_equip_from_pool(eq, shield_slot_id, starter_shield, _slot_seed(seed, "shield"))

func _equip_from_pool(eq: Node, slot_id: StringName, pool: Array[BaseItemType], seed: int) -> void:
	if pool.is_empty():
		return

	if only_if_empty and eq.has_method("get_item_instance"):
		var existing: ItemInstance = eq.get_item_instance(slot_id)
		if existing != null:
			return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var base_type: BaseItemType = pool[rng.randi_range(0, pool.size() - 1)]

	var inst: ItemInstance = _roll_item_instance_from_base_type(base_type, seed)

	if eq.has_method("equip_item_instance"):
		eq.equip_item_instance(slot_id, inst)
	else:
		push_error("Equipment missing equip_item_instance(slot_id, ItemInstance). Implement this on Equipment.")

func _roll_item_instance_from_base_type(base_type: BaseItemType, item_seed: int) -> ItemInstance:
	# Mirrors ItemSpawner.spawn_with_run_seed(), but returns ItemInstance only.
	var inst := ItemInstance.new()
	inst.def = base_type.item_def
	inst.seed = item_seed
	inst.ensure_initialized()

	# Use ItemSpawner logic to keep behavior identical (attr count roll, ranged mode selection, pool building).
	var sp := ItemSpawner.new()
	sp.base_type = base_type

	sp._apply_starting_stat_levels(inst, base_type)

	var attr_count: int = sp._roll_attr_count(item_seed, base_type.min_attribute_count, base_type.max_attribute_count)

	var chosen_mode: int = -1
	if int(base_type.item_def.category) == ItemDef.Category.RANGED and base_type.use_ranged_mode_roll:
		chosen_mode = sp._roll_ranged_mode(item_seed, base_type)
		inst.ranged_mode = chosen_mode

	sp._roll_attributes(inst, base_type, item_seed, attr_count, chosen_mode)

	return inst

func _slot_seed(run_seed: int, slot_key: String) -> int:
	# Stable combinator seed. If you have SeedUtils.hash_combine, replace this with it.
	return _hash3(run_seed, "player_loadout", slot_key)

func _hash3(a: int, b: String, c: String) -> int:
	var h: int = 2166136261
	h = int((h ^ a) * 16777619) & 0x7fffffff
	h = int((h ^ b.hash()) * 16777619) & 0x7fffffff
	h = int((h ^ c.hash()) * 16777619) & 0x7fffffff
	return h

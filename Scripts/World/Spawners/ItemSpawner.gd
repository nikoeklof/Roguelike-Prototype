extends Node2D
class_name ItemSpawner

@export var pickup_scene: PackedScene
@export var base_type: BaseItemType

@export var auto_spawn_when_no_floor_spawner: bool = true

@export var spawn_id: StringName = &""
@export var drop_index: int = 0

@export var use_auto_id_if_empty: bool = true
@export var auto_room_coord: Vector2i = Vector2i.ZERO
@export var auto_room_local_index: int = -1

@export var run_seed_override_enabled: bool = false
@export var run_seed_override: int = 0
var _spawned: bool = false
const MELEE_TEMPLATE : PackedScene = preload("res://Scenes/Templates/EquipmentItems/Melee_Weapon_Template.tscn")
const RANGED_TEMPLATE : PackedScene = preload("res://Scenes/Templates/EquipmentItems/Ranged_Weapon_template.tscn")
const SPELL_BUFF_TEMPLATE: PackedScene = preload("res://Scenes/Items/Spells/Spell_Buff_Template.tscn")
const SPELL_DEBUFF_TEMPLATE : PackedScene = preload("res://Scenes/Items/Spells/Spell_Debuff_Template.tscn")
const SHIELD_ACTIVE_TEMPLATE : PackedScene = preload("res://Scenes/Items/Shields/Shield_Active_Template.tscn")
const SHIELD_PASSIVE_TEMPLATE : PackedScene = preload("res://Scenes/Items/Shields/Shield_Passive_Template.tscn")



func _ready() -> void:
	# In authored floor rooms, FloorSpawner will call spawn_with_run_seed().
	# In sandbox scenes, we auto-spawn on ready for fast iteration.
	if Engine.is_editor_hint():
		return
	if _spawned:
		return
	if not auto_spawn_when_no_floor_spawner:
		return
	var fs: Node = get_tree().get_first_node_in_group("floor_spawner")
	if fs != null:
		return
	# Use override if enabled, else default to 0 for sandbox.
	spawn()

static func roll_preview(bt: BaseItemType, seed: int) -> ItemInstance:
	if bt == null or bt.item_def == null:
		return null

	var inst: ItemInstance = ItemInstance.new()
	inst.def = bt.item_def
	inst.seed = seed
	inst.ensure_initialized()

	var spawner := ItemSpawner.new()
	spawner._apply_starting_stat_levels(inst, bt)

	var attr_count: int = spawner._roll_attr_count(seed, bt.min_attribute_count, bt.max_attribute_count)

	var chosen_mode: int = -1
	if int(bt.item_def.category) == ItemDef.Category.RANGED and bt.use_ranged_mode_roll:
		chosen_mode = spawner._roll_ranged_mode(seed, bt)
		inst.ranged_mode = chosen_mode

	spawner._roll_attributes(inst, bt, seed, attr_count, chosen_mode)
	return inst


func spawn_with_run_seed(run_seed: int) -> Node:
	if _spawned:
		return null
	_spawned = true

	if base_type == null or base_type.item_def == null:
		push_warning("ItemSpawner: Missing base_type/item_def.")
		return null

	# If pickup_scene is not set, fall back to the default ground pickup scene.
	if pickup_scene == null:
		pickup_scene = load("res://Scenes/Templates/World/GroundItemPickup.tscn")
		if pickup_scene == null:
			push_warning("ItemSpawner: pickup_scene is null and default GroundItemPickup.tscn could not be loaded.")
			return null


	var sid: StringName = spawn_id
	if sid == StringName() or String(sid).is_empty():
		if use_auto_id_if_empty:
			sid = _compute_auto_spawn_id()
		if sid == StringName() or String(sid).is_empty():
			sid = StringName(String(get_path()))

	var final_seed: int = run_seed_override if run_seed_override_enabled else run_seed
	var item_seed: int = _make_drop_seed(final_seed, sid, drop_index)

	var inst: ItemInstance = ItemInstance.new()
	inst.def = base_type.item_def
	inst.seed = item_seed
	inst.ensure_initialized()

	_apply_starting_stat_levels(inst, base_type)

	var attr_count: int = _roll_attr_count(item_seed, base_type.min_attribute_count, base_type.max_attribute_count)

	var chosen_mode: int = -1
	if int(base_type.item_def.category) == ItemDef.Category.RANGED and base_type.use_ranged_mode_roll:
		chosen_mode = _roll_ranged_mode(item_seed, base_type)
		inst.ranged_mode = chosen_mode

	_roll_attributes(inst, base_type, item_seed, attr_count, chosen_mode)

	var pickup_node: Node = pickup_scene.instantiate()
	if not (pickup_node is EquipmentSwapPickup):
		pickup_node.queue_free()
		return null

	var pickup: EquipmentSwapPickup = pickup_node as EquipmentSwapPickup
	var equip_item: Node = _make_equipment_item(inst)
	if equip_item == null:
		pickup.queue_free()
		return null
	pickup.set_item(equip_item)
	get_parent().add_child.call_deferred(pickup)
	pickup.set_deferred("global_position", global_position)
	return pickup


func spawn() -> Node:
	var seed_value: int = run_seed_override if run_seed_override_enabled else 0
	return spawn_with_run_seed(seed_value)


func _compute_auto_spawn_id() -> StringName:
	if auto_room_local_index < 0:
		return &""
	return StringName("room_%d_%d_pickup_%d" % [auto_room_coord.x, auto_room_coord.y, auto_room_local_index])


func _make_equipment_item(inst: ItemInstance) -> Node:

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
			var spell_def : SpellItemDef = inst.def as SpellItemDef;
			if spell_def != null:
				match spell_def.spell_type:
					SpellItemDef.SpellType.BUFF:
						scene = preload("res://Scenes/Items/Spells/Spell_Buff_Template.tscn")
					SpellItemDef.SpellType.DEBUFF:
						scene = preload("res://Scenes/Items/Spells/Spell_Debuff_Template.tscn")
			else:
				scene = preload("res://Scenes/Items/Spells/Spell_Buff_Template.tscn")  # Default to buff
		ItemDef.Category.SHIELD:
				var shield_def: ShieldItemDef = inst.def as ShieldItemDef
				if shield_def != null:
					match shield_def.shield_type:
						ShieldItemDef.ShieldType.ACTIVE:
							scene = SHIELD_ACTIVE_TEMPLATE
						ShieldItemDef.ShieldType.PASSIVE:
							scene = SHIELD_PASSIVE_TEMPLATE
				else:
					scene = SHIELD_ACTIVE_TEMPLATE  # Default fallback

	if scene == null:
		return null

	var n: Node = scene.instantiate()

	# Preferred path: inject instance directly
	if n.has_method(&"set_item_instance"):
		n.call(&"set_item_instance", inst)
	else:
		# Fallback for older nodes: set def/seed if fields exist
		if "item_def" in n:
			n.set("item_def", inst.def)
		if "item_seed" in n:
			n.set("item_seed", inst.seed)

	return n

func _make_drop_seed(run_seed: int, id: StringName, idx: int) -> int:
	var h: int = int(hash(id))
	var s: int = run_seed
	s = int((s * 1103515245 + 12345) & 0x7fffffff)
	s = int((s ^ h) & 0x7fffffff)
	s = int((s + idx * 1013) & 0x7fffffff)
	return s


func _roll_attr_count(seed: int, min_c: int, max_c: int) -> int:
	var lo: int = mini(min_c, max_c)
	var hi: int = maxi(min_c, max_c)
	if hi <= lo:
		return lo
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	return rng.randi_range(lo, hi)


func _apply_starting_stat_levels(inst: ItemInstance, bt: BaseItemType) -> void:
	if bt.start_stat_levels.is_empty():
		return
	for k: Variant in bt.start_stat_levels.keys():
		var key: StringName = StringName(k)
		inst.stat_levels[key] = int(bt.start_stat_levels[k])


func _roll_ranged_mode(seed: int, bt: BaseItemType) -> int:
	if bt.locked_ranged_mode >= 0:
		return bt.locked_ranged_mode

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int((seed * 2246822519 + 3266489917) & 0x7fffffff)

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


func _roll_attributes(inst: ItemInstance, bt: BaseItemType, seed: int, count: int, chosen_mode: int) -> void:
	if count <= 0:
		return

	var pool: Array[ItemAttribute] = []

	# Pool Resources path (preferred)
	if bt != null and bt.pool_def != null:
		var category: int = int(inst.def.category) if inst.def != null else int(bt.item_def.category)
		var weapon_token: String = _derive_weapon_token_from_exports(bt)
		pool = AttributePoolBuilder.build_pool(bt, category, chosen_mode, weapon_token)
	else:
		push_error("ItemSpawner: BaseItemType '%s' has no pool_def set. pool_def is required." % [String(bt.id) if bt != null else "<null>"])
		return

	if pool.is_empty():
		return

	# Filter out placeholder / invalid templates up-front
	var filtered: Array[ItemAttribute] = []
	for a: ItemAttribute in pool:
		if a == null:
			continue
		# Placeholder resources often have empty resource_path
		if a.resource_path == "":
			continue
		filtered.append(a)
	pool = filtered

	if pool.is_empty():
		return

	# Do not roll more than available (avoid endless loop)
	var remaining_budget: int = mini(count, pool.size())

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int((seed * 1664525 + 1013904223) & 0x7fffffff)

	while inst.attributes.size() < count and pool.size() > 0 and remaining_budget > 0:
		var pick_i: int = rng.randi_range(0, pool.size() - 1)

		var chosen: ItemAttribute = pool[pick_i]
		pool.remove_at(pick_i)

		if chosen == null:
			continue

		# Duplicate safely
		var dup_res: Resource = chosen.duplicate(true)
		var dup_attr: ItemAttribute = dup_res as ItemAttribute
		if dup_attr == null:
			continue

		# Keep real duplicated runtime attributes.
		# Placeholder filtering already happened earlier on the source pool entry.
		inst.attributes.append(dup_attr)

		remaining_budget -= 1


func _derive_weapon_token_from_exports(bt: BaseItemType) -> String:
	if bt == null:
		return ""

	var t: String = String(bt.auto_weapon_token).strip_edges()
	if not t.is_empty():
		return _to_token(t)

	if bt.id != &"":
		return _to_token(str(bt.id))

	if bt.item_def != null:
		if bt.item_def.id != &"":
			return _to_token(str(bt.item_def.id))
		var dn: String = String(bt.item_def.display_name).strip_edges()
		if not dn.is_empty():
			return _to_token(dn)

	return ""


func _to_token(s: String) -> String:
	var in_s: String = s.strip_edges()
	if in_s.is_empty():
		return ""

	var out: String = ""
	for i: int in range(in_s.length()):
		var ch: String = in_s[i]
		var code: int = ch.unicode_at(0)
		var is_alnum: bool = (
			(code >= 48 and code <= 57) or
			(code >= 65 and code <= 90) or
			(code >= 97 and code <= 122)
		)
		out += ch if is_alnum else "_"

	while out.find("__") != -1:
		out = out.replace("__", "_")
	while out.begins_with("_"):
		out = out.substr(1)
	while out.ends_with("_"):
		out = out.substr(0, out.length() - 1)

	return out

static func get_shield_display_info(inst: ItemInstance) -> Dictionary:
	"""Return shield stats formatted for UI display"""
	if inst == null or inst.def == null:
		return {}
	
	var shield_def: ShieldItemDef = inst.def as ShieldItemDef
	if shield_def == null:
		return {}
	
	var info: Dictionary = {
		"type": ShieldItemDef.ShieldType.keys()[shield_def.shield_type],
	}
	
	match shield_def.shield_type:
		ShieldItemDef.ShieldType.ACTIVE:
			info["block_damage_reduction"] = "%.0f%%" % (shield_def.block_damage_reduction * 100.0)
			info["movement_speed_while_blocking"] = "%.0f%%" % (shield_def.movement_speed_mult_while_blocking * 100.0)
		
		ShieldItemDef.ShieldType.PASSIVE:
			info["damage_reduction"] = "%.0f%%" % (shield_def.passive_damage_reduction_mult * 100.0)
			info["movement_speed"] = "%.0f%%" % (shield_def.passive_movement_speed_mult * 100.0)
			info["flat_reduction"] = "%.1f" % shield_def.flat_damage_reduction
	
	return info

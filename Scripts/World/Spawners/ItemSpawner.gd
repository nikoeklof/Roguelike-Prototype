extends Node2D
class_name ItemSpawner

@export var pickup_scene: PackedScene
@export var base_type: BaseItemType

@export var spawn_id: StringName = &""
@export var drop_index: int = 0

@export var use_auto_id_if_empty: bool = true
@export var auto_room_coord: Vector2i = Vector2i.ZERO
@export var auto_room_local_index: int = -1

@export var run_seed_override_enabled: bool = false
@export var run_seed_override: int = 0

var _spawned: bool = false


func spawn_with_run_seed(run_seed: int) -> Node:
	if _spawned:
		return null
	_spawned = true

	if base_type == null:
		push_warning("ItemSpawner: base_type missing.")
		return null
	if base_type.item_def == null:
		push_warning("ItemSpawner: base_type.item_def missing.")
		return null
	if pickup_scene == null:
		push_warning("ItemSpawner: pickup_scene missing.")
		return null

	var sid: StringName = spawn_id
	if sid == StringName() or String(sid).is_empty():
		if use_auto_id_if_empty:
			sid = _compute_auto_spawn_id()
		if sid == StringName() or String(sid).is_empty():
			sid = StringName(String(get_path()))
			push_warning("ItemSpawner: spawn_id empty; falling back to NodePath id: %s" % String(sid))

	var final_seed: int = run_seed_override if run_seed_override_enabled else run_seed
	var item_seed: int = _make_drop_seed(final_seed, sid, drop_index)

	var inst: ItemInstance = ItemInstance.new()
	inst.def = base_type.item_def
	inst.seed = item_seed
	inst.ensure_initialized()

	_apply_starting_stat_levels(inst, base_type)

	var attr_count: int = _roll_attr_count(item_seed, base_type.min_attribute_count, base_type.max_attribute_count)

	# If ranged: choose shot mode first and (optionally) force its mode attribute.
	var chosen_mode: int = -1
	if int(base_type.item_def.category) == ItemDef.Category.RANGED and base_type.use_ranged_mode_roll:
		chosen_mode = _roll_ranged_mode(item_seed, base_type)

		if base_type.force_mode_attribute:
			_force_mode_attribute_if_needed(inst, base_type, chosen_mode)

	# Roll remaining attributes (minus forced mode attr, if any)
	_roll_attributes(inst, base_type, item_seed, attr_count, chosen_mode)

	var pickup_node: Node = pickup_scene.instantiate()
	if not (pickup_node is EquipmentSwapPickup):
		push_warning("ItemSpawner: pickup_scene is not EquipmentSwapPickup.")
		pickup_node.queue_free()
		return null

	var pickup: EquipmentSwapPickup = pickup_node as EquipmentSwapPickup

	var item_node: ItemNode = ItemNode.new()
	item_node.set_item_instance(inst)
	pickup.set_item(item_node)

	get_parent().add_child(pickup)
	pickup.global_position = global_position

	return pickup


func spawn() -> Node:
	var seed_value: int = run_seed_override if run_seed_override_enabled else 0
	return spawn_with_run_seed(seed_value)


# ------------------------------------------------------------
# Deterministic identity / seed helpers
# ------------------------------------------------------------

func _compute_auto_spawn_id() -> StringName:
	if auto_room_local_index < 0:
		return &""
	return StringName("room_%d_%d_pickup_%d" % [auto_room_coord.x, auto_room_coord.y, auto_room_local_index])


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


# ------------------------------------------------------------
# Item building
# ------------------------------------------------------------

func _apply_starting_stat_levels(inst: ItemInstance, bt: BaseItemType) -> void:
	if bt.start_stat_levels.is_empty():
		return

	for k: Variant in bt.start_stat_levels.keys():
		var key: StringName = StringName(k)
		inst.stat_levels[key] = int(bt.start_stat_levels[k])


func _roll_ranged_mode(seed: int, bt: BaseItemType) -> int:
	# Lock override
	if bt.locked_ranged_mode >= 0:
		return bt.locked_ranged_mode

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	# Different stream from attributes to keep stable behavior when pool changes
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


func _force_mode_attribute_if_needed(inst: ItemInstance, bt: BaseItemType, mode: int) -> void:
	# PROJECTILE is default → no forced mode attribute needed.
	if mode == RangedShotData.ShotMode.PROJECTILE:
		return

	var root: String = bt.auto_attribute_root
	if root.is_empty():
		return

	# Expect exact mode attribute filenames:
	# Attr_Ranged_Mode_Hitscan.tres
	# Attr_Ranged_Mode_Beam.tres
	var fname: String = ""
	if mode == RangedShotData.ShotMode.HITSCAN:
		fname = "Attr_Ranged_Mode_Hitscan.tres"
	elif mode == RangedShotData.ShotMode.BEAM:
		fname = "Attr_Ranged_Mode_Beam.tres"
	else:
		return

	var path: String = root.path_join(fname)
	var res: Resource = ResourceLoader.load(path)
	if res == null or not (res is ItemAttribute):
		push_warning("ItemSpawner: missing mode attribute resource: %s" % path)
		return

	var template: ItemAttribute = res as ItemAttribute
	var dup_res: Resource = template.duplicate(true)
	if dup_res is ItemAttribute:
		inst.attributes.append(dup_res as ItemAttribute)


func _roll_attributes(inst: ItemInstance, bt: BaseItemType, seed: int, count: int, chosen_mode: int) -> void:
	if count <= 0:
		return

	var pool: Array[ItemAttribute] = []
	var weights: Array[float] = []

	# Manual pool wins if present.
	if bt.has_manual_pool():
		pool = bt.allowed_attributes.duplicate()
		weights = bt.attribute_weights.duplicate()
	else:
		if not bt.use_auto_attribute_pool:
			return
		pool = _build_auto_pool(bt, chosen_mode)
		weights = [] # uniform for auto pools

	if pool.is_empty():
		return

	# Do not roll more than available (avoid endless loop)
	var max_roll: int = mini(count, pool.size())

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int((seed * 1664525 + 1013904223) & 0x7fffffff)

	var use_weights: bool = (weights.size() == pool.size())

	# We may have already forced 1 mode attribute; keep rolling until total reaches count.
	while inst.attributes.size() < count and pool.size() > 0 and max_roll > 0:
		var pick_i: int = 0
		if use_weights:
			pick_i = _weighted_pick_index(rng, weights, pool.size())
		else:
			pick_i = rng.randi_range(0, pool.size() - 1)

		var chosen: ItemAttribute = pool[pick_i]
		pool.remove_at(pick_i)
		if use_weights:
			weights.remove_at(pick_i)

		if chosen == null:
			continue

		# Safety: prevent rolling mode attributes from other modes
		# (We already forced the correct one, and pool shouldn’t include others — but belt+suspenders.)
		if _is_mode_attribute(chosen) and not _is_mode_attribute_for_mode(chosen, chosen_mode):
			continue

		var dup_res: Resource = chosen.duplicate(true)
		if dup_res is ItemAttribute:
			inst.attributes.append(dup_res as ItemAttribute)

		max_roll -= 1


func _is_mode_attribute(attr: ItemAttribute) -> bool:
	if attr == null:
		return false
	# Use filename convention for mode attribute resources
	var file: String = attr.resource_path.get_file()
	return file.begins_with("Attr_Ranged_Mode_")


func _is_mode_attribute_for_mode(attr: ItemAttribute, mode: int) -> bool:
	if attr == null:
		return false
	var file: String = attr.resource_path.get_file()
	if mode == RangedShotData.ShotMode.HITSCAN:
		return file == "Attr_Ranged_Mode_Hitscan.tres"
	if mode == RangedShotData.ShotMode.BEAM:
		return file == "Attr_Ranged_Mode_Beam.tres"
	# Projectile: we expect no mode attribute forced/allowed
	return false


func _build_auto_pool(bt: BaseItemType, chosen_mode: int) -> Array[ItemAttribute]:
	var out: Array[ItemAttribute] = []

	var root: String = bt.auto_attribute_root
	if root.is_empty():
		return out

	var token: String = bt.get_weapon_token()

	# Global always allowed
	if bt.auto_include_global:
		_append_all(out, _load_attributes_by_prefix(root, "Attr_Global_"))

	var cat: int = int(bt.item_def.category)

	if cat == ItemDef.Category.MELEE:
		_append_all(out, _load_attributes_by_prefix(root, "Attr_Melee_Common_"))
		if token != "":
			_append_all(out, _load_attributes_by_prefix(root, "Attr_Melee_Weapon_%s_" % token))
		return out

	if cat == ItemDef.Category.RANGED:
		# Ranged common
		_append_all(out, _load_attributes_by_prefix(root, "Attr_Ranged_Common_"))

		# Weapon-specific (any-mode)
		if token != "":
			_append_all(out, _load_attributes_by_prefix(root, "Attr_Ranged_Weapon_%s_" % token))

		# Mode-specific pools
		var mode_prefix: String = ""
		if chosen_mode == RangedShotData.ShotMode.HITSCAN:
			mode_prefix = "Attr_Ranged_Mode_Hitscan_"
		elif chosen_mode == RangedShotData.ShotMode.BEAM:
			mode_prefix = "Attr_Ranged_Mode_Beam_"
		else:
			mode_prefix = "Attr_Ranged_Mode_Projectile_"

		_append_all(out, _load_attributes_by_prefix(root, mode_prefix))

		# Weapon + mode pool (most specific)
		if token != "":
			_append_all(out, _load_attributes_by_prefix(root, "Attr_Ranged_Weapon_%s_%s" % [token, mode_prefix.replace("Attr_Ranged_", "")]))

		# Also: avoid accidentally including the mode-enabler `.tres` itself in the random pool.
		# (We force it separately; leaving it out avoids duplicates.)
		out = _filter_out_mode_enablers(out)

		return out

	# Other categories ignored for now
	return out


func _filter_out_mode_enablers(arr: Array[ItemAttribute]) -> Array[ItemAttribute]:
	var out: Array[ItemAttribute] = []
	for a: ItemAttribute in arr:
		if a == null:
			continue
		var f: String = a.resource_path.get_file()
		if f == "Attr_Ranged_Mode_Hitscan.tres":
			continue
		if f == "Attr_Ranged_Mode_Beam.tres":
			continue
		out.append(a)
	return out


func _append_all(dst: Array[ItemAttribute], src: Array[ItemAttribute]) -> void:
	for a: ItemAttribute in src:
		dst.append(a)


func _load_attributes_by_prefix(root: String, prefix: String) -> Array[ItemAttribute]:
	var out: Array[ItemAttribute] = []

	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		push_warning("ItemSpawner: could not open attribute root: %s" % root)
		return out

	dir.list_dir_begin()
	var files: PackedStringArray = PackedStringArray()

	while true:
		var name: String = dir.get_next()
		if name == "":
			break

		if dir.current_is_dir():
			continue

		if not (name.ends_with(".tres") or name.ends_with(".res")):
			continue
		if not name.begins_with(prefix):
			continue

		files.append(name)

	dir.list_dir_end()

	files.sort()

	for fname: String in files:
		var path: String = root.path_join(fname)
		var res: Resource = ResourceLoader.load(path)
		if res == null:
			continue
		if res is ItemAttribute:
			out.append(res as ItemAttribute)

	return out


func _weighted_pick_index(rng: RandomNumberGenerator, weights: Array[float], size: int) -> int:
	if weights.size() != size:
		return rng.randi_range(0, size - 1)

	var total: float = 0.0
	for w: float in weights:
		total += max(0.0, w)

	if total <= 0.0:
		return rng.randi_range(0, size - 1)

	var r: float = rng.randf() * total
	var acc: float = 0.0

	for i: int in range(size):
		acc += max(0.0, weights[i])
		if r <= acc:
			return i

	return size - 1

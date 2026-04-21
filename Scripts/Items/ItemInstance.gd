extends Resource
class_name ItemInstance

@export var def: ItemDef
@export var item_seed: int = 0

# Rolled shot mode for ranged items. This is the ONLY place shot mode lives
# (mode is not represented by attributes anymore).
@export var ranged_mode: int = -1

# Rolled delivery mode for debuff spells. -1 = use def default (PROJECTILE).
@export var spell_delivery_mode: int = -1

@export var stat_levels: Dictionary = {}
@export var attributes: Array[ItemAttribute] = []


func rarity() -> int:
	return attributes.size()


func ensure_initialized() -> void:
	if def == null:
		return

	if stat_levels.is_empty():
		stat_levels["damage"] = 0
		stat_levels["cooldown_sec"] = 0
		stat_levels["windup_time"] = 0
		stat_levels["recovery_time"] = 0

		stat_levels["projectile_count"] = 0
		stat_levels["pierce"] = 0

		stat_levels["flat_damage_reduction"] = 0
		stat_levels["bonus_max_hp"] = 0
		stat_levels["heal_on_equip"] = 0

		stat_levels["active_time"] = 0
		stat_levels["knockback"] = 0
		stat_levels["hitbox_offset"] = 0
		stat_levels["hitbox_size"] = 0

		stat_levels["move_speed_mult"] = 0
		stat_levels["damage_taken_mult"] = 0

		# New runtime-editable ranged spread/origin stats
		stat_levels["spread_degrees"] = 0
		stat_levels["spread_pattern_degrees"] = 0
		stat_levels["muzzle_offset"] = 0


func add_attribute(attr: ItemAttribute) -> void:
	if attr == null:
		return
	attributes.append(attr)


func upgrade_stat(key: String, amount: int = 1) -> void:
	if amount <= 0:
		return

	var cur: int = 0
	if stat_levels.has(key):
		cur = int(stat_levels[key])
	stat_levels[key] = cur + amount


func get_upgrade_level(key: String) -> int:
	if not stat_levels.has(key):
		return 0
	return int(stat_levels[key])


func compute_stats(context: CombatContext) -> ItemStats:
	var out: ItemStats = ItemStats.new()
	if def == null:
		return out

	var base_res: Resource = _resolve_stats_resource(def)

	# Collect modifiers from attributes + instance upgrades.
	var mods: Array[StatModifier] = _collect_stat_modifiers(context)

	# Resolve each field deterministically using safe exported-property reads.
	out.damage = ModifierResolver.resolve_float(_stats_float(base_res, &"damage", 0.0), _mods_for(mods, StatId.DAMAGE))
	out.cooldown_sec = ModifierResolver.resolve_float(_stats_float(base_res, &"cooldown_sec", 0.0), _mods_for(mods, StatId.COOLDOWN_SEC))
	out.windup_time = ModifierResolver.resolve_float(_stats_float(base_res, &"windup_time", 0.0), _mods_for(mods, StatId.WINDUP_TIME))
	out.recovery_time = ModifierResolver.resolve_float(_stats_float(base_res, &"recovery_time", 0.0), _mods_for(mods, StatId.RECOVERY_TIME))

	out.projectile_count = ModifierResolver.resolve_int(_stats_int(base_res, &"projectile_count", 1), _mods_for(mods, StatId.PROJECTILE_COUNT))
	out.pierce = ModifierResolver.resolve_int(_stats_int(base_res, &"pierce", 0), _mods_for(mods, StatId.PIERCE))

	out.move_speed_mult = ModifierResolver.resolve_float(_stats_float(base_res, &"move_speed_mult", 1.0), _mods_for(mods, StatId.MOVE_SPEED_MULT))
	out.damage_taken_mult = ModifierResolver.resolve_float(_stats_float(base_res, &"damage_taken_mult", 1.0), _mods_for(mods, StatId.DAMAGE_TAKEN_MULT))
	out.flat_damage_reduction = ModifierResolver.resolve_float(_stats_float(base_res, &"flat_damage_reduction", 0.0), _mods_for(mods, StatId.FLAT_DAMAGE_REDUCTION))

	out.bonus_max_hp = ModifierResolver.resolve_float(_stats_float(base_res, &"bonus_max_hp", 0.0), _mods_for(mods, StatId.BONUS_MAX_HP))
	out.heal_on_equip = ModifierResolver.resolve_float(_stats_float(base_res, &"heal_on_equip", 0.0), _mods_for(mods, StatId.HEAL_ON_EQUIP))

	out.active_time = ModifierResolver.resolve_float(_stats_float(base_res, &"active_time", 0.0), _mods_for(mods, StatId.ACTIVE_TIME))
	out.knockback = ModifierResolver.resolve_float(_stats_float(base_res, &"knockback", 0.0), _mods_for(mods, StatId.KNOCKBACK))
	out.hitbox_offset = ModifierResolver.resolve_vec2(_stats_vec2(base_res, &"hitbox_offset", Vector2.ZERO), _mods_for(mods, StatId.HITBOX_OFFSET))
	out.hitbox_size = ModifierResolver.resolve_vec2(_stats_vec2(base_res, &"hitbox_size", Vector2.ZERO), _mods_for(mods, StatId.HITBOX_SIZE))

	# New runtime-editable spread/origin values
	out.spread_degrees = ModifierResolver.resolve_float(_stats_float(base_res, &"spread_degrees", 0.0), _mods_for(mods, StatId.SPREAD_DEGREES))
	out.spread_pattern_degrees = ModifierResolver.resolve_float(_stats_float(base_res, &"spread_pattern_degrees", 0.0), _mods_for(mods, StatId.SPREAD_PATTERN_DEGREES))
	out.muzzle_offset = ModifierResolver.resolve_vec2(_stats_vec2(base_res, &"muzzle_offset", Vector2.ZERO), _mods_for(mods, StatId.MUZZLE_OFFSET))

	# Safety clamps
	out.projectile_count = maxi(1, out.projectile_count)
	out.pierce = maxi(0, out.pierce)
	out.spread_degrees = maxf(0.0, out.spread_degrees)
	out.spread_pattern_degrees = maxf(0.0, out.spread_pattern_degrees)

	return out


func _resolve_stats_resource(d: ItemDef) -> Resource:
	if d == null:
		return null
	# Typed stats field (new per-type system) takes priority.
	var typed: Variant = d.get(&"stats")
	if typed is Resource:
		return typed as Resource
	# Fallback: legacy base_stats field (used by ranged/spell/shield until migrated).
	var base: Variant = d.get(&"base_stats")
	if base is Resource:
		return base as Resource
	return null


func _mods_for(all_mods: Array[StatModifier], stat: StringName) -> Array[StatModifier]:
	var out: Array[StatModifier] = []
	for m: StatModifier in all_mods:
		if m != null and m.stat == stat:
			out.append(m)
	return out


func _collect_stat_modifiers(context: CombatContext) -> Array[StatModifier]:
	var out: Array[StatModifier] = []

	var attrs: Array[ItemAttribute] = ItemAttributeBus._sorted_attrs(self)
	for a: ItemAttribute in attrs:
		if a == null:
			continue

		if a.has_method("applies_to_domain"):
			if not a.applies_to_domain(ItemAttributeBus.DOMAIN_STATS):
				continue
		else:
			continue

		if a.has_method("contribute_modifiers"):
			a.contribute_modifiers(context, self, ItemAttributeBus.DOMAIN_STATS, out)
			continue

		if a.has_method("get_stat_additive"):
			var add_res: Variant = a.get_stat_additive(context, self)
			if add_res is Resource:
				_legacy_itemstats_to_mods(add_res as Resource, a.id, out)

	_apply_instance_upgrade_modifiers(out)
	return out


func _legacy_itemstats_to_mods(add: Resource, source_id: StringName, out: Array[StatModifier]) -> void:
	if add == null:
		return

	# Additives
	var damage_val: float = _stats_float(add, &"damage", 0.0)
	if damage_val != 0.0:
		out.append(StatModifier.new(StatId.DAMAGE, StatModifier.Op.ADD, damage_val, 50, source_id))

	var cooldown_val: float = _stats_float(add, &"cooldown_sec", 0.0)
	if cooldown_val != 0.0:
		out.append(StatModifier.new(StatId.COOLDOWN_SEC, StatModifier.Op.ADD, cooldown_val, 50, source_id))

	var windup_val: float = _stats_float(add, &"windup_time", 0.0)
	if windup_val != 0.0:
		out.append(StatModifier.new(StatId.WINDUP_TIME, StatModifier.Op.ADD, windup_val, 50, source_id))

	var recovery_val: float = _stats_float(add, &"recovery_time", 0.0)
	if recovery_val != 0.0:
		out.append(StatModifier.new(StatId.RECOVERY_TIME, StatModifier.Op.ADD, recovery_val, 50, source_id))

	var projectile_count_val: int = _stats_int(add, &"projectile_count", 0)
	if projectile_count_val != 0:
		out.append(StatModifier.new(StatId.PROJECTILE_COUNT, StatModifier.Op.ADD, projectile_count_val, 50, source_id))

	var pierce_val: int = _stats_int(add, &"pierce", 0)
	if pierce_val != 0:
		out.append(StatModifier.new(StatId.PIERCE, StatModifier.Op.ADD, pierce_val, 50, source_id))

	var flat_reduction_val: float = _stats_float(add, &"flat_damage_reduction", 0.0)
	if flat_reduction_val != 0.0:
		out.append(StatModifier.new(StatId.FLAT_DAMAGE_REDUCTION, StatModifier.Op.ADD, flat_reduction_val, 50, source_id))

	var bonus_hp_val: float = _stats_float(add, &"bonus_max_hp", 0.0)
	if bonus_hp_val != 0.0:
		out.append(StatModifier.new(StatId.BONUS_MAX_HP, StatModifier.Op.ADD, bonus_hp_val, 50, source_id))

	var heal_on_equip_val: float = _stats_float(add, &"heal_on_equip", 0.0)
	if heal_on_equip_val != 0.0:
		out.append(StatModifier.new(StatId.HEAL_ON_EQUIP, StatModifier.Op.ADD, heal_on_equip_val, 50, source_id))

	var active_time_val: float = _stats_float(add, &"active_time", 0.0)
	if active_time_val != 0.0:
		out.append(StatModifier.new(StatId.ACTIVE_TIME, StatModifier.Op.ADD, active_time_val, 50, source_id))

	var knockback_val: float = _stats_float(add, &"knockback", 0.0)
	if knockback_val != 0.0:
		out.append(StatModifier.new(StatId.KNOCKBACK, StatModifier.Op.ADD, knockback_val, 50, source_id))

	var hitbox_offset_val: Vector2 = _stats_vec2(add, &"hitbox_offset", Vector2.ZERO)
	if hitbox_offset_val != Vector2.ZERO:
		out.append(StatModifier.new(StatId.HITBOX_OFFSET, StatModifier.Op.ADD, hitbox_offset_val, 50, source_id))

	var hitbox_size_val: Vector2 = _stats_vec2(add, &"hitbox_size", Vector2.ZERO)
	if hitbox_size_val != Vector2.ZERO:
		out.append(StatModifier.new(StatId.HITBOX_SIZE, StatModifier.Op.ADD, hitbox_size_val, 50, source_id))

	var spread_val: float = _stats_float(add, &"spread_degrees", 0.0)
	if spread_val != 0.0:
		out.append(StatModifier.new(StatId.SPREAD_DEGREES, StatModifier.Op.ADD, spread_val, 50, source_id))

	var spread_pattern_val: float = _stats_float(add, &"spread_pattern_degrees", 0.0)
	if spread_pattern_val != 0.0:
		out.append(StatModifier.new(StatId.SPREAD_PATTERN_DEGREES, StatModifier.Op.ADD, spread_pattern_val, 50, source_id))

	var muzzle_offset_val: Vector2 = _stats_vec2(add, &"muzzle_offset", Vector2.ZERO)
	if muzzle_offset_val != Vector2.ZERO:
		out.append(StatModifier.new(StatId.MUZZLE_OFFSET, StatModifier.Op.ADD, muzzle_offset_val, 50, source_id))

	# Multipliers
	var move_speed_mult_val: float = _stats_float(add, &"move_speed_mult", 1.0)
	if move_speed_mult_val != 1.0:
		out.append(StatModifier.new(StatId.MOVE_SPEED_MULT, StatModifier.Op.MUL, move_speed_mult_val - 1.0, 60, source_id))

	var damage_taken_mult_val: float = _stats_float(add, &"damage_taken_mult", 1.0)
	if damage_taken_mult_val != 1.0:
		out.append(StatModifier.new(StatId.DAMAGE_TAKEN_MULT, StatModifier.Op.MUL, damage_taken_mult_val - 1.0, 60, source_id))


func _apply_instance_upgrade_modifiers(out: Array[StatModifier]) -> void:
	var src: StringName = &"__upgrade"

	var dmg_lvl: int = get_upgrade_level(String(StatId.DAMAGE))
	if dmg_lvl > 0:
		out.append(StatModifier.new(StatId.DAMAGE, StatModifier.Op.ADD, float(dmg_lvl) * 0.5, 10, src))

	var cd_lvl: int = get_upgrade_level(String(StatId.COOLDOWN_SEC))
	if cd_lvl > 0:
		out.append(StatModifier.new(StatId.COOLDOWN_SEC, StatModifier.Op.ADD, float(cd_lvl) * -0.05, 10, src))

	var wind_lvl: int = get_upgrade_level(String(StatId.WINDUP_TIME))
	if wind_lvl > 0:
		out.append(StatModifier.new(StatId.WINDUP_TIME, StatModifier.Op.ADD, float(wind_lvl) * -0.01, 10, src))

	var rec_lvl: int = get_upgrade_level(String(StatId.RECOVERY_TIME))
	if rec_lvl > 0:
		out.append(StatModifier.new(StatId.RECOVERY_TIME, StatModifier.Op.ADD, float(rec_lvl) * -0.01, 10, src))

	var proj_lvl: int = get_upgrade_level(String(StatId.PROJECTILE_COUNT))
	if proj_lvl > 0:
		out.append(StatModifier.new(StatId.PROJECTILE_COUNT, StatModifier.Op.ADD, proj_lvl, 10, src))

	var pierce_lvl: int = get_upgrade_level(String(StatId.PIERCE))
	if pierce_lvl > 0:
		out.append(StatModifier.new(StatId.PIERCE, StatModifier.Op.ADD, pierce_lvl, 10, src))

	var spread_lvl: int = get_upgrade_level(String(StatId.SPREAD_DEGREES))
	if spread_lvl > 0:
		out.append(StatModifier.new(StatId.SPREAD_DEGREES, StatModifier.Op.ADD, float(spread_lvl) * 0.5, 10, src))

	var spread_pattern_lvl: int = get_upgrade_level(String(StatId.SPREAD_PATTERN_DEGREES))
	if spread_pattern_lvl > 0:
		out.append(StatModifier.new(StatId.SPREAD_PATTERN_DEGREES, StatModifier.Op.ADD, float(spread_pattern_lvl) * 1.0, 10, src))


func _stats_has(res: Resource, prop: StringName) -> bool:
	if res == null:
		return false
	for p in res.get_property_list():
		if StringName(p.name) == prop:
			return true
	return false


func _stats_float(res: Resource, prop: StringName, fallback: float) -> float:
	if res == null:
		return fallback
	if not _stats_has(res, prop):
		return fallback
	return float(res.get(prop))


func _stats_int(res: Resource, prop: StringName, fallback: int) -> int:
	if res == null:
		return fallback
	if not _stats_has(res, prop):
		return fallback
	return int(res.get(prop))


func _stats_vec2(res: Resource, prop: StringName, fallback: Vector2) -> Vector2:
	if res == null:
		return fallback
	if not _stats_has(res, prop):
		return fallback
	var value: Variant = res.get(prop)
	if value is Vector2:
		return value
	return fallback

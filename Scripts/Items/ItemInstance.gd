extends Resource
class_name ItemInstance

@export var def: ItemDef
@export var seed: int = 0

# Rolled shot mode for ranged items. This is the ONLY place shot mode lives
# (mode is not represented by attributes anymore).
@export var ranged_mode: int = -1

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

	# Template base stats
	# IMPORTANT: In tool mode, def can be a placeholder Resource.
	# Placeholders expose exported properties but DO NOT have script methods,
	# so do not call def.get_base_stats_safe(). Read exported property directly.
	var base_stats: ItemStats = def.base_stats if def.base_stats != null else ItemStats.new()
	var base: ItemStats
	if base_stats != null:
		var dup: Resource = base_stats.duplicate(true) # built-in, placeholder-safe
		if dup is ItemStats:
			base = dup as ItemStats
		else:
			base = ItemStats.new()
	else:
		base = ItemStats.new()

	# Collect modifiers from attributes + instance upgrades.
	var mods: Array[StatModifier] = _collect_stat_modifiers(context)

	# Resolve each field deterministically.
	out.damage = ModifierResolver.resolve_float(base.damage, _mods_for(mods, StatId.DAMAGE))
	out.cooldown_sec = ModifierResolver.resolve_float(base.cooldown_sec, _mods_for(mods, StatId.COOLDOWN_SEC))
	out.windup_time = ModifierResolver.resolve_float(base.windup_time, _mods_for(mods, StatId.WINDUP_TIME))
	out.recovery_time = ModifierResolver.resolve_float(base.recovery_time, _mods_for(mods, StatId.RECOVERY_TIME))

	out.projectile_count = ModifierResolver.resolve_int(base.projectile_count, _mods_for(mods, StatId.PROJECTILE_COUNT))
	out.pierce = ModifierResolver.resolve_int(base.pierce, _mods_for(mods, StatId.PIERCE))

	out.move_speed_mult = ModifierResolver.resolve_float(base.move_speed_mult, _mods_for(mods, StatId.MOVE_SPEED_MULT))
	out.damage_taken_mult = ModifierResolver.resolve_float(base.damage_taken_mult, _mods_for(mods, StatId.DAMAGE_TAKEN_MULT))
	out.flat_damage_reduction = ModifierResolver.resolve_float(base.flat_damage_reduction, _mods_for(mods, StatId.FLAT_DAMAGE_REDUCTION))

	out.bonus_max_hp = ModifierResolver.resolve_float(base.bonus_max_hp, _mods_for(mods, StatId.BONUS_MAX_HP))
	out.heal_on_equip = ModifierResolver.resolve_float(base.heal_on_equip, _mods_for(mods, StatId.HEAL_ON_EQUIP))

	out.active_time = ModifierResolver.resolve_float(base.active_time, _mods_for(mods, StatId.ACTIVE_TIME))
	out.knockback = ModifierResolver.resolve_float(base.knockback, _mods_for(mods, StatId.KNOCKBACK))
	out.hitbox_offset = ModifierResolver.resolve_vec2(base.hitbox_offset, _mods_for(mods, StatId.HITBOX_OFFSET))
	out.hitbox_size = ModifierResolver.resolve_vec2(base.hitbox_size, _mods_for(mods, StatId.HITBOX_SIZE))

	# Safety clamps
	out.projectile_count = maxi(1, out.projectile_count)
	out.pierce = maxi(0, out.pierce)

	return out


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

		# Placeholder-safe: placeholders have no script methods.
		# In tool mode, skip them instead of crashing.
		if a.resource_path == "":
			continue

		if a.has_method("applies_to_domain"):
			if not a.applies_to_domain(ItemAttributeBus.DOMAIN_STATS):
				continue
		# If no method, treat as not applicable
		else:
			continue

		# Preferred pipeline
		if a.has_method("contribute_modifiers"):
			a.contribute_modifiers(context, self, ItemAttributeBus.DOMAIN_STATS, out)
			continue

		# Legacy fallback
		if a.has_method("get_stat_additive"):
			var add: ItemStats = a.get_stat_additive(context, self)
			if add != null:
				_legacy_itemstats_to_mods(add, a.id, out)

	_apply_instance_upgrade_modifiers(out)
	return out


func _legacy_itemstats_to_mods(add: ItemStats, source_id: StringName, out: Array[StatModifier]) -> void:
	# Additives
	if add.damage != 0.0:
		out.append(StatModifier.new(StatId.DAMAGE, StatModifier.Op.ADD, add.damage, 50, source_id))
	if add.cooldown_sec != 0.0:
		out.append(StatModifier.new(StatId.COOLDOWN_SEC, StatModifier.Op.ADD, add.cooldown_sec, 50, source_id))
	if add.windup_time != 0.0:
		out.append(StatModifier.new(StatId.WINDUP_TIME, StatModifier.Op.ADD, add.windup_time, 50, source_id))
	if add.recovery_time != 0.0:
		out.append(StatModifier.new(StatId.RECOVERY_TIME, StatModifier.Op.ADD, add.recovery_time, 50, source_id))

	if add.projectile_count != 0:
		out.append(StatModifier.new(StatId.PROJECTILE_COUNT, StatModifier.Op.ADD, add.projectile_count, 50, source_id))
	if add.pierce != 0:
		out.append(StatModifier.new(StatId.PIERCE, StatModifier.Op.ADD, add.pierce, 50, source_id))

	if add.flat_damage_reduction != 0.0:
		out.append(StatModifier.new(StatId.FLAT_DAMAGE_REDUCTION, StatModifier.Op.ADD, add.flat_damage_reduction, 50, source_id))
	if add.bonus_max_hp != 0.0:
		out.append(StatModifier.new(StatId.BONUS_MAX_HP, StatModifier.Op.ADD, add.bonus_max_hp, 50, source_id))
	if add.heal_on_equip != 0.0:
		out.append(StatModifier.new(StatId.HEAL_ON_EQUIP, StatModifier.Op.ADD, add.heal_on_equip, 50, source_id))

	if add.active_time != 0.0:
		out.append(StatModifier.new(StatId.ACTIVE_TIME, StatModifier.Op.ADD, add.active_time, 50, source_id))
	if add.knockback != 0.0:
		out.append(StatModifier.new(StatId.KNOCKBACK, StatModifier.Op.ADD, add.knockback, 50, source_id))
	if add.hitbox_offset != Vector2.ZERO:
		out.append(StatModifier.new(StatId.HITBOX_OFFSET, StatModifier.Op.ADD, add.hitbox_offset, 50, source_id))
	if add.hitbox_size != Vector2.ZERO:
		out.append(StatModifier.new(StatId.HITBOX_SIZE, StatModifier.Op.ADD, add.hitbox_size, 50, source_id))

	# Multipliers (legacy ItemStats stores them as absolute multipliers)
	if add.move_speed_mult != 1.0:
		out.append(StatModifier.new(StatId.MOVE_SPEED_MULT, StatModifier.Op.MUL, add.move_speed_mult - 1.0, 60, source_id))
	if add.damage_taken_mult != 1.0:
		out.append(StatModifier.new(StatId.DAMAGE_TAKEN_MULT, StatModifier.Op.MUL, add.damage_taken_mult - 1.0, 60, source_id))


func _apply_instance_upgrade_modifiers(out: Array[StatModifier]) -> void:
	# Keep the exact same upgrade behavior as before, but expressed as modifiers.
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

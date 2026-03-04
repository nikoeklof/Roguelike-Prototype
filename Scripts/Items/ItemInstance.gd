extends Resource
class_name ItemInstance

@export var def: ItemDef
@export var seed: int = 0

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
	out = def.get_base_stats_safe().duplicate_typed()

	# Attribute additive stats
	for a: ItemAttribute in attributes:
		if a == null:
			continue
		var add: ItemStats = a.get_stat_additive(context, self)
		if add != null:
			out.apply_additive(add)

	# Per-instance upgrade scaling (simple default rules)
	_apply_instance_upgrades(out)

	# Safety clamps
	out.projectile_count = maxi(1, out.projectile_count)
	out.pierce = maxi(0, out.pierce)

	return out


func _apply_instance_upgrades(out: ItemStats) -> void:
	if out == null:
		return

	var dmg_lvl: int = get_upgrade_level("damage")
	if dmg_lvl > 0:
		out.damage += float(dmg_lvl) * 0.5

	var cd_lvl: int = get_upgrade_level("cooldown_sec")
	if cd_lvl > 0:
		out.cooldown_sec += float(cd_lvl) * -0.05

	var wind_lvl: int = get_upgrade_level("windup_time")
	if wind_lvl > 0:
		out.windup_time += float(wind_lvl) * -0.01

	var rec_lvl: int = get_upgrade_level("recovery_time")
	if rec_lvl > 0:
		out.recovery_time += float(rec_lvl) * -0.01

	var proj_lvl: int = get_upgrade_level("projectile_count")
	if proj_lvl > 0:
		out.projectile_count += proj_lvl

	var pierce_lvl: int = get_upgrade_level("pierce")
	if pierce_lvl > 0:
		out.pierce += pierce_lvl

	var k_lvl: int = get_upgrade_level("knockback")
	if k_lvl > 0:
		out.knockback += float(k_lvl) * 0.2

	# Vector2 fields
	var size_lvl: int = get_upgrade_level("hitbox_size")
	if size_lvl > 0:
		var delta: float = float(size_lvl) * 0.05
		out.hitbox_size += Vector2(delta, delta)

	var offset_lvl: int = get_upgrade_level("hitbox_offset")
	if offset_lvl > 0:
		var delta_off: float = float(offset_lvl) * 0.05
		out.hitbox_offset += Vector2(delta_off, delta_off)

	var flatdr_lvl: int = get_upgrade_level("flat_damage_reduction")
	if flatdr_lvl > 0:
		out.flat_damage_reduction += float(flatdr_lvl) * 0.5

	var hp_lvl: int = get_upgrade_level("bonus_max_hp")
	if hp_lvl > 0:
		out.bonus_max_hp += float(hp_lvl) * 1.0

	var heal_lvl: int = get_upgrade_level("heal_on_equip")
	if heal_lvl > 0:
		out.heal_on_equip += float(heal_lvl) * 1.0

	var active_lvl: int = get_upgrade_level("active_time")
	if active_lvl > 0:
		out.active_time += float(active_lvl) * 0.1

	var ms_lvl: int = get_upgrade_level("move_speed_mult")
	if ms_lvl > 0:
		out.move_speed_mult *= pow(1.05, float(ms_lvl))

	var dt_lvl: int = get_upgrade_level("damage_taken_mult")
	if dt_lvl > 0:
		out.damage_taken_mult *= pow(0.98, float(dt_lvl))

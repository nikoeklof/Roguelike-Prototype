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


func get_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed) & 0x7fffffff
	return rng


func roll_attributes(target_count: int) -> void:
	if def == null:
		return
	var pool := def.allowed_attributes
	if pool.is_empty():
		return

	var rng := get_rng()

	var indices: Array[int] = []
	indices.resize(pool.size())
	for i in range(pool.size()):
		indices[i] = i

	for i in range(indices.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := indices[i]
		indices[i] = indices[j]
		indices[j] = tmp

	attributes.clear()
	var count := mini(target_count, pool.size())
	for k in range(count):
		var attr_template := pool[indices[k]]
		if attr_template == null:
			continue
		var inst := attr_template.duplicate(true) as ItemAttribute
		if inst != null:
			attributes.append(inst)


func add_attribute(attr: ItemAttribute) -> void:
	if attr == null:
		return
	attributes.append(attr)


func upgrade_stat(key: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	var cur := 0
	if stat_levels.has(key):
		cur = int(stat_levels[key])
	stat_levels[key] = cur + amount


func get_upgrade_level(key: String) -> int:
	if not stat_levels.has(key):
		return 0
	return int(stat_levels[key])


func compute_stats(context: CombatContext) -> ItemStats:
	var out := ItemStats.new()
	if def == null:
		return out

	out = def.get_base_stats_safe().duplicate_typed()

	var step := def.get_upgrade_step_safe()
	_apply_upgrade_step(out, step)

	for a in attributes:
		if a == null:
			continue
		var add := a.get_stat_additive(context, self)
		if add != null:
			out.apply_additive(add)

	# Safety
	out.projectile_count = maxi(1, out.projectile_count)
	out.pierce = maxi(0, out.pierce)

	return out


func _apply_upgrade_step(out: ItemStats, step: ItemStats) -> void:
	if out == null or step == null:
		return

	out.damage += step.damage * float(get_upgrade_level("damage"))
	out.cooldown_sec += step.cooldown_sec * float(get_upgrade_level("cooldown_sec"))
	out.windup_time += step.windup_time * float(get_upgrade_level("windup_time"))
	out.recovery_time += step.recovery_time * float(get_upgrade_level("recovery_time"))

	out.projectile_count += int(round(float(step.projectile_count) * float(get_upgrade_level("projectile_count"))))
	out.pierce += int(round(float(step.pierce) * float(get_upgrade_level("pierce"))))

	out.flat_damage_reduction += step.flat_damage_reduction * float(get_upgrade_level("flat_damage_reduction"))
	out.bonus_max_hp += step.bonus_max_hp * float(get_upgrade_level("bonus_max_hp"))
	out.heal_on_equip += step.heal_on_equip * float(get_upgrade_level("heal_on_equip"))

	out.active_time += step.active_time * float(get_upgrade_level("active_time"))
	out.knockback += step.knockback * float(get_upgrade_level("knockback"))
	out.hitbox_offset += step.hitbox_offset * float(get_upgrade_level("hitbox_offset"))
	out.hitbox_size += step.hitbox_size * float(get_upgrade_level("hitbox_size"))

	var ms_lvl := get_upgrade_level("move_speed_mult")
	if ms_lvl > 0 and not is_equal_approx(step.move_speed_mult, 1.0):
		out.move_speed_mult *= pow(step.move_speed_mult, float(ms_lvl))

	var dt_lvl := get_upgrade_level("damage_taken_mult")
	if dt_lvl > 0 and not is_equal_approx(step.damage_taken_mult, 1.0):
		out.damage_taken_mult *= pow(step.damage_taken_mult, float(dt_lvl))

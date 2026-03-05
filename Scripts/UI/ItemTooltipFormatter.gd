extends RefCounted
class_name ItemTooltipFormatter

# ------------------------------------------------------------
# Universal resolver: works for Weapon/Spell/Shield/ItemNode
# ------------------------------------------------------------
static func get_item_instance(item: Node) -> ItemInstance:
	if item == null:
		return null

	# Equipment items (Weapon/Spell/Shield) should expose this
	if item.has_method(&"get_item_instance"):
		var res: Variant = item.call(&"get_item_instance")
		if res is ItemInstance:
			return res as ItemInstance

	# Legacy ItemNode support
	if item.has_method(&"get_item"):
		var res2: Variant = item.call(&"get_item")
		if res2 is ItemInstance:
			return res2 as ItemInstance

	return null


static func get_item_def(item: Node) -> ItemDef:
	var inst: ItemInstance = get_item_instance(item)
	if inst != null:
		return inst.def
	return null


static func get_item_name(item: Node) -> String:
	var def: ItemDef = get_item_def(item)
	if def != null:
		if def.display_name != "":
			return def.display_name
		if def.id != &"":
			return str(def.id)
	if item != null:
		return str(item.name)
	return "Item"


static func format_attributes(inst: ItemInstance) -> String:
	if inst == null or inst.attributes == null or inst.attributes.is_empty():
		return "None"

	var names: Array[String] = []
	for a in inst.attributes:
		var attr: ItemAttribute = a as ItemAttribute
		if attr == null:
			continue

		var n := ""
		# placeholder-safe: prefer exported property
		if "display_name" in attr:
			n = str(attr.display_name)
		if n == "":
			n = str(attr.id)
		if n == "":
			n = "Attribute"

		names.append(n)

	if names.is_empty():
		return "None"

	return ", ".join(names)


# ------------------------------------------------------------
# SAME UX as before: compact always visible, expanded in range
# ------------------------------------------------------------
static func format_compact(item: Node) -> String:
	var def: ItemDef = get_item_def(item)
	var inst: ItemInstance = get_item_instance(item)

	var label: String = get_item_name(item)

	if inst != null:
		label += " (⭐%d)" % int(inst.rarity())
		label += "\nAttrs: %s" % format_attributes(inst)

	if def != null:
		label += "\nType: %s" % _category_name(int(def.category))

	return label


static func format_expanded(item: Node) -> String:
	var def: ItemDef = get_item_def(item)
	var inst: ItemInstance = get_item_instance(item)

	var out := ""
	out += get_item_name(item)

	if def != null:
		out += "  [%s]" % _category_name(int(def.category))

	if inst != null:
		out += "  (⭐%d)" % int(inst.rarity())

	out += "\n"
	# Ranged Mode (debug/info)
	if inst != null and def != null and def.category == ItemDef.Category.RANGED:
		# inst.ranged_mode is stored on ItemInstance in your refactor
		if "ranged_mode" in inst:
			var rm: int = int(inst.get("ranged_mode"))
			if rm >= 0:
				out += "Mode: %s\n" % _ranged_mode_name(rm)
	# --- Stats: compute via ItemInstance.compute_stats(context) ---
	if inst != null:
		var stats := _compute_stats_for_tooltip(item, inst)
		out += _format_stats_block(stats)
	elif def != null:
		# fallback: base stats only (placeholder-safe)
		var base_stats: ItemStats = def.base_stats if def.base_stats != null else ItemStats.new()
		out += _format_stats_block(base_stats)

	if inst != null:
		out += "\nAttrs: %s" % format_attributes(inst)

	out += "\n[Press E to swap]"
	return out


# ------------------------------------------------------------
# Tooltip stats computation
# ------------------------------------------------------------
static func _compute_stats_for_tooltip(item_node: Node, inst: ItemInstance) -> ItemStats:
	if inst == null:
		return ItemStats.new()

	# If compute_stats exists, use it (this is your current architecture)
	if inst.has_method(&"compute_stats"):
		var ctx := CombatContext.new()
		ctx.item = item_node
		ctx.item_instance = inst
		# owner can be null; most stat attributes don't need it
		var res: Variant = inst.call(&"compute_stats", ctx)
		if res is ItemStats:
			return res as ItemStats

	# Fallback: base stats
	if inst.def != null and inst.def.base_stats != null:
		return inst.def.base_stats
	return ItemStats.new()


static func _format_stats_block(stats: ItemStats) -> String:
	if stats == null:
		return "Stats: (none)\n"

	var lines: Array[String] = []

	# floats
	if not is_zero_approx(stats.damage):
		lines.append("Damage: %s" % _fmt_float(stats.damage))
	if not is_zero_approx(stats.cooldown_sec):
		lines.append("Cooldown: %ss" % _fmt_float(stats.cooldown_sec))
	if not is_zero_approx(stats.windup_time):
		lines.append("Windup: %ss" % _fmt_float(stats.windup_time))
	if not is_zero_approx(stats.recovery_time):
		lines.append("Recovery: %ss" % _fmt_float(stats.recovery_time))

	# ints
	if int(stats.projectile_count) != 0:
		lines.append("Projectiles: %d" % int(stats.projectile_count))
	if int(stats.pierce) != 0:
		lines.append("Pierce: %d" % int(stats.pierce))

	# misc
	if not is_zero_approx(stats.knockback):
		lines.append("Knockback: %s" % _fmt_float(stats.knockback))

	if not is_zero_approx(stats.flat_damage_reduction):
		lines.append("Flat DR: %s" % _fmt_float(stats.flat_damage_reduction))

	if not is_zero_approx(stats.bonus_max_hp):
		lines.append("Bonus HP: %s" % _fmt_float(stats.bonus_max_hp))

	if not is_zero_approx(stats.heal_on_equip):
		lines.append("Heal on Equip: %s" % _fmt_float(stats.heal_on_equip))

	# multipliers (only show if not default)
	if not is_equal_approx(stats.move_speed_mult, 1.0):
		lines.append("Move Speed: x%s" % _fmt_float(stats.move_speed_mult))
	if not is_equal_approx(stats.damage_taken_mult, 1.0):
		lines.append("Damage Taken: x%s" % _fmt_float(stats.damage_taken_mult))

	if lines.is_empty():
		return "Stats: (base)\n"

	return "Stats:\n- " + "\n- ".join(lines) + "\n"


static func _fmt_float(v: float) -> String:
	return ("%0.2f" % v).rstrip("0").rstrip(".")


static func _ranged_mode_name(mode: int) -> String:
	match mode:
		0:
			return "Projectile"
		1:
			return "Hitscan"
		2:
			return "Beam"
		_:
			return "Unknown"

static func _category_name(cat: int) -> String:
	match cat:
		ItemDef.Category.MELEE:
			return "Melee"
		ItemDef.Category.RANGED:
			return "Ranged"
		ItemDef.Category.SPELL:
			return "Spell"
		ItemDef.Category.SHIELD:
			return "Shield"
		_:
			return "Item"

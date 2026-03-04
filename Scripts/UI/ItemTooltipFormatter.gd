extends RefCounted
class_name ItemTooltipFormatter


static func get_item_def_from_node(item_node: Node) -> ItemDef:
	if item_node == null:
		return null
	if item_node is ItemNode:
		var it: ItemNode = item_node as ItemNode
		var inst: ItemInstance = it.get_item_instance()
		if inst != null:
			return inst.def
	return null


static func get_item_instance_from_node(item_node: Node) -> ItemInstance:
	if item_node == null:
		return null
	if item_node is ItemNode:
		return (item_node as ItemNode).get_item_instance()
	return null


static func get_item_name_from_node(item_node: Node) -> String:
	var def: ItemDef = get_item_def_from_node(item_node)
	if def != null:
		if def.display_name != "":
			return def.display_name
		if def.id != &"":
			return str(def.id)
	if item_node != null:
		return str(item_node.name)
	return "Item"


static func format_attributes(inst: ItemInstance) -> String:
	if inst == null or inst.attributes.is_empty():
		return "None"

	var names: Array[String] = []
	for a: ItemAttribute in inst.attributes:
		if a == null:
			continue
		var n: String = String(a.display_name)
		if n == "":
			n = str(a.id)
		if n == "":
			n = "Attribute"
		names.append(n)

	if names.is_empty():
		return "None"

	return ", ".join(names)


static func format_compact(item_node: Node) -> String:
	# Always-visible tooltip when not in pickup radius:
	# Name + rarity + attributes + category
	var def: ItemDef = get_item_def_from_node(item_node)
	var inst: ItemInstance = get_item_instance_from_node(item_node)

	var label: String = get_item_name_from_node(item_node)

	if inst != null:
		label += " (⭐%d)" % inst.rarity()
		label += "\nAttrs: %s" % format_attributes(inst)

	if def != null:
		label += "\nType: %s" % _category_name(def.category)

	return label


static func format_expanded(item_node: Node) -> String:
	# Expanded tooltip when in pickup radius:
	# Name + type + rarity + stats + attributes
	var def: ItemDef = get_item_def_from_node(item_node)
	var inst: ItemInstance = get_item_instance_from_node(item_node)

	var out: String = ""
	out += get_item_name_from_node(item_node)

	if def != null:
		out += "  [%s]" % _category_name(def.category)

	if inst != null:
		out += "  (⭐%d)" % inst.rarity()

	out += "\n"

	# Stats block: we *can* compute without CombatContext, but your compute_stats currently expects it.
	# So we show base stats safely; if you later want context-aware numbers, pass context in.
	if def != null:
		var base: ItemStats = def.get_base_stats_safe()
		out += _format_stats_block(base)

	if inst != null:
		out += "\nAttrs: %s" % format_attributes(inst)

	out += "\n[Press E to swap]"
	return out


static func _format_stats_block(stats: ItemStats) -> String:
	if stats == null:
		return "Stats: (none)\n"

	var lines: Array[String] = []
	# Keep this conservative: only show fields that are meaningful in your ItemStats.
	# If you add/remove fields later, this won't break compilation.
	if not is_zero_approx(stats.damage):
		lines.append("Damage: %s" % _fmt_float(stats.damage))
	if not is_zero_approx(stats.cooldown_sec):
		lines.append("Cooldown: %ss" % _fmt_float(stats.cooldown_sec))
	if not is_zero_approx(stats.windup_time):
		lines.append("Windup: %ss" % _fmt_float(stats.windup_time))
	if not is_zero_approx(stats.recovery_time):
		lines.append("Recovery: %ss" % _fmt_float(stats.recovery_time))

	# Int-like stats
	if int(stats.projectile_count) != 0:
		lines.append("Projectiles: %d" % int(stats.projectile_count))
	if int(stats.pierce) != 0:
		lines.append("Pierce: %d" % int(stats.pierce))

	if not is_zero_approx(stats.knockback):
		lines.append("Knockback: %s" % _fmt_float(stats.knockback))

	if lines.is_empty():
		return "Stats: (base)\n"

	return "Stats:\n- " + "\n- ".join(lines) + "\n"


static func _fmt_float(v: float) -> String:
	# Small, stable formatting (no Variant inference).
	return ("%0.2f" % v).rstrip("0").rstrip(".")


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

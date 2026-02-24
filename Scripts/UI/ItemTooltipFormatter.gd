extends RefCounted
class_name ItemTooltipFormatter

static func category_name_from_item_def(def: ItemDef) -> String:
	if def == null:
		return "Item"
	match def.category:
		ItemDef.Category.MELEE: return "Melee"
		ItemDef.Category.RANGED: return "Ranged"
		ItemDef.Category.SPELL: return "Spell"
		ItemDef.Category.SHIELD: return "Shield"
		_: return "Item"


static func get_item_def_from_node(item_node: Node) -> ItemDef:
	if item_node == null:
		return null
	if "item_def" in item_node:
		var v: Variant = item_node.get("item_def")
		if v is ItemDef:
			return v as ItemDef
	if item_node.has_method(&"get_item_def"):
		var v2: Variant = item_node.call(&"get_item_def")
		if v2 is ItemDef:
			return v2 as ItemDef
	return null


static func get_item_instance_from_node(item_node: Node) -> ItemInstance:
	if item_node == null:
		return null
	if item_node.has_method(&"get_item_instance"):
		var v: Variant = item_node.call(&"get_item_instance")
		if v is ItemInstance:
			return v as ItemInstance
	return null


static func get_item_display_name(item_node: Node) -> String:
	if item_node == null:
		return "Unknown"
	var def := get_item_def_from_node(item_node)
	if def != null and def.display_name != "":
		return def.display_name
	if "name" in item_node and str(item_node.name) != "":
		return str(item_node.name)
	return "Item"


static func format_attributes(inst: ItemInstance) -> String:
	if inst == null or inst.attributes.is_empty():
		return "None"

	var names: Array[String] = []
	for a in inst.attributes:
		if a == null:
			continue
		var n := a.display_name
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
	# Type + rarity + attributes
	var def := get_item_def_from_node(item_node)
	var inst := get_item_instance_from_node(item_node)

	var type_name := category_name_from_item_def(def)
	var rar := 0
	if inst != null:
		rar = inst.rarity()

	var attrs := format_attributes(inst)

	var title := "%s (Rarity %d)" % [type_name, rar]
	return "[b]%s[/b]\n%s" % [title, attrs]


static func format_expanded(item_node: Node) -> String:
	# In pickup radius: type + rarity + attributes + base stats (computed)
	var def := get_item_def_from_node(item_node)
	var inst := get_item_instance_from_node(item_node)

	var type_name := category_name_from_item_def(def)
	var rar := 0
	if inst != null:
		rar = inst.rarity()

	var name := get_item_display_name(item_node)
	var attrs := format_attributes(inst)

	var out := "[b]%s[/b]\n%s (Rarity %d)\n\n[b]Attributes[/b]\n%s\n" % [
		name, type_name, rar, attrs
	]

	if inst == null:
		out += "\n[i]No ItemInstance found.[/i]"
		return out

	# Compute stats without an owner (pure numbers for UI/debug)
	var ctx := CombatContext.new()
	ctx.owner = null
	ctx.aim_dir = Vector2.RIGHT
	ctx.item = item_node
	ctx.item_instance = inst

	var s := inst.compute_stats(ctx)

	out += "\n[b]Stats[/b]\n"
	out += _format_stats_for_category(def, s)
	return out


static func _format_stats_for_category(def: ItemDef, s: ItemStats) -> String:
	if s == null:
		return "None"

	var lines: Array[String] = []

	var cat := ItemDef.Category.MELEE
	if def != null:
		cat = def.category

	match cat:
		ItemDef.Category.MELEE:
			lines.append("Damage: %s" % _f(s.damage))
			lines.append("Cooldown: %ss (%s atk/s)" % [_f(s.cooldown_sec), _attack_speed(s.cooldown_sec)])
			if s.windup_time > 0.0: lines.append("Windup: %ss" % _f(s.windup_time))
			if s.recovery_time > 0.0: lines.append("Recovery: %ss" % _f(s.recovery_time))
			if s.active_time > 0.0: lines.append("Active: %ss" % _f(s.active_time))
			if s.knockback > 0.0: lines.append("Knockback: %s" % _f(s.knockback))

		ItemDef.Category.RANGED:
			lines.append("Damage: %s" % _f(s.damage))
			lines.append("Cooldown: %ss (%s shots/s)" % [_f(s.cooldown_sec), _attack_speed(s.cooldown_sec)])
			if s.windup_time > 0.0: lines.append("Windup: %ss" % _f(s.windup_time))

		ItemDef.Category.SPELL:
			lines.append("Power: %s" % _f(s.damage))
			lines.append("Cooldown: %ss" % _f(s.cooldown_sec))
			if s.windup_time > 0.0: lines.append("Cast Time: %ss" % _f(s.windup_time))

		ItemDef.Category.SHIELD:
			if s.bonus_max_hp != 0.0: lines.append("Max HP: %+s" % _f(s.bonus_max_hp))
			if s.heal_on_equip != 0.0: lines.append("Heal on Equip: %+s" % _f(s.heal_on_equip))
			if not is_equal_approx(s.move_speed_mult, 1.0): lines.append("Move Speed: x%s" % _f(s.move_speed_mult))
			if not is_equal_approx(s.damage_taken_mult, 1.0): lines.append("Damage Taken: x%s" % _f(s.damage_taken_mult))
			if s.flat_damage_reduction != 0.0: lines.append("Flat DR: %+s" % _f(s.flat_damage_reduction))

		_:
			lines.append("Damage: %s" % _f(s.damage))
			lines.append("Cooldown: %ss" % _f(s.cooldown_sec))

	if lines.is_empty():
		return "None"

	return "\n".join(lines)


static func _attack_speed(cooldown_sec: float) -> String:
	var cd := maxf(0.001, cooldown_sec)
	var aps := 1.0 / cd
	return _f(aps)


static func _f(v: float) -> String:
	# Nice compact float for UI
	return String.num(v, 2).rstrip("0").rstrip(".")

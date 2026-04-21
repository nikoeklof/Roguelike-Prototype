extends DebugHUDSection
class_name ShieldSection


func section_name() -> String:
	return "SHIELD"


func build_text(ctx: DebugHUDContext) -> String:
	var equipment: Equipment = ctx.player_equipment
	if equipment == null:
		return "(No equipment)"

	var shield_slot: ShieldSlot = equipment.get_node_or_null("ShieldSlot") as ShieldSlot
	if shield_slot == null:
		return "(No shield slot)"

	var shield: Shield = shield_slot.get_item() as Shield
	if shield == null:
		return "(No shield equipped)"

	var shield_instance: ItemInstance = shield.get_item_instance()
	if shield_instance == null or shield_instance.def == null:
		return "(No instance)"

	var shield_def: ShieldItemDef = shield_instance.def as ShieldItemDef
	if shield_def == null:
		return "(Invalid def)"

	var t: String = ""

	# Shield name and type
	t += "Name: %s (%s)" % [
		shield_def.display_name,
		ShieldItemDef.ShieldType.keys()[shield_def.shield_type]
	]

	# Shield modifiers
	t += "\nBlock Reduction: %.1f%%" % (shield_def.block_damage_reduction * 100.0)
	t += "\nMove Speed Mult: %.2f" % shield_def.movement_speed_mult_while_blocking
	t += "\nBlock Damage Reduction: %.1f" % shield_def.block_damage_reduction
	t += "\nPassive Damage Reduction: %.1f" % shield_def.passive_damage_reduction_mult

	# Attributes with ability info
	if not shield_instance.attributes.is_empty():
		t += "\nAttributes (%d):" % shield_instance.attributes.size()
		for attr: ItemAttribute in shield_instance.attributes:
			if attr == null:
				continue
			t += "\n  • %s" % attr.display_name

			if ctx.player_passive_shield != null and attr is PhasingAttribute:
				var cooldown: float = ctx.player_passive_shield.get_ability_cooldown_remaining(attr)
				var is_active: bool = ctx.player_passive_shield.get_ability_active(attr)

				if is_active:
					t += " [ACTIVE]"
				elif cooldown > 0.0:
					t += " [CD: %.1fs]" % cooldown
				else:
					t += " [READY]"

	return t

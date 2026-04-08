extends DebugHUDSection
class_name EnemyAISection


func section_name() -> String:
	return "ENEMY AI"


func build_text(ctx: DebugHUDContext) -> String:
	var enemies: Array[Node] = ctx.enemies
	if enemies.is_empty():
		return "(no enemies found)"

	var t: String = "Count: %d" % enemies.size()

	for enemy: Node in enemies:
		t += "\n\n--- %s ---" % enemy.name

		# AI state
		var ai: EnemyAI = enemy.get_node_or_null("EnemyAI") as EnemyAI
		if ai != null:
			var awareness_names := ["IDLE", "ALERT", "LOST"]
			var awareness_idx: int = ai.get_awareness()
			var awareness_str: String = awareness_names[awareness_idx] if awareness_idx < awareness_names.size() else "UNKNOWN"
			t += "\nState: %s" % awareness_str

			var decision: AIDecision = ai.get_current_decision()
			if decision != null:
				t += "\nDecision: %s (pri: %d)" % [decision.state, decision.priority]
			else:
				t += "\nDecision: (none)"

			var target: Node2D = ai.get_target()
			if target != null and ai.get_entity() != null:
				var dist: float = ai.get_entity().global_position.distance_to(target.global_position)
				t += "\nDist: %.0f" % dist
			else:
				t += "\nTarget: (none)"
		else:
			t += "\n(no EnemyAI)"

		# Loadout
		var eq: Equipment = enemy.get_node_or_null("Equipment") as Equipment
		if eq != null:
			var items: Dictionary[String, Node] = eq.get_equipped_items_debug()
			t += "\n[b]Loadout:[/b]"

			for slot_name: String in ["MELEE", "RANGED", "SPELL", "SHIELD"]:
				var item: Node = items.get(slot_name)
				if item != null:
					t += "\n  %s: %s" % [slot_name, _item_name(item)]
				else:
					t += "\n  %s: (empty)" % slot_name
		else:
			t += "\n(no Equipment)"

		# Health
		var health: Health = null
		if enemy is Entity:
			health = (enemy as Entity).find_component(&"Health") as Health
		else:
			health = enemy.get_node_or_null("Health") as Health

		if health != null:
			t += "\nHP: %.0f / %.0f (%.0f%%)" % [health.hp, health.max_hp, (health.hp / health.max_hp) * 100.0]

	return t


func _item_name(item: Node) -> String:
	if item.has_method("get_item_instance"):
		var inst: ItemInstance = item.call("get_item_instance") as ItemInstance
		if inst != null and inst.def != null:
			var display: String = inst.def.display_name.strip_edges()
			if not display.is_empty():
				var rarity: int = inst.attributes.size()
				if rarity > 0:
					return "%s [%d attr]" % [display, rarity]
				return display

	if "item_def" in item:
		var def: ItemDef = item.get("item_def") as ItemDef
		if def != null:
			var display: String = def.display_name.strip_edges()
			if not display.is_empty():
				return display

	return str(item.name)

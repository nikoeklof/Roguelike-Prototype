extends ItemAttribute
class_name DebuffSpellAttribute

## Helper to apply debuff to a single target
func apply_debuff_to_target(victim: Node, context: CombatContext, item_instance: ItemInstance) -> void:
	if victim == null:
		return
	
	var hit_event: HitEvent = HitEvent.new()
	hit_event.victim = victim
	hit_event.attacker = context.owner
	hit_event.damage = 0.0
	
	# Subclasses implement their own on_hit logic
	on_hit(context, hit_event, item_instance)

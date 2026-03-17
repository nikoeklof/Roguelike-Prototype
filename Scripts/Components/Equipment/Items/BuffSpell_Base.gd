extends Spell
class_name BuffSpell

# Buff spells apply effects to the caster only


func _do_cast(_owner_entity: Node, _dir: Vector2) -> void:
	# Buff spells apply immediately to self
	if _instance == null:
		return

	var ctx: CombatContext = _make_context(_owner_entity, _dir)
	
	# Dispatch attributes to apply buffs
	ItemAttributeBus.dispatch_cast_apply(ctx, _instance)

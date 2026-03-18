extends Spell
class_name BuffSpell

func _do_cast(owner_entity: Node, _dir: Vector2) -> void:
	if _instance == null or owner_entity == null:
		print("[BuffSpell] Cannot cast: instance=%s, owner=%s" % [_instance, owner_entity])
		return

	print("[BuffSpell] Casting buff spell '%s'" % name)
	var ctx: CombatContext = _make_context(owner_entity, _dir)
	print("[BuffSpell] Context: owner=%s, item_instance=%s" % [ctx.owner, ctx.item_instance])
	
	if _instance == null or _instance.def == null:
		print("[BuffSpell] No item definition")
		return
	
	print("[BuffSpell] Attributes: %d" % _instance.attributes.size())
	
	# Use ItemAttributeBus to dispatch cast_apply
	# This should handle attribute instantiation internally
	ItemAttributeBus.dispatch_cast_apply(ctx, _instance)
	
	print("[BuffSpell] Buff applied successfully")

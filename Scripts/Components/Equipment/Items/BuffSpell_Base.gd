extends Spell
class_name BuffSpell

func _do_cast(owner_entity: Node, _dir: Vector2) -> void:
	if _instance == null:
		print("[BuffSpell] Instance is null!")
		return
	
	if owner_entity == null:
		print("[BuffSpell] Owner entity is null!")
		return

	print("[BuffSpell] Casting buff spell '%s'" % name)
	
	var ctx: CombatContext = _make_context(owner_entity, _dir)
	print("[BuffSpell] Context: owner=%s" % ctx.owner)
	print("[BuffSpell] Item instance: %s" % _instance)
	print("[BuffSpell] Item def: %s" % _instance.def)
	
	# Deep inspection of attributes
	print("[BuffSpell] Attributes array size: %d" % _instance.attributes.size())
	print("[BuffSpell] Attributes: %s" % _instance.attributes)
	
	for i in range(_instance.attributes.size()):
		var attr = _instance.attributes[i]
		print("[BuffSpell] Attribute[%d]: %s (class: %s)" % [i, attr, attr.get_class() if attr else "null"])
		
		if attr != null and attr is ItemAttribute:
			print("[BuffSpell]   - Is ItemAttribute: YES")
			print("[BuffSpell]   - Domains: %s" % PackedStringArray(attr.default_domains()))
			print("[BuffSpell]   - Applies to 'cast'? %s" % attr.applies_to_domain(&"cast"))
		else:
			print("[BuffSpell]   - Is ItemAttribute: NO")
	
	print("[BuffSpell] Dispatching via ItemAttributeBus...")
	ItemAttributeBus.dispatch_cast_apply(ctx, _instance)
	
	print("[BuffSpell] Done!")

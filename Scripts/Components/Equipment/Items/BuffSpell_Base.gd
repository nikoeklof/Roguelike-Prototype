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
	
	for i in range(_instance.attributes.size()):
		var attr = _instance.attributes[i]
		
		if attr != null and attr is ItemAttribute:
			# Get the attribute label
			var label: String = ""
			if "display_name" in attr and attr.display_name != "":
				label = attr.display_name
			elif "id" in attr and attr.id != &"":
				label = str(attr.id)
			else:
				label = attr.get_class()
			
			print("[BuffSpell] Attribute[%d]: %s" % [i, label])
			
			var domains: PackedStringArray = attr.default_domains()
			print("[BuffSpell]   - Domains: %s" % str(domains))
			print("[BuffSpell]   - Applies to 'cast'? %s" % attr.applies_to_domain(&"cast"))
		else:
			print("[BuffSpell] Attribute[%d]: NULL or invalid" % i)
	
	print("[BuffSpell] Dispatching via ItemAttributeBus...")
	ItemAttributeBus.dispatch_cast_apply(ctx, _instance)
	
	print("[BuffSpell] Done!")

extends RefCounted
class_name ShieldBlockExecutor

# Domains for shield blocking
const DOMAIN_BLOCK_START: StringName = &"block_start"
const DOMAIN_BLOCK_END: StringName = &"block_end"


static func execute_block_start(entity: Node, shield: Shield, shield_instance: ItemInstance) -> void:
	"""Activate all blocking-related attributes on a shield"""
	if shield_instance == null:
		return
	
	if shield_instance.attributes.is_empty():
		return
	
	print("[ShieldBlockExecutor] Executing block_start for shield: %s (%d attributes)" % [shield.name if shield else "unknown", shield_instance.attributes.size()])
	
	# Create context
	var ctx := CombatContext.new()
	ctx.owner = entity
	ctx.item = shield
	ctx.item_instance = shield_instance
	
	# Dispatch to all attributes that apply to block_start domain
	for attr: ItemAttribute in shield_instance.attributes:
		if attr == null:
			continue
		
		if attr.applies_to_domain(DOMAIN_BLOCK_START):
			_execute_attribute_block_start(attr, ctx, shield_instance)


static func execute_block_end(entity: Node, shield: Shield, shield_instance: ItemInstance) -> void:
	"""Deactivate all blocking-related attributes on a shield"""
	if shield_instance == null:
		return
	
	if shield_instance.attributes.is_empty():
		return
	
	print("[ShieldBlockExecutor] Executing block_end for shield: %s (%d attributes)" % [shield.name if shield else "unknown", shield_instance.attributes.size()])
	
	# Create context
	var ctx := CombatContext.new()
	ctx.owner = entity
	ctx.item = shield
	ctx.item_instance = shield_instance
	
	# Dispatch to all attributes that apply to block_end domain
	for attr: ItemAttribute in shield_instance.attributes:
		if attr == null:
			continue
		
		if attr.applies_to_domain(DOMAIN_BLOCK_END):
			_execute_attribute_block_end(attr, ctx, shield_instance)


static func _execute_attribute_block_start(attr: ItemAttribute, ctx: CombatContext, inst: ItemInstance) -> void:
	"""Execute block_start hook on attribute"""
	if not attr.has_method("on_block_start"):
		return
	
	attr.call("on_block_start", ctx, inst)
	print("[ShieldBlockExecutor] Called on_block_start for: %s" % attr.get_class())


static func _execute_attribute_block_end(attr: ItemAttribute, ctx: CombatContext, inst: ItemInstance) -> void:
	"""Execute block_end hook on attribute"""
	if not attr.has_method("on_block_end"):
		return
	
	attr.call("on_block_end", ctx, inst)
	print("[ShieldBlockExecutor] Called on_block_end for: %s" % attr.get_class())

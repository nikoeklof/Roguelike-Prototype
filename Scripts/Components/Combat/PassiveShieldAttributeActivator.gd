extends Node
class_name PassiveShieldAttributeActivator

signal ability_activated(attribute: ItemAttribute, cooldown: float)

var _entity: Entity
var _shield_instance: ItemInstance
var _active_abilities: Dictionary = {}  # attribute_id -> { cooldown_until, activated_at, duration }


func _ready() -> void:
	_entity = get_parent() as Entity
	if _entity == null:
		print("[PassiveShieldAttributeActivator] ERROR: Parent is not Entity")
		return
	
	print("[PassiveShieldAttributeActivator] Ready")


func _physics_process(_delta: float) -> void:
	if _entity == null or _shield_instance == null:
		return
	
	# Check for block input
	var control: ControlSource = _entity.find_component(&"ControlSource") as ControlSource
	if control == null:
		return
	
	# Only trigger if block input is pressed
	if control.wants_block():
		_try_activate_abilities()


func set_shield_instance(instance: ItemInstance) -> void:
	"""Set the shield instance when equipped"""
	_shield_instance = instance
	_active_abilities.clear()
	print("[PassiveShieldAttributeActivator] Shield instance set: %s" % (instance.def.display_name if instance.def else "unknown"))


func _try_activate_abilities() -> void:
	"""Try to activate all passive shield abilities that are ready"""
	if _shield_instance == null or _shield_instance.attributes.is_empty():
		return
	
	var now: float = Time.get_ticks_msec() / 1000.0
	
	for attr: ItemAttribute in _shield_instance.attributes:
		if attr == null:
			continue
		
		if not _is_ability_attribute(attr):
			continue
		
		var attr_id: StringName = attr.id
		var ability_data: Dictionary = _active_abilities.get(attr_id, {})
		var cooldown_until: float = ability_data.get("cooldown_until", 0.0)
		
		if now >= cooldown_until:
			_activate_ability(attr, now)


func _is_ability_attribute(attr: ItemAttribute) -> bool:
	"""Check if attribute has ability mechanics"""
	return attr is PhasingAttribute


func _activate_ability(attr: ItemAttribute, now: float) -> void:
	"""Activate a passive shield ability"""
	var attr_id: StringName = attr.id
	
	print("[PassiveShieldAttributeActivator] Activating ability: %s" % attr.display_name)
	
	# Call the ability hook
	if attr.has_method("on_ability_activate"):
		var ctx := CombatContext.new()
		ctx.owner = _entity
		ctx.item_instance = _shield_instance
		attr.call("on_ability_activate", ctx, _shield_instance)
	
	# Calculate cooldown and duration from attribute
	var cooldown: float = 0.0
	var duration: float = 0.0
	
	if attr is PhasingAttribute:
		var phasing: PhasingAttribute = attr as PhasingAttribute
		cooldown = phasing.phase_cooldown_sec
		duration = phasing.phase_duration_sec
	
	# Store full ability data as Dictionary (FIXED)
	_active_abilities[attr_id] = {
		"cooldown_until": now + cooldown,
		"activated_at": now,
		"duration": duration
	}
	
	print("[PassiveShieldAttributeActivator] Ability cooldown set: %.1fs" % cooldown)
	ability_activated.emit(attr, cooldown)


func get_ability_cooldown_remaining(attr: ItemAttribute) -> float:
	"""Get remaining cooldown for an ability"""
	if attr == null:
		return 0.0
	
	var ability_data: Dictionary = _active_abilities.get(attr.id, {})
	var cooldown_until: float = ability_data.get("cooldown_until", 0.0)
	var now: float = Time.get_ticks_msec() / 1000.0
	
	return maxf(0.0, cooldown_until - now)


func get_ability_active(attr: ItemAttribute) -> bool:
	"""Check if ability is currently active"""
	if attr == null or not (attr is PhasingAttribute):
		return false
	
	if _entity != null:
		return _entity.get_meta(PhasingAttribute.META_PHASING, false)
	
	return false


func get_active_abilities() -> Dictionary:
	"""Get all active abilities data for debug display"""
	return _active_abilities.duplicate()


func get_active_ability_buffs(shield_instance: ItemInstance) -> Array[String]:
	"""PUBLIC: Get formatted buff text for all active passive shield abilities"""
	var buffs: Array[String] = []
	var now: float = Time.get_ticks_msec() / 1000.0
	
	if shield_instance == null or shield_instance.attributes.is_empty():
		return buffs
	
	for attr: ItemAttribute in shield_instance.attributes:
		if attr == null:
			continue
		
		if not _is_ability_attribute(attr):
			continue
		
		var is_active: bool = get_ability_active(attr)
		var cooldown_remaining: float = get_ability_cooldown_remaining(attr)
		
		# Format buff text based on state
		var buff_text: String = ""
		if is_active:
			# Show remaining duration for active abilities
			if attr is PhasingAttribute:
				var phasing: PhasingAttribute = attr as PhasingAttribute
				var ability_data: Dictionary = _active_abilities.get(attr.id, {})
				var activated_at: float = ability_data.get("activated_at", 0.0)
				var remaining: float = (activated_at + phasing.phase_duration_sec) - now
				buff_text = "[%s] (%.1fs)" % [attr.display_name, maxf(0.0, remaining)]
		elif cooldown_remaining > 0.0:
			# Show cooldown if not ready
			buff_text = "[%s] CD: %.1fs" % [attr.display_name, cooldown_remaining]
		
		if buff_text != "":
			buffs.append(buff_text)
	
	return buffs

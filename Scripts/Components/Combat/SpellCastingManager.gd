extends Node
class_name SpellCastingManager

@export var equipment_path: NodePath
@export var cast_input_action: String = "ui_cast_spell"

var _equipment: Equipment = null
var _owner_entity: Node = null
var _spell_slot: EquipmentSlot = null
var _queued_spell_cast: bool = false


func _ready() -> void:
	_owner_entity = _find_owner_entity()
	print("[SpellCastingManager] Owner entity: %s" % _owner_entity)
	
	# Resolve equipment from path or auto-find
	if equipment_path != NodePath(""):
		print("[SpellCastingManager] Trying to find equipment at path: %s" % equipment_path)
		_equipment = get_node_or_null(equipment_path) as Equipment
	
	# If not found, try auto-finding from owner
	if _equipment == null and _owner_entity != null:
		print("[SpellCastingManager] Auto-searching for Equipment in owner")
		_equipment = _owner_entity.get_node_or_null("Equipment") as Equipment
	
	if _equipment == null:
		push_error("[SpellCastingManager] FAILED: Equipment not found!")
		return

	print("[SpellCastingManager] ✓ Equipment found: %s" % _equipment.name)
	print("[SpellCastingManager] Spell slot path from Equipment: %s" % _equipment.spell_slot_path)
	
	# Get the spell slot - use Equipment's internal _slot() method via get_node_or_null
	# The spell_slot_path is relative to Equipment, so we need to call on Equipment
	_spell_slot = _equipment.get_node_or_null(_equipment.spell_slot_path) as EquipmentSlot
	
	if _spell_slot == null:
		print("[SpellCastingManager] ⚠ Warning: Spell slot not found at path '%s' - this is OK if no spell is equipped yet" % _equipment.spell_slot_path)
		# Don't return - we'll retry when spell is picked up
	else:
		print("[SpellCastingManager] ✓ Spell slot found: %s" % _spell_slot.name)
		# IMPORTANT: Listen for changes to the spell slot
		if not _spell_slot.changed.is_connected(_on_spell_slot_changed):
			_spell_slot.changed.connect(_on_spell_slot_changed)
	
	# Hook weapon signals for queueing
	_hook_weapon_signals()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(cast_input_action):
		print("[SpellCastingManager] Cast input pressed!")
		_on_cast_input_pressed()


func _on_cast_input_pressed() -> void:
	if _equipment == null or _owner_entity == null:
		print("[SpellCastingManager] Early exit: equipment=%s, owner=%s" % [_equipment, _owner_entity])
		return

	# If we can cast immediately, do it
	if _try_cast_spell_now():
		print("[SpellCastingManager] ✓ Spell cast immediately")
		_queued_spell_cast = false
		return

	# Otherwise queue it for when weapon finishes
	print("[SpellCastingManager] Spell queued (weapon in progress)")
	_queued_spell_cast = true


func _try_cast_spell_now() -> bool:
	if _equipment == null or _owner_entity == null:
		return false

	# Ensure spell slot is found (in case it was picked up after startup)
	if _spell_slot == null:
		_spell_slot = _equipment.get_node_or_null(_equipment.spell_slot_path) as EquipmentSlot
		if _spell_slot == null:
			print("[SpellCastingManager] Cannot cast: spell slot still not found")
			return false
		# Connect to changes now
		if not _spell_slot.changed.is_connected(_on_spell_slot_changed):
			_spell_slot.changed.connect(_on_spell_slot_changed)

	# Get equipped spell from the spell slot
	var spell: Spell = _spell_slot.get_item() as Spell
	
	if spell == null:
		print("[SpellCastingManager] No spell equipped")
		return false
	
	if not spell.can_cast():
		print("[SpellCastingManager] Spell on cooldown")
		return false

	# Get aim direction from AimRay
	var aim_dir: Vector2 = _get_aim_direction()

	# Try to cast the spell
	var success: bool = spell.try_cast(_owner_entity, aim_dir)
	if success:
		print("[SpellCastingManager] ✓ Spell '%s' cast successfully!" % spell.name)
	else:
		print("[SpellCastingManager] ✗ Spell cast failed")
	
	return success


func _try_cast_queued_spell() -> void:
	if not _queued_spell_cast:
		return

	_queued_spell_cast = false
	print("[SpellCastingManager] Attempting queued spell cast...")
	_try_cast_spell_now()


func _on_spell_slot_changed(new_item: Node, _old_item: Node) -> void:
	"""Called whenever a spell is equipped or unequipped"""
	var spell: Spell = new_item as Spell
	if spell != null:
		print("[SpellCastingManager] ✓ New spell equipped: %s" % spell.name)
	else:
		print("[SpellCastingManager] Spell slot cleared")


func _get_aim_direction() -> Vector2:
	if _owner_entity == null:
		return Vector2.RIGHT

	# Try to get direction from AimRay
	var aim_ray: AimRay = _owner_entity.get_node_or_null("FacingPointer/AimRay") as AimRay
	if aim_ray != null:
		var aim_angle: float = aim_ray.global_rotation
		return Vector2.RIGHT.rotated(aim_angle)

	# Fallback to facing direction
	var facing_pointer: FacingPointer = _owner_entity.get_node_or_null("FacingPointer") as FacingPointer
	if facing_pointer != null and facing_pointer.facing_vector.length() > 0.001:
		return facing_pointer.facing_vector.normalized()

	return Vector2.RIGHT


func _hook_weapon_signals() -> void:
	if _equipment == null:
		print("[SpellCastingManager] Cannot hook weapon signals: equipment is null")
		return

	# Hook melee weapon
	var melee_slot: EquipmentSlot = _equipment.get_node_or_null(_equipment.melee_slot_path) as EquipmentSlot
	if melee_slot != null:
		melee_slot.changed.connect(_on_melee_weapon_changed)
		var weapon: Weapon = melee_slot.get_item() as Weapon
		if weapon != null and weapon.has_signal("attack_finished"):
			weapon.attack_finished.connect(_try_cast_queued_spell, CONNECT_ONE_SHOT)
			print("[SpellCastingManager] ✓ Hooked melee weapon")

	# Hook ranged weapon
	var ranged_slot: EquipmentSlot = _equipment.get_node_or_null(_equipment.ranged_slot_path) as EquipmentSlot
	if ranged_slot != null:
		ranged_slot.changed.connect(_on_ranged_weapon_changed)
		var weapon: Weapon = ranged_slot.get_item() as Weapon
		if weapon != null and weapon.has_signal("attack_finished"):
			weapon.attack_finished.connect(_try_cast_queued_spell, CONNECT_ONE_SHOT)
			print("[SpellCastingManager] ✓ Hooked ranged weapon")


func _on_melee_weapon_changed(new_item: Node, _old_item: Node) -> void:
	var weapon: Weapon = new_item as Weapon
	if weapon != null and weapon.has_signal("attack_finished"):
		weapon.attack_finished.connect(_try_cast_queued_spell, CONNECT_ONE_SHOT)


func _on_ranged_weapon_changed(new_item: Node, _old_item: Node) -> void:
	var weapon: Weapon = new_item as Weapon
	if weapon != null and weapon.has_signal("attack_finished"):
		weapon.attack_finished.connect(_try_cast_queued_spell, CONNECT_ONE_SHOT)


func _find_owner_entity() -> Node:
	var p: Node = get_parent()
	while p != null:
		if p is CharacterBody2D:
			return p
		p = p.get_parent()
	return null

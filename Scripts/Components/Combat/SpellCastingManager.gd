extends Node
class_name SpellCastingManager

@export var equipment_path: NodePath = NodePath("")
@export var cast_input_action: StringName = &"Cast"

var _owner_entity: Node = null
var _equipment: Equipment = null
var _spell_slot: EquipmentSlot = null
var _queued_spell_cast: bool = false


func _ready() -> void:
	print("[SpellCastingManager] _ready() called")
	_owner_entity = _find_owner_entity()
	
	if _owner_entity == null:
		push_error("[SpellCastingManager] FAILED: Owner entity not found!")
		return

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

	# Check spell cooldown ONCE before attempting cast
	var stats: Stats = null
	if _owner_entity is Entity:
		stats = (_owner_entity as Entity).find_component(&"Stats") as Stats
	else:
		stats = _owner_entity.get_node_or_null("Stats") as Stats
	
	if stats != null and not stats.is_spell_ready():
		var remaining := stats.get_spell_cooldown_remaining()
		print("[SpellCastingManager] Spell on cooldown - %.2fs remaining" % remaining)
		return false
	
	# Get item instance for the spell
	var item_instance: ItemInstance = spell.get_item_instance() if spell.has_method("get_item_instance") else null
	
	# Try to cast via combat system
	var combat: Combat = null
	if _owner_entity is Entity:
		combat = (_owner_entity as Entity).get_component(&"Combat") as Combat
	else:
		combat = _owner_entity.get_node_or_null("Combat") as Combat
	
	if combat == null:
		print("[SpellCastingManager] No Combat component found")
		return false

	# Create context and attempt cast
	var context: CombatContext = CombatContext.new()
	context.owner = _owner_entity
	context.item = spell
	context.item_instance = item_instance
	context.spread_roll = randi()

	combat.try_attack(Combat.AttackKind.SPELL, Vector2.RIGHT, context)
	
	# Apply spell cooldown on successful cast
	if stats != null and spell.has_meta("cooldown_sec"):
		var cooldown: float = float(spell.get_meta("cooldown_sec"))
		stats.apply_spell_cooldown(cooldown)
		print("[SpellCastingManager] Applied spell cooldown: %.2fs" % cooldown)
	
	print("[SpellCastingManager] Spell cast!")
	return true


func _hook_weapon_signals() -> void:
	if _equipment == null:
		return

	# Hook into weapon signals for queued spell casting
	var melee_slot: EquipmentSlot = _equipment.get_node_or_null(_equipment.melee_slot_path) as EquipmentSlot
	if melee_slot != null and melee_slot.has_signal("item_action_finished"):
		if not melee_slot.item_action_finished.is_connected(_on_weapon_action_finished):
			melee_slot.item_action_finished.connect(_on_weapon_action_finished)

	var ranged_slot: EquipmentSlot = _equipment.get_node_or_null(_equipment.ranged_slot_path) as EquipmentSlot
	if ranged_slot != null and ranged_slot.has_signal("item_action_finished"):
		if not ranged_slot.item_action_finished.is_connected(_on_weapon_action_finished):
			ranged_slot.item_action_finished.connect(_on_weapon_action_finished)


func _on_weapon_action_finished(_item: Node) -> void:
	print("[SpellCastingManager] Weapon action finished")
	if _queued_spell_cast:
		_queued_spell_cast = false
		if _try_cast_spell_now():
			print("[SpellCastingManager] ✓ Queued spell cast")


func _on_spell_slot_changed(_new_item: Node, _old_item: Node) -> void:
	print("[SpellCastingManager] Spell slot changed - new spell: %s" % (_new_item.name if _new_item else "none"))


func _find_owner_entity() -> Node:
	var n: Node = self
	while n != null:
		if n is Entity or n is CharacterBody2D:
			return n
		n = n.get_parent()
	return null

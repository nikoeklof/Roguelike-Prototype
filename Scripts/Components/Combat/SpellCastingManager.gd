extends Node
class_name SpellCastingManager

@export var equipment_path: NodePath = NodePath("")
@export var cast_input_action: StringName = &"Cast"

var _owner_entity: Node = null
var _equipment: Equipment = null
var _spell_slot: EquipmentSlot = null
var _queued_spell_cast: bool = false
var _is_player_controlled: bool = false


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
	
	# Get the spell slot
	_spell_slot = _equipment.get_node_or_null(_equipment.spell_slot_path) as EquipmentSlot
	
	if _spell_slot == null:
		print("[SpellCastingManager] ⚠ Warning: Spell slot not found at path '%s' - this is OK if no spell is equipped yet" % _equipment.spell_slot_path)
	else:
		print("[SpellCastingManager] ✓ Spell slot found: %s" % _spell_slot.name)
		if not _spell_slot.changed.is_connected(_on_spell_slot_changed):
			_spell_slot.changed.connect(_on_spell_slot_changed)
	
	_is_player_controlled = _detect_player_controlled()
	_hook_weapon_signals()


func _process(_delta: float) -> void:
	pass  # Spell input is handled by PlayerControl (Q key) and EnemyAI directly.


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

	# Ensure spell slot is found
	if _spell_slot == null:
		_spell_slot = _equipment.get_node_or_null(_equipment.spell_slot_path) as EquipmentSlot
		if _spell_slot == null:
			print("[SpellCastingManager] Cannot cast: spell slot not found")
			return false
		if not _spell_slot.changed.is_connected(_on_spell_slot_changed):
			_spell_slot.changed.connect(_on_spell_slot_changed)

	# Get equipped spell
	var spell: Spell = _spell_slot.get_item() as Spell
	
	if spell == null:
		print("[SpellCastingManager] No spell equipped")
		return false

	# Get Stats for cooldown check
	var stats: Stats = null
	if _owner_entity is Entity:
		stats = (_owner_entity as Entity).find_component(&"Stats") as Stats
	else:
		stats = _owner_entity.get_node_or_null("Stats") as Stats
	
	# Check global spell cooldown
	if stats != null and not stats.is_spell_ready():
		var remaining := stats.get_spell_cooldown_remaining()
		print("[SpellCastingManager] Spell on cooldown - %.2fs remaining" % remaining)
		return false
	
	# Resolve aim direction from mouse position.
	var aim_dir: Vector2 = Vector2.RIGHT
	if _owner_entity is Node2D:
		var mouse_dir: Vector2 = (_owner_entity as Node2D).get_global_mouse_position() - (_owner_entity as Node2D).global_position
		if mouse_dir.length() > 0.001:
			aim_dir = mouse_dir.normalized()

	# Use Spell's try_cast method directly
	var success: bool = spell.try_cast(_owner_entity, aim_dir)
	
	if success and stats != null:
		# Get the cooldown from the spell's item instance
		var cooldown_sec: float = 0.0
		if spell.has_method("get_item_instance"):
			var item_instance: ItemInstance = spell.get_item_instance()
			if item_instance != null:
				var ctx: CombatContext = CombatContext.new()
				ctx.owner = _owner_entity
				ctx.item = spell
				ctx.item_instance = item_instance
				
				if _owner_entity is Entity:
					ctx.stats = (_owner_entity as Entity).find_component(&"Stats")
				else:
					ctx.stats = _owner_entity.get_node_or_null("Stats")
				
				var item_stats: ItemStats = item_instance.compute_stats(ctx)
				if item_stats != null:
					cooldown_sec = item_stats.cooldown_sec
		
		# Apply global spell cooldown
		stats.apply_spell_cooldown(cooldown_sec)
		print("[SpellCastingManager] Applied spell cooldown: %.2fs" % cooldown_sec)
	
	print("[SpellCastingManager] Spell cast: %s" % success)
	return success


func _hook_weapon_signals() -> void:
	if _equipment == null:
		return

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
	print("[SpellCastingManager] Spell slot changed - new spell: %s" % (str(_new_item.name) if _new_item else "none"))


func _find_owner_entity() -> Node:
	var n: Node = self
	while n != null:
		if n is Entity or n is CharacterBody2D:
			return n
		n = n.get_parent()
	return null


func _detect_player_controlled() -> bool:
	if _owner_entity == null:
		return false
	# Group check is authoritative — every player entity is added to "player".
	if _owner_entity.is_in_group("player"):
		return true
	# Fallback: presence of a PlayerControl component.
	if _owner_entity is Entity:
		return (_owner_entity as Entity).find_component(&"PlayerControl") != null
	return _owner_entity.get_node_or_null("PlayerControl") != null

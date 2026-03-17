extends Node
class_name SpellCastingManager

@export var equipment_path: NodePath
@export var cast_input_action: String = "ui_cast_spell"

var _equipment: Equipment = null
var _owner_entity: Node = null
var _queued_spell_cast: bool = false


func _ready() -> void:
	_equipment = get_node_or_null(equipment_path) as Equipment
	_owner_entity = _find_owner_entity()

	if _equipment == null:
		push_warning("SpellCastingManager: equipment not found at %s" % equipment_path)

	# Hook into weapon attack finished signals to drain queued spell casts
	_hook_weapon_signals()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(cast_input_action):
		_on_cast_input_pressed()


func _on_cast_input_pressed() -> void:
	
	if _equipment == null or _owner_entity == null:
		return

	# If we can cast immediately, do it
	if _try_cast_spell_now():
		print("Spell Input Pressed")
		_queued_spell_cast = false
		return

	# Otherwise queue it for when weapon finishes
	_queued_spell_cast = true


func _try_cast_spell_now() -> bool:
	if _equipment == null or _owner_entity == null:
		return false

	# Get equipped spell
	var spell_slot: SpellSlot = _equipment.get_node_or_null(_equipment.spell_slot_path) as SpellSlot
	if spell_slot == null:
		return false

	var spell: Spell = spell_slot.get_item() as Spell
	if spell == null or not spell.can_cast():
		return false

	# Get aim direction from AimRay
	var aim_dir: Vector2 = _get_aim_direction()

	# Try to cast the spell
	var success: bool = spell.try_cast(_owner_entity, aim_dir)
	print("%s casted!" % spell.label)
	return success


func _try_cast_queued_spell() -> void:
	if not _queued_spell_cast:
		return

	_queued_spell_cast = false
	_try_cast_spell_now()


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
		return

	# Hook melee weapon
	var melee_slot: EquipmentSlot = _equipment.get_node_or_null(_equipment.melee_slot_path) as EquipmentSlot
	if melee_slot != null:
		melee_slot.changed.connect(_on_melee_weapon_changed)
		var weapon: Weapon = melee_slot.get_item() as Weapon
		if weapon != null and weapon.has_signal("attack_finished"):
			weapon.attack_finished.connect(_try_cast_queued_spell, CONNECT_ONE_SHOT)

	# Hook ranged weapon
	var ranged_slot: EquipmentSlot = _equipment.get_node_or_null(_equipment.ranged_slot_path) as EquipmentSlot
	if ranged_slot != null:
		ranged_slot.changed.connect(_on_ranged_weapon_changed)
		var weapon: Weapon = ranged_slot.get_item() as Weapon
		if weapon != null and weapon.has_signal("attack_finished"):
			weapon.attack_finished.connect(_try_cast_queued_spell, CONNECT_ONE_SHOT)


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

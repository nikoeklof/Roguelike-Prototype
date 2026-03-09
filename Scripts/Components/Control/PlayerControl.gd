extends ControlSource
class_name PlayerControl

# Movement actions (match Project Settings → Input Map exactly)
@export var left_action: StringName  = &"Left"
@export var right_action: StringName = &"Right"
@export var up_action: StringName    = &"Up"
@export var down_action: StringName  = &"Down"

# Combat
@export var attack_action: StringName = &"Attack"
@export var block_action: StringName  = &"Shield"

# Slot switching
@export var slot_melee_action: StringName  = &"SlotMelee"
@export var slot_ranged_action: StringName = &"SlotRanged"
@export var slot_spell_action: StringName  = &"SlotSpell"
@export var next_slot_action: StringName   = &"NextSlot"
@export var prev_slot_action: StringName   = &"PrevSlot"


func _physics_process(_delta: float) -> void:
	var entity: CharacterBody2D = _entity_root()
	if entity == null:
		return

	var eq: Equipment = _equipment(entity)
	if eq == null:
		return

	if Input.is_action_just_pressed(slot_melee_action):
		eq.set_active_slot_melee("player_input")
	elif Input.is_action_just_pressed(slot_ranged_action):
		eq.set_active_slot_ranged("player_input")
	elif Input.is_action_just_pressed(slot_spell_action):
		eq.set_active_slot_spell("player_input")
	elif Input.is_action_just_pressed(next_slot_action):
		eq.cycle_active_slot(+1, "player_input")
	elif Input.is_action_just_pressed(prev_slot_action):
		eq.cycle_active_slot(-1, "player_input")


func move_intent() -> Vector2:
	var x: float = Input.get_action_strength(right_action) - Input.get_action_strength(left_action)
	var y: float = Input.get_action_strength(down_action) - Input.get_action_strength(up_action)
	var v: Vector2 = Vector2(x, y)
	if v.length() > 0.001:
		return v.normalized()
	return Vector2.ZERO


func attack_pressed() -> bool:
	return Input.is_action_just_pressed(attack_action)


func attack_released() -> bool:
	return Input.is_action_just_released(attack_action)


func attack_is_down() -> bool:
	return Input.is_action_pressed(attack_action)


func attack_kind_peek() -> Combat.AttackKind:
	if Input.is_action_pressed(attack_action):
		return _active_attack_kind()
	return Combat.AttackKind.NONE


func attack_kind_pressed() -> Combat.AttackKind:
	if Input.is_action_just_pressed(attack_action):
		return _active_attack_kind()
	return Combat.AttackKind.NONE


func attack_kind_held() -> Combat.AttackKind:
	if Input.is_action_pressed(attack_action):
		return _active_attack_kind()
	return Combat.AttackKind.NONE


func attack_kind_released() -> Combat.AttackKind:
	if Input.is_action_just_released(attack_action):
		return _active_attack_kind()
	return Combat.AttackKind.NONE


func aim_dir(fallback: Vector2) -> Vector2:
	var entity: CharacterBody2D = _entity_root()
	if entity == null:
		return fallback

	var dir: Vector2 = entity.get_global_mouse_position() - entity.global_position
	if dir.length() < 0.001:
		return fallback
	return dir.normalized()


func wants_block() -> bool:
	return Input.is_action_pressed(block_action)


func active_weapon_fires_while_held() -> bool:
	return true


func weapon_fires_while_held_for_kind(_kind: Combat.AttackKind) -> bool:
	return true


func _entity_root() -> CharacterBody2D:
	var n: Node = self
	while n != null and not (n is CharacterBody2D):
		n = n.get_parent()
	return n as CharacterBody2D if n is CharacterBody2D else null


func _equipment(entity: Node) -> Equipment:
	if entity is Entity:
		var eq: Equipment = (entity as Entity).get_component(&"Equipment") as Equipment
		if eq != null:
			return eq
	return entity.get_node_or_null("Equipment") as Equipment


func _active_attack_kind() -> Combat.AttackKind:
	var entity: CharacterBody2D = _entity_root()
	if entity == null:
		return Combat.AttackKind.MELEE

	var eq: Equipment = _equipment(entity)
	if eq != null:
		return eq.active_slot

	return Combat.AttackKind.MELEE

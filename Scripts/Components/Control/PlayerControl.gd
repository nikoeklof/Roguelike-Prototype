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
	# Handle slot switching live while the game is running.
	# We do it here (instead of inside state logic) so it works regardless of FSM state.
	var entity := _entity_root()
	if entity == null:
		return

	var eq := _equipment(entity)
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
	var v := Vector2(x, y)
	return v.normalized() if v.length() > 0.001 else Vector2.ZERO


# --- Raw button semantics ---
func attack_pressed() -> bool:
	return Input.is_action_just_pressed(attack_action)

func attack_released() -> bool:
	return Input.is_action_just_released(attack_action)

func attack_is_down() -> bool:
	return Input.is_action_pressed(attack_action)


# --- Kind-based semantics ---
# Attack button requests an attack of the CURRENT active slot.
func attack_kind_peek() -> Combat.AttackKind:
	if Input.is_action_pressed(attack_action):
		return _active_attack_kind()
	return Combat.AttackKind.NONE

func attack_kind_pressed() -> Combat.AttackKind:
	if Input.is_action_just_pressed(attack_action):
		return _active_attack_kind()
	return Combat.AttackKind.NONE


func aim_dir(fallback: Vector2) -> Vector2:
	var entity := _entity_root()
	if entity == null:
		return fallback

	var dir := entity.get_global_mouse_position() - entity.global_position
	if dir.length() < 0.001:
		return fallback
	return dir.normalized()


func wants_block() -> bool:
	return Input.is_action_pressed(block_action)


# --- Helpers ---

func _entity_root() -> CharacterBody2D:
	var n: Node = self
	while n != null and not (n is CharacterBody2D):
		n = n.get_parent()
	return n as CharacterBody2D if n is CharacterBody2D else null


func _equipment(entity: Node) -> Equipment:
	# Prefer component lookup if available.
	if entity is Entity:
		var eq := (entity as Entity).get_component(&"Equipment") as Equipment
		if eq != null:
			return eq

	# Fallback: node by name
	return entity.get_node_or_null("Equipment") as Equipment


func _active_attack_kind() -> Combat.AttackKind:
	var entity := _entity_root()
	if entity == null:
		return Combat.AttackKind.MELEE

	var eq := _equipment(entity)
	if eq != null:
		return eq.active_slot

	return Combat.AttackKind.MELEE

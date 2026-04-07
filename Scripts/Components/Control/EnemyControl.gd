extends ControlSource
class_name EnemyControl

var _move: Vector2 = Vector2.ZERO

# Kind-based request state
var _attack_kind: int = Combat.AttackKind.NONE
var _attack_dir: Vector2 = Vector2.ZERO

# Raw button semantics state
var _pressed_frame := false
var _released_frame := false
var _is_down := false

# Block state
var _block_intent: bool = false


func set_move_intent(v: Vector2) -> void:
	_move = v


# Call from AI when you want to initiate an attack (one-shot or hold start).
func press_attack(dir: Vector2, kind: int) -> void:
	_attack_dir = dir
	_attack_kind = kind

	_pressed_frame = true
	_released_frame = false
	_is_down = true


# Optional: call from AI when you want HOLD_RELEASE style release.
func release_attack() -> void:
	_released_frame = true
	_pressed_frame = false
	_is_down = false


func set_block_intent(value: bool) -> void:
	_block_intent = value


func move_intent() -> Vector2:
	return _move


# --- Raw button semantics ---
func attack_pressed() -> bool:
	# one-shot true for the frame after AI press_attack()
	var v := _pressed_frame
	_pressed_frame = false
	return v

func attack_released() -> bool:
	var v := _released_frame
	_released_frame = false
	return v

func attack_is_down() -> bool:
	return _is_down


# --- Kind-based semantics ---
func attack_kind_peek() -> int:
	return _attack_kind if _is_down else Combat.AttackKind.NONE

func attack_kind_pressed() -> int:
	# one-shot: consume the press
	if attack_pressed():
		return _attack_kind
	return Combat.AttackKind.NONE


func aim_dir(fallback: Vector2) -> Vector2:
	return fallback if _attack_dir == Vector2.ZERO else _attack_dir


func wants_block() -> bool:
	return _block_intent

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

# Ensures press survives across Idle → Attack state transition
var _press_consumed_count: int = 0
const PRESS_CONSUME_LIMIT: int = 3 

# Auto-release: how many physics frames to hold the press before releasing
var _hold_frames_remaining: int = 0
const HOLD_DURATION_FRAMES: int = 4  # Hold for 4 frames then auto-release

# Block state
var _block_intent: bool = false


func _physics_process(_delta: float) -> void:
	if _is_down and _hold_frames_remaining > 0:
		_hold_frames_remaining -= 1
		if _hold_frames_remaining <= 0:
			release_attack()


func set_move_intent(v: Vector2) -> void:
	_move = v


func press_attack(dir: Vector2, kind: int) -> void:
	_attack_dir = dir
	_attack_kind = kind
	_pressed_frame = true
	_press_consumed_count = 0
	_released_frame = false
	_is_down = true
	_hold_frames_remaining = HOLD_DURATION_FRAMES


func release_attack() -> void:
	_released_frame = true
	_pressed_frame = false
	_is_down = false
	_attack_kind = Combat.AttackKind.NONE
	_hold_frames_remaining = 0


func set_block_intent(value: bool) -> void:
	_block_intent = value


func move_intent() -> Vector2:
	return _move


# --- Raw button semantics ---
func attack_pressed() -> bool:
	if _pressed_frame:
		_press_consumed_count += 1
		if _press_consumed_count >= PRESS_CONSUME_LIMIT:
			_pressed_frame = false
		return true
	return false

func attack_released() -> bool:
	var v := _released_frame
	_released_frame = false
	return v

func attack_is_down() -> bool:
	return _is_down


# --- Kind-based semantics ---
func attack_kind_peek() -> int:
	# FIX: also check _pressed_frame so peek works even if _is_down expired before Attack.enter runs
	return _attack_kind if (_is_down or _pressed_frame) else Combat.AttackKind.NONE

func attack_kind_pressed() -> int:
	if attack_pressed():
		return _attack_kind
	return Combat.AttackKind.NONE

func attack_kind_held() -> int:
	return _attack_kind if _is_down else Combat.AttackKind.NONE

func attack_kind_released() -> int:
	if attack_released():
		return _attack_kind
	return Combat.AttackKind.NONE


func aim_dir(fallback: Vector2) -> Vector2:
	return fallback if _attack_dir == Vector2.ZERO else _attack_dir


func wants_block() -> bool:
	return _block_intent

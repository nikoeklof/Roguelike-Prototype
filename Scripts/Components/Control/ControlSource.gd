extends Node
class_name ControlSource

# Base ControlSource contract:
# - Movement intent is an analog vector (normalized if needed).
# - Attack input supports both:
#     A) Kind-based "request attack" (what your FSM uses today)
#     B) Raw button semantics (pressed/released/down) for HOLD→RELEASE future
#
# NOTE: Defaults return "no input", so AI can implement only what it needs.

func move_intent() -> Vector2:
	return Vector2.ZERO


# --- Raw button semantics (future-proof) ---

func attack_pressed() -> bool:
	# Default maps to "kind pressed"
	return attack_kind_pressed() != Combat.AttackKind.NONE

func attack_released() -> bool:
	return false

func attack_is_down() -> bool:
	# Default maps to "kind peek"
	return attack_kind_peek() != Combat.AttackKind.NONE


# Aim / direction helper
func aim_dir(fallback: Vector2) -> Vector2:
	return fallback

# Back-compat with existing call sites
func attack_dir(fallback: Vector2) -> Vector2:
	return aim_dir(fallback)


# --- Kind-based semantics (what you use now) ---
# Must match Combat.AttackKind values

# One-shot: returns Combat.AttackKind
func attack_kind_pressed() -> int:
	return Combat.AttackKind.NONE

# Held: returns Combat.AttackKind
func attack_kind_peek() -> int:
	return Combat.AttackKind.NONE

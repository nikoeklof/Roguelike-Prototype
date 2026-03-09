extends Node
class_name ControlSource

func move_intent() -> Vector2:
	return Vector2.ZERO


func attack_pressed() -> bool:
	return false


func attack_released() -> bool:
	return false


func attack_is_down() -> bool:
	return false


func attack_kind_peek() -> Combat.AttackKind:
	return Combat.AttackKind.NONE


func attack_kind_pressed() -> Combat.AttackKind:
	return Combat.AttackKind.NONE


func attack_kind_held() -> Combat.AttackKind:
	return Combat.AttackKind.NONE


func attack_kind_released() -> Combat.AttackKind:
	return Combat.AttackKind.NONE


func aim_dir(fallback: Vector2) -> Vector2:
	return fallback


func wants_block() -> bool:
	return false


func active_weapon_fires_while_held() -> bool:
	return true


func weapon_fires_while_held_for_kind(_kind: Combat.AttackKind) -> bool:
	return true

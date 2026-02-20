extends Node2D
class_name Weapon

signal attack_finished

@export var cooldown_sec: float = 0.0
@export var enabled: bool = true

# Movement policy for this weapon's attacks.
@export var allow_move_during_attack: bool = false

# ✅ NEW: which equipment slot this weapon belongs to (MELEE or RANGED)
@export var pickup_slot_kind: Equipment.SlotKind = Equipment.SlotKind.MELEE

# ✅ NEW: optional icon override for pickup visuals
@export var pickup_icon: Texture2D

var _cd_until := 0.0

func can_attack() -> bool:
	if not enabled:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	return now >= _cd_until

func _commit_cooldown() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_cd_until = now + max(cooldown_sec, 0.0)

func get_pickup_slot_kind() -> int:
	return int(pickup_slot_kind)

func get_pickup_icon() -> Texture2D:
	return pickup_icon

# Override in subclasses. Return true if attack started.
func try_attack(_dir: Vector2, _owner_entity: Node) -> bool:
	return false

func stop() -> void:
	pass

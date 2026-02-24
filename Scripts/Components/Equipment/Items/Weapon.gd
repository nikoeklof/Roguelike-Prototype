extends Node2D
class_name Weapon

signal attack_finished

@export var enabled: bool = true
@export var allow_move_during_attack: bool = false

# Which Equipment slot this item belongs to.
@export var pickup_slot_kind: Equipment.SlotKind = Equipment.SlotKind.MELEE

# Optional icon override for pickup visuals.
@export var pickup_icon: Texture2D

# Optional: if you want a hard override for cooldown independent of stats.
# Leave at 0 to use computed stats from ItemInstance/ItemDef.
@export_range(0.0, 10.0, 0.01) var cooldown_override_sec: float = 0.0

var _cd_until := 0.0


func can_attack() -> bool:
	if not enabled:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	return now >= _cd_until


func commit_cooldown(computed_cooldown_sec: float) -> void:
	var cd := computed_cooldown_sec
	if cooldown_override_sec > 0.0:
		cd = cooldown_override_sec

	var now := Time.get_ticks_msec() / 1000.0
	_cd_until = now + max(cd, 0.0)


func get_pickup_slot_kind() -> int:
	return int(pickup_slot_kind)


func get_pickup_icon() -> Texture2D:
	return pickup_icon


# Override in subclasses if they still support a legacy execution path.
func try_attack(_dir: Vector2, _owner_entity: Node) -> bool:
	return false


func stop() -> void:
	pass


# ------------------------------------------------------------
# ItemInstance transport interface (default no-op)
# ------------------------------------------------------------
func get_item_instance() -> ItemInstance:
	return null


func set_item_instance(_inst: ItemInstance) -> void:
	pass

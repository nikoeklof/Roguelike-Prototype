extends Node
class_name Shield

@export var pickup_slot_kind: Equipment.SlotKind = Equipment.SlotKind.SHIELD
@export var pickup_icon: Texture2D

func get_pickup_slot_kind() -> int:
	return int(pickup_slot_kind)

func get_pickup_icon() -> Texture2D:
	return pickup_icon

func on_equipped(_owner_entity: Node) -> void:
	pass

func on_unequipped(_owner_entity: Node) -> void:
	pass

extends Node
class_name ItemNode

var _inst: ItemInstance = null


func set_item_instance(inst: ItemInstance) -> void:
	_inst = inst


func get_item_instance() -> ItemInstance:
	return _inst


# Helps EquipmentSwapPickup infer slot without any inspector overrides.
func get_pickup_slot_kind() -> int:
	if _inst == null or _inst.def == null:
		return 0
	return int(_inst.def.category)

extends EquipmentSlot
class_name ShieldSlot

func _ready() -> void:
	slot_kind = Equipment.SlotKind.SHIELD
	super._ready()

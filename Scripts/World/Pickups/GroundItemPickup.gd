extends EquipmentSwapPickup
class_name GroundItemPickup

@export var slot_kind: Equipment.SlotKind = Equipment.SlotKind.MELEE

func _ready() -> void:
	# Force this pickup to use the explicit slot kind from the inspector.
	slot_override_enabled = true
	slot_override = slot_kind

	# Base handles: group, monitorable, instancing item_scene, visual inheritance.
	super._ready()

extends Node
class_name EquipmentSlot

signal changed(new_item: Node, old_item: Node)

# Which slot kind is this?
@export var slot_kind: Equipment.SlotKind = Equipment.SlotKind.MELEE

@export var allow_multiple: bool = false

# Optional default item to spawn at runtime if slot is empty.
@export var initial_item_scene: PackedScene


func _ready() -> void:
	spawn_initial_if_empty()


func spawn_initial_if_empty() -> void:
	if get_item() != null:
		return
	if initial_item_scene == null:
		return

	var inst: Node = initial_item_scene.instantiate()
	if not Equipment.is_item_valid_for_slot(inst, int(slot_kind)):
		push_warning("EquipmentSlot(%s): initial_item_scene '%s' is not valid for this slot." %
			[Equipment.slot_kind_name(int(slot_kind)), str(initial_item_scene.resource_path)])
		inst.queue_free()
		return

	set_item(inst, true)


func get_item() -> Node:
	if get_child_count() == 0:
		return null
	return get_child(0) as Node


func take_item() -> Node:
	var owner_entity: Node = _owner_entity()
	var old: Node = get_item()
	if old == null:
		return null

	if old.has_method(&"on_unequipped"):
		old.call(&"on_unequipped", owner_entity)

	remove_child(old)
	changed.emit(null, old)
	return old


# Equip new item. Returns old item (if free_old=false, caller can reuse it).
func set_item(item: Node, free_old: bool = true) -> Node:
	var owner_entity: Node = _owner_entity()
	var old: Node = get_item()

	if item != null and not Equipment.is_item_valid_for_slot(item, int(slot_kind)):
		push_warning("EquipmentSlot(%s): tried to equip invalid item '%s'." %
			[Equipment.slot_kind_name(int(slot_kind)), item.name])
		return null

	# Unequip old
	if old != null and not allow_multiple:
		if old.has_method(&"on_unequipped"):
			old.call(&"on_unequipped", owner_entity)

		remove_child(old)
		if free_old:
			old.queue_free()

	# Equip new
	if item != null:
		if item.get_parent() != null:
			item.get_parent().remove_child(item)
		add_child(item)
		if item.has_method(&"on_equipped"):
			item.call(&"on_equipped", owner_entity)

	changed.emit(get_item(), old)
	return old


func clear(free_old: bool = true) -> void:
	set_item(null, free_old)


func _owner_entity() -> Node:
	# Slot -> Equipment -> Entity
	var equipment := get_parent()
	if equipment == null:
		return null
	return equipment.get_parent()

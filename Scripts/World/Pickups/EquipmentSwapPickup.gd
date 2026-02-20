extends Area2D
class_name EquipmentSwapPickup

@export var item_scene: PackedScene
@export var slot_override_enabled: bool = false
@export var slot_override: Equipment.SlotKind = Equipment.SlotKind.MELEE
@export_node_path("Sprite2D") var pickup_sprite_path: NodePath
@export var hide_item_node_in_pickup: bool = true

# Safety: block swaps while attacking (if Combat provides is_attacking or active executor)
@export var block_while_attacking: bool = true

var _item: Node = null
var _sprite: Sprite2D = null


func _ready() -> void:
	monitoring = true
	monitorable = false
	add_to_group("interactable")

	_sprite = get_node_or_null(pickup_sprite_path) as Sprite2D

	if item_scene != null and _item == null:
		set_item(item_scene.instantiate())


func set_item(item: Node) -> void:
	if _item != null and is_instance_valid(_item):
		if _item.get_parent() == self:
			remove_child(_item)

	_item = item

	if _item != null:
		if _item.get_parent() != null:
			_item.get_parent().remove_child(_item)
		add_child(_item)

		if hide_item_node_in_pickup and _item is CanvasItem:
			(_item as CanvasItem).visible = false

	_update_pickup_visual()


func can_interact(interactor: Node) -> bool:
	if _item == null or not is_instance_valid(_item):
		return false
	if not block_while_attacking:
		return true

	var combat := _resolve_combat(interactor)
	if combat == null:
		return true

	if combat.has_method(&"is_attacking"):
		var res: Variant = combat.call(&"is_attacking")
		if res is bool:
			return not (res as bool)

	# Fallback: if combat exposes an active executor node
	if " _active_executor" in combat:
		# can't reliably access private; ignore
		pass

	return true


func interact(interactor: Node) -> void:
	if _item == null or not is_instance_valid(_item):
		return

	var equipment: Equipment = _resolve_equipment(interactor)
	if equipment == null:
		return

	var slot_kind: int = _infer_slot_kind(_item)
	if slot_override_enabled:
		slot_kind = int(slot_override)

	var picked: Node = _item
	_item = null

	# Swap attempt
	var old_item: Node = equipment.swap_item_in_slot(slot_kind, picked)

	# If swap failed, restore the pickup item and bail
	if old_item == null and (equipment.get_node_or_null(equipment._slot_path_from_kind(slot_kind)) != null):
		# swap_item_in_slot returns null both on failure and when slot was empty.
		# We detect failure by checking whether picked got parented into the slot.
		# If picked is still parentless, it failed.
		if picked.get_parent() == null:
			set_item(picked)
			return

	# If slot was empty, pickup consumed.
	if old_item == null:
		queue_free()
		return

	# Pickup becomes the dropped item.
	set_item(old_item)


func _resolve_equipment(entity: Node) -> Equipment:
	if entity is Entity:
		return (entity as Entity).find_component(&"Equipment") as Equipment
	return entity.get_node_or_null("Equipment") as Equipment


func _resolve_combat(entity: Node) -> Node:
	if entity is Entity:
		return (entity as Entity).find_component(&"Combat")
	return entity.get_node_or_null("Combat")


func _infer_slot_kind(item: Node) -> int:
	if item.has_method(&"get_pickup_slot_kind"):
		var res: Variant = item.call(&"get_pickup_slot_kind")
		if res is int:
			return int(res)
	return Equipment.item_slot_kind(item)


func _update_pickup_visual() -> void:
	if _sprite == null:
		return

	var tex: Texture2D = null

	if _item != null and is_instance_valid(_item) and _item.has_method(&"get_pickup_icon"):
		var res: Variant = _item.call(&"get_pickup_icon")
		if res is Texture2D:
			tex = res as Texture2D

	if tex == null and _item != null and is_instance_valid(_item):
		var s: Sprite2D = _find_first_sprite(_item)
		if s != null:
			tex = s.texture

	_sprite.texture = tex


func _find_first_sprite(root: Node) -> Sprite2D:
	if root is Sprite2D:
		return root as Sprite2D
	for c in root.get_children():
		var s: Sprite2D = _find_first_sprite(c)
		if s != null:
			return s
	return null

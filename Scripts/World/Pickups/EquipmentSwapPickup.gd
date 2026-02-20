extends Area2D
class_name EquipmentSwapPickup

@export var item_scene: PackedScene
@export var slot_override_enabled: bool = false
@export var slot_override: Equipment.SlotKind = Equipment.SlotKind.MELEE
@export var hide_item_node_in_pickup: bool = true
@export var block_while_attacking: bool = true

var _item: Node = null
var _sprite: Sprite2D = null


func _ready() -> void:
	monitoring = false
	monitorable = true
	add_to_group("interactable")

	print("[Pickup] READY:", name)

	_sprite = _find_first_sprite(self)

	if item_scene != null and _item == null:
		print("[Pickup] spawning item:", item_scene.resource_path)
		set_item(item_scene.instantiate())


func set_item(item: Node) -> void:
	print("[Pickup] set_item ->", item)

	if _item != null and is_instance_valid(_item):
		if _item.get_parent() == self:
			remove_child(_item)

	_item = item

	if _item != null:
		if _item.get_parent() != null:
			_item.get_parent().remove_child(_item)

		add_child(_item)

		if hide_item_node_in_pickup:
			_hide_visuals_recursive(_item)

	_update_pickup_visual()


func can_interact(interactor: Node) -> bool:
	print("[Pickup] can_interact by:", interactor)

	if _item == null:
		print("[Pickup] FAIL: no item")
		return false

	if not block_while_attacking:
		return true

	var combat := _resolve_combat(interactor)
	print("[Pickup] combat:", combat)

	if combat and combat.has_method("is_attacking"):
		var attacking: bool = bool(combat.call("is_attacking"))
		print("[Pickup] attacking?", attacking)
		return not attacking

	return true


func interact(interactor: Node) -> void:
	print("\n========== INTERACT START ==========")
	print("[Pickup] interact from:", interactor)
	print("[Pickup] item:", _item)

	if not can_interact(interactor):
		print("[Pickup] blocked by can_interact")
		return

	var equipment: Equipment = _resolve_equipment(interactor)
	print("[Pickup] equipment:", equipment)

	if equipment == null:
		print("[Pickup] FAIL: equipment not found")
		return

	var slot_kind: int = _infer_slot_kind(_item)
	if slot_override_enabled:
		slot_kind = int(slot_override)

	print("[Pickup] inferred slot_kind:", _infer_slot_kind(_item))
	print("[Pickup] slot_kind:", slot_kind)

	var picked: Node = _item
	_item = null

	print("[Pickup] attempting swap...")
	var old_item: Node = equipment.swap_item_in_slot(slot_kind, picked)

	print("[Pickup] swap returned old_item:", old_item)
	print("[Pickup] picked parent after swap:", picked.get_parent())

	if picked.get_parent() == null:
		print("[Pickup] swap rejected -> restoring")
		set_item(picked)
		return

	if old_item == null:
		print("[Pickup] slot empty -> pickup consumed")
		queue_free()
		return

	print("[Pickup] swap success -> dropping old item")
	set_item(old_item)
	print("========== INTERACT END ==========\n")


func _resolve_equipment(entity: Node) -> Equipment:
	# If your interactor passes the Entity root, this succeeds
	if entity is Entity:
		var eq := (entity as Entity).find_component(&"Equipment") as Equipment
		if eq != null:
			return eq

	# Otherwise, just search downward from whatever node we got
	return _find_equipment_recursive(entity)


func _find_equipment_recursive(root: Node) -> Equipment:
	if root is Equipment:
		return root as Equipment

	var direct := root.get_node_or_null("Equipment")
	if direct is Equipment:
		return direct as Equipment

	for c in root.get_children():
		var found := _find_equipment_recursive(c)
		if found != null:
			return found

	return null


func _resolve_combat(entity: Node) -> Node:
	if entity is Entity:
		return (entity as Entity).find_component(&"Combat")
	return entity.get_node_or_null("Combat")


func _infer_slot_kind(item: Node) -> int:
	if item and item.has_method("get_pickup_slot_kind"):
		return item.call("get_pickup_slot_kind")
	return Equipment.item_slot_kind(item)


func _update_pickup_visual() -> void:
	if _sprite == null:
		return

	var tex: Texture2D = null

	if _item and _item.has_method("get_pickup_icon"):
		tex = _item.call("get_pickup_icon")

	if tex == null and _item != null:
		var s := _find_first_sprite(_item)
		if s:
			tex = s.texture

	_sprite.texture = tex


func _find_first_sprite(root: Node) -> Sprite2D:
	if root is Sprite2D:
		return root
	for c in root.get_children():
		var s := _find_first_sprite(c)
		if s:
			return s
	return null


func _hide_visuals_recursive(node: Node) -> void:
	if node is CanvasItem:
		node.visible = false
	for c in node.get_children():
		_hide_visuals_recursive(c)

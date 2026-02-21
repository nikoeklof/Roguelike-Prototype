extends Area2D
class_name EquipmentSwapPickup

@export var item_scene: PackedScene
@export var slot_override_enabled: bool = false
@export var slot_override: Equipment.SlotKind = Equipment.SlotKind.MELEE
@export var hide_item_node_in_pickup: bool = true
@export var block_while_attacking: bool = true

# --- throw animation tuning ---
@export var throw_enabled: bool = true
@export var throw_duration: float = 0.18
@export var throw_offset_radius: float = 22.0
@export var throw_scale_pop: float = 1.12

var _item: Node = null
var _sprite: Sprite2D = null
var _is_animating_throw: bool = false


func _ready() -> void:
	monitoring = false
	monitorable = true
	add_to_group("interactable")

	_sprite = _find_first_sprite(self)

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

		if hide_item_node_in_pickup:
			_hide_visuals_recursive(_item)

	_update_pickup_visual()


func can_interact(interactor: Node) -> bool:
	if _is_animating_throw:
		return false

	if _item == null or not is_instance_valid(_item):
		return false

	if not block_while_attacking:
		return true

	var combat := _resolve_combat(interactor)
	if combat and combat.has_method("is_attacking"):
		return not bool(combat.call("is_attacking"))

	return true


func interact(interactor: Node) -> void:
	if not can_interact(interactor):
		return

	if _item == null or not is_instance_valid(_item):
		return

	var equipment: Equipment = _resolve_equipment(interactor)
	if equipment == null:
		return

	var origin_pos: Vector2 = global_position

	var slot_kind: int = _infer_slot_kind(_item)
	if slot_override_enabled:
		slot_kind = int(slot_override)

	var picked: Node = _item
	_item = null

	var old_item: Node = equipment.swap_item_in_slot(slot_kind, picked)

	# Swap rejected: item not parented anywhere -> restore
	if picked.get_parent() == null:
		set_item(picked)
		return

	# Slot empty: pickup consumed
	if old_item == null:
		queue_free()
		return

	# Pickup becomes dropped item
	set_item(old_item)

	# Animate the dropped pickup flying out from the character back to the pickup origin
	if throw_enabled:
		_play_throw_from_to(interactor, origin_pos)
	else:
		global_position = origin_pos


func _play_throw_from_to(interactor: Node, target_origin: Vector2) -> void:
	_is_animating_throw = true
	monitorable = false # prevent re-interacting mid-flight

	# Start at the character position (best effort)
	var start_pos := target_origin
	if interactor is Node2D:
		start_pos = (interactor as Node2D).global_position
	global_position = start_pos

	# Land near the original pickup spot with a small random offset
	var offset := Vector2(
		randf_range(-throw_offset_radius, throw_offset_radius),
		randf_range(-throw_offset_radius, throw_offset_radius)
	)
	var end_pos := target_origin + offset

	# --- IMPORTANT: run tweens in PHYSICS time so capture FPS doesn't affect them ---
	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.set_trans(Tween.TRANS_QUAD)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(self, "global_position", end_pos, throw_duration)

	if _sprite != null:
		_sprite.scale = Vector2.ONE
		var t2 := create_tween()
		t2.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		t2.tween_property(_sprite, "scale", Vector2.ONE * throw_scale_pop, throw_duration * 0.5)
		t2.tween_property(_sprite, "scale", Vector2.ONE, throw_duration * 0.5)

	t.finished.connect(func():
		monitorable = true
		_is_animating_throw = false
	)


func _resolve_equipment(entity: Node) -> Equipment:
	# Robust: find Equipment anywhere under the node we received
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
		var res: Variant = _item.call("get_pickup_icon")
		if res is Texture2D:
			tex = res as Texture2D

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

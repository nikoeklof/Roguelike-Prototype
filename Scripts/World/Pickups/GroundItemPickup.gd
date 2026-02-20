extends Area2D
class_name GroundItemPickup

# Which slot this pickup swaps with
@export var slot_kind: Equipment.SlotKind = Equipment.SlotKind.MELEE

# Optional: auto-spawn an item scene for the pickup
@export var item_scene: PackedScene

# Optional: visual child path (Sprite2D/Node2D) you can rotate or animate later
@export_node_path("Node2D") var visual_path: NodePath

# How close you must be (handled by Area2D collision)
var _in_range_entity: Node = null
var _item: Node = null


func _ready() -> void:
	monitoring = true
	monitorable = false

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if item_scene != null and _item == null:
		var inst := item_scene.instantiate()
		set_item(inst)


func set_item(item: Node) -> void:
	# Replace contained item (no free; caller decides).
	if _item != null and is_instance_valid(_item):
		remove_child(_item)

	_item = item

	if _item != null:
		if _item.get_parent() != null:
			_item.get_parent().remove_child(_item)
		add_child(_item)

	# Hide the actual gameplay node if it's Node2D so it doesn't appear at origin oddly.
	# You can swap this later for proper pickup sprites.
	if _item is CanvasItem:
		(_item as CanvasItem).visible = false


func get_item() -> Node:
	return _item


func _unhandled_input(event: InputEvent) -> void:
	if _in_range_entity == null:
		return
	if _item == null or not is_instance_valid(_item):
		return

	if event.is_action_pressed("interact"):
		_try_swap(_in_range_entity)


func _try_swap(entity: Node) -> void:
	var equipment: Equipment = null
	if entity is Entity:
		equipment = (entity as Entity).find_component(&"Equipment") as Equipment
	else:
		equipment = entity.get_node_or_null("Equipment") as Equipment

	if equipment == null:
		return

	var world_parent: Node = get_parent()
	var drop_pos: Vector2 = global_position

	# Swap: pick up my item, drop theirs.
	var picked_item := _item
	_item = null

	equipment.swap_slot_with_item(slot_kind, picked_item, world_parent, drop_pos)

	# The item we had is now equipped; this pickup should now contain the dropped one.
	# swap_slot_with_item dropped old item as a NEW pickup instance, so this pickup is consumed.
	queue_free()


func _on_body_entered(body: Node) -> void:
	# Only allow player for now (simple). If you want AI later, relax this check.
	if body.name == "Player" or body.is_in_group("player"):
		_in_range_entity = body

func _on_body_exited(body: Node) -> void:
	if body == _in_range_entity:
		_in_range_entity = null

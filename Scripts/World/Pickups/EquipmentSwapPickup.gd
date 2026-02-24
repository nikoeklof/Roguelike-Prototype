extends Area2D
class_name EquipmentSwapPickup

@export var item_scene: PackedScene
@export var slot_override_enabled: bool = false
@export var slot_override: Equipment.SlotKind = Equipment.SlotKind.MELEE
@export var hide_item_node_in_pickup: bool = true
@export var block_while_attacking: bool = true

# --- deterministic item instance rolling (new system) ---
@export var deterministic_roll_enabled: bool = true
@export_range(0, 8, 1) var roll_attribute_count: int = 0
@export var roll_seed_salt: int = 0

# --- throw animation tuning ---
@export var throw_enabled: bool = true
@export var throw_duration: float = 0.18
@export var throw_offset_radius: float = 22.0
@export var throw_scale_pop: float = 1.12

# --- tooltip tuning ---
@export var tooltip_enabled: bool = true
@export var tooltip_local_offset: Vector2 = Vector2(-60.0, -64.0)
@export_range(120.0, 600.0, 10.0) var tooltip_width: float = 220.0

@export_range(8, 48, 1) var tooltip_font_size: int = 14
@export_range(8, 64, 1) var tooltip_title_font_size: int = 16 # (reserved for later formatter upgrade)
@export_range(0, 32, 1) var tooltip_padding: int = 8
@export var tooltip_use_background: bool = true

var _item: Node = null
var _sprite: Sprite2D = null
var _is_animating_throw: bool = false
var _did_initial_roll: bool = false

# UI state
var _in_pickup_radius: bool = false
var _tooltip_panel: PanelContainer = null
var _tooltip_text: RichTextLabel = null


func _ready() -> void:
	monitoring = false
	monitorable = true
	add_to_group("interactable")

	_sprite = _find_first_sprite(self)

	if tooltip_enabled:
		_build_tooltip()

	if item_scene != null and _item == null:
		set_item(item_scene.instantiate())
		_try_roll_initial_instance()
		_refresh_tooltip()


func get_item() -> Node:
	return _item


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
	_refresh_tooltip()


func _try_roll_initial_instance() -> void:
	# Only roll once per pickup node, and only for initial spawned item_scene instance.
	if _did_initial_roll:
		return
	_did_initial_roll = true

	if not deterministic_roll_enabled:
		return
	if _item == null or not is_instance_valid(_item):
		return

	ItemPickupRoller.apply_roll_if_possible(self, _item, roll_attribute_count, roll_seed_salt)
	_refresh_tooltip()


# ------------------------------------------------------------
# Interactor proximity callbacks (called by Interactor.gd)
# ------------------------------------------------------------
func on_interactor_entered(_interactor_owner: Node) -> void:
	_in_pickup_radius = true
	_refresh_tooltip()


func on_interactor_exited(_interactor_owner: Node) -> void:
	_in_pickup_radius = false
	_refresh_tooltip()


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

	# Pickup becomes dropped item (IMPORTANT: preserve its instance; do not reroll)
	set_item(old_item)

	# Animate the dropped pickup flying out from the character back to the pickup origin
	if throw_enabled:
		_play_throw_from_to(interactor, origin_pos)
	else:
		global_position = origin_pos


func _play_throw_from_to(interactor: Node, target_origin: Vector2) -> void:
	_is_animating_throw = true
	monitorable = false # prevent re-interacting mid-flight

	var start_pos := target_origin
	if interactor is Node2D:
		start_pos = (interactor as Node2D).global_position
	global_position = start_pos

	var offset := Vector2(
		randf_range(-throw_offset_radius, throw_offset_radius),
		randf_range(-throw_offset_radius, throw_offset_radius)
	)
	var end_pos := target_origin + offset

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


# ------------------------------------------------------------
# Tooltip UI
# ------------------------------------------------------------
func _build_tooltip() -> void:
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.name = "ItemTooltip"
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.position = tooltip_local_offset
	_tooltip_panel.custom_minimum_size = Vector2(tooltip_width, 0.0)

	# Background styling
	if not tooltip_use_background:
		var empty_style := StyleBoxEmpty.new()
		_tooltip_panel.add_theme_stylebox_override("panel", empty_style)
	else:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.75)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.content_margin_left = tooltip_padding
		style.content_margin_right = tooltip_padding
		style.content_margin_top = tooltip_padding
		style.content_margin_bottom = tooltip_padding
		_tooltip_panel.add_theme_stylebox_override("panel", style)

	_tooltip_text = RichTextLabel.new()
	_tooltip_text.name = "Text"
	_tooltip_text.fit_content = true
	_tooltip_text.bbcode_enabled = true
	_tooltip_text.scroll_active = false
	_tooltip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Font override
	var font := ThemeDB.fallback_font
	if font != null:
		_tooltip_text.add_theme_font_override("normal_font", font)
		_tooltip_text.add_theme_font_size_override("normal_font_size", tooltip_font_size)

	_tooltip_panel.add_child(_tooltip_text)
	add_child(_tooltip_panel)


func _refresh_tooltip() -> void:
	if not tooltip_enabled:
		return
	if _tooltip_panel == null or _tooltip_text == null:
		return

	if _item == null or not is_instance_valid(_item):
		_tooltip_panel.visible = false
		return

	_tooltip_panel.visible = true
	_tooltip_text.clear()

	if _in_pickup_radius:
		_tooltip_text.append_text(ItemTooltipFormatter.format_expanded(_item))
	else:
		_tooltip_text.append_text(ItemTooltipFormatter.format_compact(_item))


# ------------------------------------------------------------
# Existing helpers
# ------------------------------------------------------------
func _resolve_equipment(entity: Node) -> Equipment:
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

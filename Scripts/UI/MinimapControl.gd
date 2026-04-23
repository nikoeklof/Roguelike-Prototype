extends Control
class_name MinimapControl

@export var cell_size: int = 18
@export var padding: int = 12
@export var show_debug_overlay: bool = false

var _plan: FloorGenerator.FloorPlan = null
var _player_cell: Vector2i = Vector2i.ZERO
var _bounds: Rect2i = Rect2i(Vector2i.ZERO, Vector2i.ONE)


func set_floor_plan(plan: FloorGenerator.FloorPlan) -> void:
	_plan = plan
	_recompute()
	queue_redraw()


func set_player_cell(cell: Vector2i) -> void:
	_player_cell = cell
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_recompute()
		queue_redraw()


func _recompute() -> void:
	if _plan == null:
		return
	if _plan.coords.is_empty():
		return

	_bounds = _compute_bounds_from_coords(_plan.coords)

	# Ensure this control can show the whole layout if needed
	var w: int = _bounds.size.x * cell_size + padding * 2
	var h: int = _bounds.size.y * cell_size + padding * 2
	custom_minimum_size = Vector2(float(w), float(h))


func _draw() -> void:
	if show_debug_overlay:
		_draw_debug_overlay()

	if _plan == null:
		return
	if _plan.coords.is_empty():
		return

	var map_px: Vector2 = Vector2(
		float(_bounds.size.x * cell_size),
		float(_bounds.size.y * cell_size)
	)

	# Center map within available control size
	var available: Vector2 = size
	var origin: Vector2 = (available - map_px) * 0.5
	origin.x = max(origin.x, float(padding))
	origin.y = max(origin.y, float(padding))

	for coord: Vector2i in _plan.coords:
		if not _plan.rooms.has(coord):
			continue

		var room: FloorGenerator.RoomNode = _plan.rooms[coord] as FloorGenerator.RoomNode
		if room == null:
			continue

		if room.kind == &"XL_OCCUPIED":
			continue

		var local: Vector2i = coord - _bounds.position
		var pixel_pos: Vector2 = origin + Vector2(local) * float(cell_size)

		var cell_px: float = float(cell_size)
		var is_xl: bool = room.kind == &"XL"
		var rect_size: Vector2 = Vector2(cell_px * 2.0, cell_px * 2.0) if is_xl else Vector2(cell_px, cell_px)
		var rect: Rect2 = Rect2(pixel_pos, rect_size)

		_draw_room(rect, room)
		_draw_exits(rect, room.exits_mask)

	_draw_player(origin)


func _draw_room(rect: Rect2, room: FloorGenerator.RoomNode) -> void:
	var base_color: Color = Color(0.35, 0.35, 0.35)

	if room.kind == &"START":
		base_color = Color(0.2, 0.8, 0.2)
	elif room.kind == &"BOSS":
		base_color = Color(0.8, 0.2, 0.2)
	elif room.kind == &"XL":
		base_color = Color(0.6, 0.3, 0.8)

	draw_rect(rect, base_color, true)
	draw_rect(rect, Color(0, 0, 0), false, 2.0)


func _draw_exits(rect: Rect2, exits_mask: int) -> void:
	var center: Vector2 = rect.get_center()
	var stub: float = rect.size.x * 0.45

	if exits_mask & FloorGenerator.N != 0:
		draw_line(center, center + Vector2(0, -stub), Color.WHITE, 2.0)
	if exits_mask & FloorGenerator.E != 0:
		draw_line(center, center + Vector2(stub, 0), Color.WHITE, 2.0)
	if exits_mask & FloorGenerator.S != 0:
		draw_line(center, center + Vector2(0, stub), Color.WHITE, 2.0)
	if exits_mask & FloorGenerator.W != 0:
		draw_line(center, center + Vector2(-stub, 0), Color.WHITE, 2.0)


func _draw_player(origin: Vector2) -> void:
	if _plan == null:
		return
	if not _plan.rooms.has(_player_cell):
		return

	var local: Vector2i = _player_cell - _bounds.position
	var pixel_pos: Vector2 = origin + Vector2(local) * float(cell_size)
	var rect: Rect2 = Rect2(pixel_pos, Vector2(float(cell_size), float(cell_size)))

	draw_circle(rect.get_center(), float(cell_size) * 0.35, Color(1, 1, 0.2))


func _draw_debug_overlay() -> void:
	var coords_count: int = 0
	var seed_val: int = 0
	if _plan != null:
		coords_count = _plan.coords.size()
		seed_val = int(_plan.seed)

	var text: String = ""
	text += "Minimap debug\n"
	text += "plan: %s\n" % ("OK" if _plan != null else "NULL")
	text += "seed: %d\n" % seed_val
	text += "coords: %d\n" % coords_count
	text += "size: %s\n" % str(size)
	text += "custom_min: %s\n" % str(custom_minimum_size)
	text += "bounds: pos=%s size=%s\n" % [str(_bounds.position), str(_bounds.size)]

	draw_string(
		get_theme_default_font(),
		Vector2(6, 16),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color(1, 1, 1)
	)


func _compute_bounds_from_coords(coords: Array[Vector2i]) -> Rect2i:
	var min_x: int = 999999
	var min_y: int = 999999
	var max_x: int = -999999
	var max_y: int = -999999

	for c: Vector2i in coords:
		min_x = min(min_x, c.x)
		min_y = min(min_y, c.y)
		max_x = max(max_x, c.x)
		max_y = max(max_y, c.y)

	return Rect2i(
		Vector2i(min_x, min_y),
		Vector2i(max_x - min_x + 1, max_y - min_y + 1)
	)

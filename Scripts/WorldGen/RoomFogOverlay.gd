extends Node2D
class_name RoomFogOverlay

@export_range(8.0, 160.0, 4.0) var edge_width: float = 72.0
@export_range(0.0, 1.0, 0.05) var edge_opacity: float = 0.55
@export var fog_color: Color = Color(0.025, 0.035, 0.055, 1.0)

var room_rect: Rect2 = Rect2()


func _ready() -> void:
	z_index = 50
	z_as_relative = false
	set_notify_transform(true)


func set_room_rect(rect: Rect2) -> void:
	room_rect = rect
	queue_redraw()


func _draw() -> void:
	if room_rect.size == Vector2.ZERO:
		return

	var clear_color := Color(fog_color.r, fog_color.g, fog_color.b, 0.0)
	var left: float = room_rect.position.x
	var top: float = room_rect.position.y
	var right: float = room_rect.end.x
	var bottom: float = room_rect.end.y
	var width: float = minf(edge_width, minf(room_rect.size.x, room_rect.size.y) * 0.25)
	var edge_color := Color(fog_color.r, fog_color.g, fog_color.b, edge_opacity)

	_draw_gradient(
		PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, top + width), Vector2(left, top + width)]),
		PackedColorArray([edge_color, edge_color, clear_color, clear_color])
	)
	_draw_gradient(
		PackedVector2Array([Vector2(left, bottom - width), Vector2(right, bottom - width), Vector2(right, bottom), Vector2(left, bottom)]),
		PackedColorArray([clear_color, clear_color, edge_color, edge_color])
	)
	_draw_gradient(
		PackedVector2Array([Vector2(left, top), Vector2(left + width, top), Vector2(left + width, bottom), Vector2(left, bottom)]),
		PackedColorArray([edge_color, clear_color, clear_color, edge_color])
	)
	_draw_gradient(
		PackedVector2Array([Vector2(right - width, top), Vector2(right, top), Vector2(right, bottom), Vector2(right - width, bottom)]),
		PackedColorArray([clear_color, edge_color, edge_color, clear_color])
	)


func _draw_gradient(points: PackedVector2Array, colors: PackedColorArray) -> void:
	draw_polygon(points, colors)

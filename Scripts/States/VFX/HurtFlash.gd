@tool
extends Node
class_name HurtFlash

# Optional override. If unset/broken, we auto-find a CanvasItem under VisualRoot.
@export_node_path("CanvasItem") var render_path: NodePath
@export var flash_color: Color = Color(1, 1, 1, 1)
@export_range(0.0, 60.0, 0.1) var blink_speed: float = 18.0

var _sprite: CanvasItem
var _time := 0.0
var _duration := 0.0
var _playing := false


func _ready() -> void:
	_resolve()
	if Engine.is_editor_hint():
		update_configuration_warnings()


func _notification(what: int) -> void:
	if Engine.is_editor_hint() and (what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_READY):
		_resolve()
		update_configuration_warnings()


func _resolve() -> void:
	_sprite = null

	# 1) Explicit override (if set)
	if render_path != NodePath():
		_sprite = get_node_or_null(render_path) as CanvasItem
		if _sprite != null:
			return

	# 2) Common defaults on the entity
	var entity := get_parent()
	if entity == null:
		return

	_sprite = entity.get_node_or_null("VisualRoot/animations") as CanvasItem
	if _sprite == null:
		_sprite = entity.get_node_or_null("VisualRoot") as CanvasItem

	# 3) Final fallback: find any CanvasItem under the entity (cached)
	if _sprite == null:
		_sprite = EntityComponents.resolve_in_tree(entity, &"CanvasItem") as CanvasItem


func flash(duration_sec: float = 0.12) -> void:
	_resolve()
	if _sprite == null:
		return

	_duration = duration_sec
	_time = 0.0
	_playing = true

	# Lightweight flash via modulate (swap to shader later if you want)
	_sprite.modulate = flash_color


func _process(delta: float) -> void:
	if not _playing:
		return

	_time += delta
	if _time >= _duration:
		_playing = false
		if _sprite != null:
			_sprite.modulate = Color(1, 1, 1, 1)


func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if get_parent() == null:
		w.append("HurtFlash: Must be a child of the entity.")

	if render_path != NodePath() and get_node_or_null(render_path) == null:
		w.append("HurtFlash: render_path is set but doesn't resolve.")

	return w

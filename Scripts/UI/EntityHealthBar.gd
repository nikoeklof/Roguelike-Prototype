extends Node2D
class_name EntityHealthBar

## A small health bar that floats above an entity.
## Attach as a child of any Entity that has a Health component.
## Automatically hides when health is full, shows when damaged.

@export var bar_width: float = 24.0
@export var bar_height: float = 3.0
@export var y_offset: float = -30.0  ## How far above the entity origin
@export var bg_color: Color = Color(0.15, 0.15, 0.15, 0.8)
@export var fill_color: Color = Color(0.2, 0.85, 0.2, 1.0)
@export var damage_color: Color = Color(0.85, 0.2, 0.2, 1.0)
@export var low_hp_threshold: float = 0.3  ## Below this %, bar turns red
@export var border_color: Color = Color(0.0, 0.0, 0.0, 0.9)
@export var border_width: float = 1.0

## If true, the bar hides when HP is full
@export var hide_when_full: bool = true
## If true, the bar always faces the camera (no parent rotation)
@export var billboard: bool = true

var _health: Health = null
var _ratio: float = 1.0
var _visible_timer: float = 0.0

## How long the bar stays visible after taking damage (seconds)
const SHOW_DURATION: float = 4.0
const FADE_DURATION: float = 0.5


func _ready() -> void:
	# Position above entity
	position = Vector2(0, y_offset)

	# Find the Health component on the parent entity
	var entity: Node = get_parent()
	if entity == null:
		return

	_health = entity.get_node_or_null("Health") as Health
	if _health == null:
		# Try find_component for Entity class
		if entity.has_method("find_component"):
			_health = entity.call("find_component", &"Health") as Health

	if _health == null:
		print("[EntityHealthBar] WARNING: No Health component found on %s" % entity.name)
		visible = false
		return

	# Connect signals
	_health.hp_changed.connect(_on_hp_changed)
	_health.damaged.connect(_on_damaged)

	# Initialize
	_ratio = _health.hp / _health.max_hp if _health.max_hp > 0.0 else 1.0

	if hide_when_full and _ratio >= 1.0:
		modulate.a = 0.0


func _process(delta: float) -> void:
	if billboard:
		# Counter-rotate to cancel parent's rotation (keeps bar horizontal)
		var parent_entity: Node2D = get_parent() as Node2D
		if parent_entity != null:
			global_rotation = 0.0

	# Fade logic
	if hide_when_full:
		if _ratio >= 1.0:
			_visible_timer -= delta
			if _visible_timer <= 0.0:
				modulate.a = maxf(modulate.a - delta / FADE_DURATION, 0.0)
		else:
			modulate.a = 1.0
			_visible_timer = SHOW_DURATION


func _draw() -> void:
	var half_w: float = bar_width * 0.5
	var rect_bg := Rect2(-half_w - border_width, -border_width, bar_width + border_width * 2.0, bar_height + border_width * 2.0)
	var rect_fill := Rect2(-half_w, 0.0, bar_width * _ratio, bar_height)
	var rect_empty := Rect2(-half_w, 0.0, bar_width, bar_height)

	# Border / background
	draw_rect(rect_bg, border_color)

	# Empty (dark bg)
	draw_rect(rect_empty, bg_color)

	# Fill
	var fill: Color = fill_color if _ratio > low_hp_threshold else damage_color
	draw_rect(rect_fill, fill)


func _on_hp_changed(hp: float, max_hp: float) -> void:
	if max_hp <= 0.0:
		_ratio = 0.0
	else:
		_ratio = clampf(hp / max_hp, 0.0, 1.0)
	queue_redraw()


func _on_damaged(_amount: float, _source: Node) -> void:
	_visible_timer = SHOW_DURATION
	modulate.a = 1.0

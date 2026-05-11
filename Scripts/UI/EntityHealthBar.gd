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

@export_group("Shield Bar")
@export var shield_fill_color: Color = Color(0.3, 0.6, 1.0, 1.0)
@export var shield_broken_color: Color = Color(0.35, 0.35, 0.45, 1.0)
@export var shield_bar_gap: float = 2.0  ## Gap between HP bar and shield bar

var _health: Health = null
var _ratio: float = 1.0
var _visible_timer: float = 0.0

var _entity: Node = null  ## Cached reference used by _init_shield_bar_state
var _active_shield: ActiveShield = null
var _shield_ratio: float = 1.0
var _shield_broken: bool = false
var _shield_bar_visible: bool = false
var _shield_visible_timer: float = 0.0

## How long the bar stays visible after taking damage (seconds)
const SHOW_DURATION: float = 4.0
const FADE_DURATION: float = 0.5


func _ready() -> void:
	z_as_relative = false
	z_index = 100000
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

	# ActiveShield is created dynamically by ShieldSlot via call_deferred, so it
	# doesn't exist yet during _ready(). Defer the entire shield bar setup until
	# after LoadoutAssigner has finished equipping items (which is also deferred).
	# Use find_child (recursive) to locate LoadoutAssigner regardless of nesting.
	_entity = entity
	var assigner: LoadoutAssigner = entity.find_child("LoadoutAssigner", true, false) as LoadoutAssigner
	if assigner != null:
		assigner.loadout_assigned.connect(_init_shield_bar_state, CONNECT_ONE_SHOT)
	else:
		call_deferred("_init_shield_bar_state")


func _process(delta: float) -> void:
	if billboard:
		# Counter-rotate to cancel parent's rotation (keeps bar horizontal)
		var parent_entity: Node2D = get_parent() as Node2D
		if parent_entity != null:
			global_rotation = 0.0

	# Health bar fade logic
	if hide_when_full:
		if _ratio >= 1.0:
			_visible_timer -= delta
			if _visible_timer <= 0.0:
				modulate.a = maxf(modulate.a - delta / FADE_DURATION, 0.0)
		else:
			modulate.a = 1.0
			_visible_timer = SHOW_DURATION

	# Shield bar visibility: hide when full only if hide_when_full is enabled
	if _shield_bar_visible and hide_when_full:
		if _shield_ratio >= 1.0 and not _shield_broken:
			_shield_visible_timer -= delta
			if _shield_visible_timer <= 0.0:
				_shield_bar_visible = false
				queue_redraw()


func _draw() -> void:
	var half_w: float = bar_width * 0.5

	# --- Health bar ---
	var rect_bg := Rect2(-half_w - border_width, -border_width, bar_width + border_width * 2.0, bar_height + border_width * 2.0)
	var rect_fill := Rect2(-half_w, 0.0, bar_width * _ratio, bar_height)
	var rect_empty := Rect2(-half_w, 0.0, bar_width, bar_height)

	draw_rect(rect_bg, border_color)
	draw_rect(rect_empty, bg_color)
	var fill: Color = fill_color if _ratio > low_hp_threshold else damage_color
	draw_rect(rect_fill, fill)

	# --- Shield bar (only when a shield with HP is equipped) ---
	if _shield_bar_visible:
		var sy: float = -(bar_height + shield_bar_gap + border_width)
		var shield_bg := Rect2(-half_w - border_width, sy - border_width, bar_width + border_width * 2.0, bar_height + border_width * 2.0)
		var shield_empty := Rect2(-half_w, sy, bar_width, bar_height)
		var shield_fill := Rect2(-half_w, sy, bar_width * _shield_ratio, bar_height)

		draw_rect(shield_bg, border_color)
		draw_rect(shield_empty, bg_color)
		var shield_color: Color = shield_broken_color if _shield_broken else shield_fill_color
		draw_rect(shield_fill, shield_color)


func _init_shield_bar_state() -> void:
	# ActiveShield is created dynamically by ShieldSlot, so look it up now.
	if _entity == null:
		return
	if _active_shield == null:
		var found: ActiveShield = null
		if _entity.has_method("find_component"):
			found = _entity.call("find_component", &"ActiveShield") as ActiveShield
		if found == null:
			found = _entity.get_node_or_null("ActiveShield") as ActiveShield
		if found == null:
			return  # Entity has no active shield — nothing to show
		_active_shield = found
		_active_shield.shield_hp_changed.connect(_on_shield_hp_changed)
		_active_shield.shield_broken.connect(_on_shield_broken)
		_active_shield.shield_restored.connect(_on_shield_restored)

	var cur_max: float = _active_shield.get_shield_max_hp()
	if cur_max > 0.0:
		_on_shield_hp_changed(_active_shield.get_shield_hp(), cur_max)
		if _active_shield.is_broken():
			_on_shield_broken()


func _on_hp_changed(hp: float, max_hp: float) -> void:
	if max_hp <= 0.0:
		_ratio = 0.0
	else:
		_ratio = clampf(hp / max_hp, 0.0, 1.0)
	queue_redraw()


func _on_damaged(_amount: float, _source: Node) -> void:
	_visible_timer = SHOW_DURATION
	modulate.a = 1.0


func _on_shield_hp_changed(current: float, max_hp: float) -> void:
	if max_hp <= 0.0:
		_shield_bar_visible = false
		queue_redraw()
		return
	_shield_ratio = clampf(current / max_hp, 0.0, 1.0)
	_shield_broken = false
	_shield_bar_visible = true
	_shield_visible_timer = SHOW_DURATION
	queue_redraw()


func _on_shield_broken() -> void:
	_shield_broken = true
	_shield_bar_visible = true
	_shield_visible_timer = SHOW_DURATION
	queue_redraw()


func _on_shield_restored() -> void:
	_shield_broken = false
	_shield_ratio = 1.0
	_shield_visible_timer = SHOW_DURATION
	queue_redraw()

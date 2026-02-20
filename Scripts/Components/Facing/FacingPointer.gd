extends Node
class_name FacingPointer

signal facing_changed(new_name: String, new_vector: Vector2)

@export_node_path("CharacterBody2D") var velocity_source: NodePath
@export var speed_deadzone := 5.0
@export var default_facing := Vector2.DOWN
@export var debug_print_facing := false

var facing_vector: Vector2 = Vector2.DOWN
var facing_name: String = "down"

var _manual_override: bool = false


func _ready() -> void:
	_apply_facing(default_facing.normalized())


func _physics_process(_delta: float) -> void:
	# During manual override we freeze facing
	if _manual_override:
		return

	var body := _get_velocity_owner()
	if body == null:
		return

	var v: Vector2 = body.velocity
	if v.length() <= speed_deadzone:
		return

	_apply_facing(v.normalized())


# --- Public API ---

func get_facing_name() -> String:
	return facing_name

func get_facing_vector() -> Vector2:
	return facing_vector


func set_manual_facing(dir: Vector2) -> void:
	if dir.length() < 0.001:
		return
	_manual_override = true
	_apply_facing(dir.normalized()) # immediate (prevents 1-frame mismatch)


func clear_manual_facing() -> void:
	_manual_override = false


func has_manual_override() -> bool:
	return _manual_override


# --- Internals ---

func _apply_facing(vec: Vector2) -> void:
	var new_name := dir8_name(vec)
	if new_name == facing_name:
		return

	facing_vector = vec
	facing_name = new_name

	if debug_print_facing:
		print("Facing:", facing_name, facing_vector)

	facing_changed.emit(facing_name, facing_vector)


func _get_velocity_owner() -> CharacterBody2D:
	if velocity_source != NodePath(""):
		var n := get_node_or_null(velocity_source)
		if n is CharacterBody2D:
			return n
		return null

	var p := get_parent()
	while p != null:
		if p is CharacterBody2D:
			return p
		p = p.get_parent()

	return null


func dir8_name(dir: Vector2) -> String:
	if dir == Vector2.ZERO:
		dir = facing_vector

	var a := dir.angle()
	var idx := int(floor((a + PI / 8.0) / (PI / 4.0))) & 7

	match idx:
		0: return "right"
		1: return "down_right"
		2: return "down"
		3: return "down_left"
		4: return "left"
		5: return "up_left"
		6: return "up"
		7: return "up_right"
		_: return "down"

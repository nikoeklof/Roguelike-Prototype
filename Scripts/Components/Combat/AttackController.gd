@tool
extends Node
class_name AttackController

signal finished

# Optional overrides. Defaults assume a common entity layout.
@export_node_path("Node2D") var visual_root_path: NodePath = ^"../VisualRoot"
@export_node_path("Node2D") var pivot_path: NodePath = ^"../FacingPointer/AimRay"
@export_node_path("Node2D") var socket_path: NodePath = ^"../VisualRoot/WeaponSocket"

@export var slash_anim_name := "Slash"
@export_range(0.0, 200.0, 0.5) var slash_reach := 20.0
@export_range(0, 500, 1) var hitbox_forward := 34

# If we can't find an AnimationPlayer / animation, we still must finish.
@export_range(0.01, 2.0, 0.01) var fallback_finish_time := 0.20

var _visual_root: Node2D
var _pivot: Node2D
var _socket: Node2D

var _anim: AnimationPlayer
var _finish_timer: Timer
var _attack_in_progress := false


func _ready() -> void:
	_resolve_nodes()
	if Engine.is_editor_hint():
		update_configuration_warnings()


func _notification(what: int) -> void:
	if Engine.is_editor_hint() and (what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_READY):
		_resolve_nodes()
		update_configuration_warnings()


func _resolve_nodes() -> void:
	_visual_root = get_node_or_null(visual_root_path) as Node2D
	_pivot = get_node_or_null(pivot_path) as Node2D
	_socket = get_node_or_null(socket_path) as Node2D

	# QoL fallbacks by common names
	var entity := get_parent()
	if _visual_root == null and entity != null:
		_visual_root = entity.get_node_or_null("VisualRoot") as Node2D
	if _pivot == null and entity != null:
		_pivot = entity.get_node_or_null("FacingPointer/AimRay") as Node2D
		if _pivot == null:
			_pivot = entity.get_node_or_null("FacingPointer/AimRay") as Node2D
	if _socket == null and entity != null:
		_socket = entity.get_node_or_null("VisualRoot/WeaponSocket") as Node2D
		if _socket == null:
			_socket = entity.get_node_or_null("WeaponSocket") as Node2D

	# Resolve AnimationPlayer (non-fatal if missing)
	_anim = null
	if _visual_root != null and is_instance_valid(_visual_root):
		# Common pattern: VisualRoot/animations (AnimationPlayer)
		var a := _visual_root.get_node_or_null("animations") as AnimationPlayer
		if a == null:
			# Or direct child named AnimationPlayer
			a = _visual_root.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if a == null:
			# Or search one level down
			for c in _visual_root.get_children():
				if c is AnimationPlayer:
					a = c
					break
		_anim = a


func get_pivot() -> Node2D:
	if _pivot == null or not is_instance_valid(_pivot):
		_resolve_nodes()
	return _pivot


func get_socket() -> Node2D:
	if _socket == null or not is_instance_valid(_socket):
		_resolve_nodes()
	return _socket


func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if get_pivot() == null:
		w.append("AttackController: Missing pivot (AttackPivot). Check pivot_path or add VisualRoot/AttackPivot.")
	if get_socket() == null:
		w.append("AttackController: Missing socket (WeaponSocket). Check socket_path or add VisualRoot/WeaponSocket.")
	return w


# --- API expected by MeleeWeapon.gd ---

func connect_finished(cb: Callable) -> void:
	# One-shot by default so we don't accumulate connections.
	if not finished.is_connected(cb):
		finished.connect(cb, CONNECT_ONE_SHOT)


func start_attack(dir: Vector2, _dmg: float = 1.0, _src: Node = null) -> void:
	# Minimal "melee attack lifecycle":
	# - rotate pivot to face dir
	# - play slash animation if present
	# - always emit finished (via anim or timer)
	if dir.length() < 0.001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()

	_resolve_nodes()

	_attack_in_progress = true

	# Face direction (pivot is the canonical rotator)
	var p := get_pivot()
	if p != null:
		# Trust AimRay rotation; derive dir from it
		dir = Vector2.RIGHT.rotated(p.global_rotation)

	# Cancel any previous finish timer
	_cancel_finish_timer()

	# If we have an AnimationPlayer and the animation exists, use its real duration
	if _anim != null and is_instance_valid(_anim) and _anim.has_animation(slash_anim_name):
		# Prevent stacking multiple "animation_finished" handlers
		var cb := Callable(self, "_on_anim_finished")
		if _anim.animation_finished.is_connected(cb):
			_anim.animation_finished.disconnect(cb)
		_anim.animation_finished.connect(cb)
		_anim.play(slash_anim_name)
		return

	# Fallback: timer-based completion
	_start_finish_timer(fallback_finish_time)


func stop_attack() -> void:
	# For future interrupts (stagger/death). Still finishes cleanly.
	if not _attack_in_progress:
		return

	_attack_in_progress = false
	_cancel_finish_timer()

	if _anim != null and is_instance_valid(_anim):
		# Optional: stop animation if you want, but keep it safe
		# _anim.stop()
		var cb := Callable(self, "_on_anim_finished")
		if _anim.animation_finished.is_connected(cb):
			_anim.animation_finished.disconnect(cb)

	_emit_finished()


# --- internals ---

func _on_anim_finished(anim_name: StringName) -> void:
	if not _attack_in_progress:
		return
	if anim_name != slash_anim_name:
		return

	_attack_in_progress = false

	# Disconnect to avoid repeated calls
	if _anim != null and is_instance_valid(_anim):
		var cb := Callable(self, "_on_anim_finished")
		if _anim.animation_finished.is_connected(cb):
			_anim.animation_finished.disconnect(cb)

	_emit_finished()


func _start_finish_timer(t: float) -> void:
	if _finish_timer == null or not is_instance_valid(_finish_timer):
		_finish_timer = Timer.new()
		_finish_timer.one_shot = true
		add_child(_finish_timer)

	_finish_timer.stop()
	_finish_timer.wait_time = maxf(0.01, t)

	# One-shot connection
	var cb := Callable(self, "_on_finish_timer")
	if _finish_timer.timeout.is_connected(cb):
		_finish_timer.timeout.disconnect(cb)
	_finish_timer.timeout.connect(cb, CONNECT_ONE_SHOT)

	_finish_timer.start()


func _cancel_finish_timer() -> void:
	if _finish_timer != null and is_instance_valid(_finish_timer):
		_finish_timer.stop()
		# Don't free; keep reusable


func _on_finish_timer() -> void:
	if not _attack_in_progress:
		return
	_attack_in_progress = false
	_emit_finished()


func _emit_finished() -> void:
	# Emit deferred for safety (avoids re-entrant state transitions)
	call_deferred("_emit_finished_deferred")


func _emit_finished_deferred() -> void:
	finished.emit()

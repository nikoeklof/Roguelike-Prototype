@tool
extends Node
class_name AnimDriver

@export var sprite: AnimatedSprite2D
@export var anim_player: AnimationPlayer
@export var anim_set: AnimSet

@export_node_path("FacingPointer") var facing_pointer_path: NodePath
@export_node_path("CharacterBody2D") var velocity_source: NodePath

@export_range(0.0, 50.0, 0.1) var speed_deadzone := 5.0
@export var play_hurt_anim: bool = true

var _last_anim := ""
var _lock_until_t: float = 0.0
var _lock_priority: int = -999999


func _ready() -> void:
	# Auto-wire convenience (optional)
	if sprite == null:
		sprite = get_parent().get_node_or_null("VisualRoot/animations") as AnimatedSprite2D
		if sprite == null:
			sprite = get_parent().get_node_or_null("Visual/Sprite") as AnimatedSprite2D

	if anim_player == null:
		anim_player = get_parent().get_node_or_null("VisualRoot/AnimationPlayer") as AnimationPlayer
		if anim_player == null:
			anim_player = get_parent().get_node_or_null("Visual/AnimationPlayer") as AnimationPlayer

	if Engine.is_editor_hint():
		update_configuration_warnings()


# -------------------------------------------------------------------
# Timing + lock
# -------------------------------------------------------------------

func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func set_lock_seconds(sec: float, priority: int = 0) -> void:
	var until: float = _now() + max(sec, 0.0)
	if until > _lock_until_t or priority >= _lock_priority:
		_lock_until_t = until
		_lock_priority = priority


# -------------------------------------------------------------------
# Component resolution
# -------------------------------------------------------------------

func _get_facing_pointer() -> FacingPointer:
	# 1) direct path
	if facing_pointer_path != NodePath(""):
		var fp := get_node_or_null(facing_pointer_path) as FacingPointer
		if fp != null:
			return fp

	# 2) resolver via entity
	var entity := get_parent() as Entity
	if entity != null:
		var fp2 := entity.find_component(&"FacingPointer") as FacingPointer
		if fp2 != null:
			return fp2

	# 3) fallback by name
	return get_parent().get_node_or_null("FacingPointer") as FacingPointer


func _get_velocity_source() -> CharacterBody2D:
	if velocity_source != NodePath(""):
		var vs := get_node_or_null(velocity_source)
		if vs is CharacterBody2D:
			return vs
	return get_parent() as CharacterBody2D


func _safe_facing_name(fp: FacingPointer) -> String:
	if fp == null:
		return "down"
	# Your FacingPointer.gd provides this (we added it):
	return fp.get_facing_name()


# -------------------------------------------------------------------
# Animation helpers
# -------------------------------------------------------------------

func _has_anim(anim_name: String) -> bool:
	if anim_name == "":
		return false

	if anim_player != null and anim_player.has_animation(anim_name):
		return true

	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name):
		return true

	return false


func _play(anim_name: String) -> void:
	if anim_name == "" or anim_name == _last_anim:
		return
	if not _has_anim(anim_name):
		return

	_last_anim = anim_name

	if anim_player != null and anim_player.has_animation(anim_name):
		anim_player.play(anim_name)
	elif sprite != null:
		sprite.play(anim_name)


# -------------------------------------------------------------------
# Locomotion
# -------------------------------------------------------------------

func _locomotion_anim(speed: float, facing: String) -> String:
	if anim_set == null:
		return ""

	if anim_set.directional:
		if speed > speed_deadzone:
			return anim_set.walk_prefix + facing
		return anim_set.idle_prefix + facing

	return anim_set.walk_key if speed > speed_deadzone else anim_set.idle_key


# -------------------------------------------------------------------
# Action requests (attack/hurt/etc)
# -------------------------------------------------------------------

func _action_candidates(action: StringName, facing: String) -> Array[String]:
	var out: Array[String] = []
	if anim_set == null:
		return out

	var key := ""
	if anim_set.actions.has(action):
		key = str(anim_set.actions[action])
	else:
		key = str(action)

	if anim_set.actions_are_directional:
		out.append(anim_set.action_prefix + key + "_" + facing)

	out.append(anim_set.action_prefix + key)
	out.append(key)
	return out


func request(action: StringName, lock_sec: float = 0.2, priority: int = 0) -> void:
	if anim_set == null:
		return
	if action == &"hurt" and not play_hurt_anim:
		return

	if _now() < _lock_until_t and priority < _lock_priority:
		return

	var fp := _get_facing_pointer()
	var facing := _safe_facing_name(fp)

	for anim in _action_candidates(action, facing):
		if _has_anim(anim):
			_play(anim)
			set_lock_seconds(lock_sec, priority)
			return


# -------------------------------------------------------------------
# Update loop
# -------------------------------------------------------------------

func update_anim() -> void:
	if anim_set == null:
		return
	if _now() < _lock_until_t:
		return

	var fp := _get_facing_pointer()
	var vs := _get_velocity_source()
	if fp == null or vs == null:
		return

	var facing := _safe_facing_name(fp)
	var speed := vs.velocity.length()

	var desired := _locomotion_anim(speed, facing)

	if not _has_anim(desired) and anim_set.directional:
		desired = anim_set.walk_key if speed > speed_deadzone else anim_set.idle_key

	_play(desired)


func _process(_delta: float) -> void:
	# IMPORTANT: Avoid ALL tool-time execution (prevents placeholder spam in templates).
	if Engine.is_editor_hint():
		return
	update_anim()


# -------------------------------------------------------------------
# Editor warnings
# -------------------------------------------------------------------

func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if anim_set == null:
		w.append("AnimDriver: Missing AnimSet reference.")
	if sprite == null and anim_player == null:
		w.append("AnimDriver: Provide AnimatedSprite2D or AnimationPlayer.")
	return w

extends Node
class_name EnemyAttack

@export var melee: MeleeAttack
@export var ranged: RangedAttack

@export var default_mode: Mode = Mode.MELEE
@export var cooldown_sec := 0.8
@export var require_los := false

enum Mode { MELEE, RANGED }
var mode: Mode

var _cooldown_until := 0.0
var actor: Node2D


func _ready() -> void:
	actor = get_parent() as Node2D
	if actor == null:
		push_error("EnemyAttack must be a child of a Node2D (needs global_position).")
		return

	mode = default_mode

	if melee:
		melee.actor = actor
	if ranged:
		ranged.actor = actor


func can_attack() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	return now >= _cooldown_until


func attack_at(target_global_pos: Vector2) -> bool:
	if actor == null:
		return false

	var now := Time.get_ticks_msec() / 1000.0
	if now < _cooldown_until:
		return false

	var dir := target_global_pos - actor.global_position
	if dir.length() < 0.001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()

	# Optional LOS (stub)
	if require_los:
		pass

	var ok := false
	match mode:
		Mode.MELEE:
			ok = melee != null and melee.try_attack(dir)
		Mode.RANGED:
			ok = ranged != null and ranged.try_attack(dir)

	if ok:
		_cooldown_until = now + cooldown_sec
	return ok

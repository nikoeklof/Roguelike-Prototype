extends Node
class_name Spell

signal cast_finished(success: bool)

enum SpellType { OFFENSIVE, DEFENSIVE }
@export var spell_type: SpellType = SpellType.OFFENSIVE

@export var cooldown_sec: float = 1.0
@export var cast_time_sec: float = 0.0

@export var allow_move_during_cast: bool = false

# ✅ NEW: for pickup inference
@export var pickup_slot_kind: Equipment.SlotKind = Equipment.SlotKind.SPELL
@export var pickup_icon: Texture2D

var _cd_until := 0.0

func can_cast() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	return now >= _cd_until

func get_pickup_slot_kind() -> int:
	return int(pickup_slot_kind)

func get_pickup_icon() -> Texture2D:
	return pickup_icon

func try_cast(owner_entity: Node, dir: Vector2) -> bool:
	if owner_entity == null or not can_cast():
		return false

	var now := Time.get_ticks_msec() / 1000.0
	_cd_until = now + max(cooldown_sec, 0.0)

	if cast_time_sec <= 0.0:
		_do_cast(owner_entity, dir)
		cast_finished.emit(true)
		return true

	var t := Timer.new()
	t.one_shot = true
	t.wait_time = cast_time_sec
	owner_entity.add_child(t)
	t.timeout.connect(func():
		if is_instance_valid(owner_entity):
			_do_cast(owner_entity, dir)
		cast_finished.emit(true)
		t.queue_free()
	)
	t.start()
	return true

func _do_cast(_owner_entity: Node, _dir: Vector2) -> void:
	pass

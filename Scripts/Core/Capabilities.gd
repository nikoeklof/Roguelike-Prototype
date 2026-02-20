extends Node
class_name Capabilities

signal capability_changed(cap: StringName, enabled: bool)

# Common capability ids (use these everywhere to avoid typos)
const CAN_MOVE: StringName   = &"can_move"
const CAN_ATTACK: StringName = &"can_attack"
const CAN_CAST: StringName   = &"can_cast"
const CAN_BLOCK: StringName  = &"can_block"
const CAN_SWITCH: StringName = &"can_switch" # switching active slot

@export var defaults: Dictionary = {
	CAN_MOVE: true,
	CAN_ATTACK: true,
	CAN_CAST: true,
	CAN_BLOCK: true,
	CAN_SWITCH: true,
}

# cap -> Dictionary(reason -> true)
var _blocks: Dictionary = {}

func is_enabled(cap: StringName) -> bool:
	var base := true
	if defaults.has(cap):
		base = bool(defaults[cap])
	if not base:
		return false
	return not _blocks.has(cap) or _blocks[cap].is_empty()

func is_blocked(cap: StringName) -> bool:
	return not is_enabled(cap)

func block(cap: StringName, reason: StringName) -> void:
	if cap == &"" or reason == &"":
		return

	var was_enabled := is_enabled(cap)

	if not _blocks.has(cap):
		_blocks[cap] = {}
	_blocks[cap][reason] = true

	if was_enabled and not is_enabled(cap):
		capability_changed.emit(cap, false)

func unblock(cap: StringName, reason: StringName) -> void:
	if not _blocks.has(cap):
		return
	var reasons: Dictionary = _blocks[cap]

	var was_enabled := is_enabled(cap)

	if reasons.has(reason):
		reasons.erase(reason)
	# cleanup empty
	if reasons.is_empty():
		_blocks.erase(cap)

	if not was_enabled and is_enabled(cap):
		capability_changed.emit(cap, true)

func clear_blocks(cap: StringName) -> void:
	var was_enabled := is_enabled(cap)
	_blocks.erase(cap)
	if not was_enabled and is_enabled(cap):
		capability_changed.emit(cap, true)

func clear_all_blocks() -> void:
	# emit changes for anything that becomes enabled
	var caps := _blocks.keys()
	for cap in caps:
		var was_enabled := is_enabled(cap)
		_blocks.erase(cap)
		if not was_enabled and is_enabled(cap):
			capability_changed.emit(cap, true)

func debug_reasons(cap: StringName) -> Array[StringName]:
	if not _blocks.has(cap):
		return []
	var out: Array[StringName] = []
	out.assign(_blocks[cap].keys())
	return out

extends Node
class_name Equipment

signal active_slot_changed(prev_slot: int, new_slot: int, reason: String)

enum SlotKind { MELEE, RANGED, SPELL, SHIELD }

var _active_slot: int = Combat.AttackKind.MELEE

@export var active_slot: int:
	get:
		return _active_slot
	set(value):
		set_active_slot(value, "set:export")

@export_node_path("Node") var melee_slot_path: NodePath = ^"MeleeSlot"
@export_node_path("Node") var ranged_slot_path: NodePath = ^"RangedSlot"
@export_node_path("Node") var spell_slot_path: NodePath = ^"SpellSlot"
@export_node_path("Node") var shield_slot_path: NodePath = ^"ShieldSlot"


func set_active_slot(new_slot: int, reason: String = "") -> void:
	if new_slot == _active_slot:
		return
	var prev := _active_slot
	_active_slot = new_slot
	print("[Equipment] active_slot: %s → %s%s" % [
		_kind_name(prev),
		_kind_name(new_slot),
		(" (reason: %s)" % reason) if reason != "" else ""
	])
	active_slot_changed.emit(prev, new_slot, reason)


func cycle_active_slot(dir: int, reason: String = "cycle") -> void:
	var order := [Combat.AttackKind.MELEE, Combat.AttackKind.RANGED]
	var idx := order.find(_active_slot)
	if idx == -1:
		idx = 0
	idx = (idx + (1 if dir >= 0 else -1)) % order.size()
	set_active_slot(order[idx], reason)


func set_active_slot_melee(reason: String = "slot_melee") -> void:
	set_active_slot(Combat.AttackKind.MELEE, reason)

func set_active_slot_ranged(reason: String = "slot_ranged") -> void:
	set_active_slot(Combat.AttackKind.RANGED, reason)

func set_active_slot_spell(reason: String = "slot_spell") -> void:
	set_active_slot(Combat.AttackKind.SPELL, reason)


func get_item_for_kind(kind: int) -> Node:
	match kind:
		Combat.AttackKind.MELEE:
			return _get_equipped(_slot(melee_slot_path))
		Combat.AttackKind.RANGED:
			return _get_equipped(_slot(ranged_slot_path))
		Combat.AttackKind.SPELL:
			return _get_equipped(_slot(spell_slot_path))
		_:
			return null


func get_active_item() -> Node:
	return get_item_for_kind(_active_slot)


func get_shield() -> Node:
	return _get_equipped(_slot(shield_slot_path))


# --- NEW: strong validation ---
static func slot_kind_name(kind: int) -> String:
	match kind:
		SlotKind.MELEE: return "MELEE"
		SlotKind.RANGED: return "RANGED"
		SlotKind.SPELL: return "SPELL"
		SlotKind.SHIELD: return "SHIELD"
		_: return "UNKNOWN(%d)" % kind


static func item_slot_kind(item: Node) -> int:
	# Prefer explicit reporting.
	if item != null and item.has_method(&"get_pickup_slot_kind"):
		var res: Variant = item.call(&"get_pickup_slot_kind")
		if res is int:
			return int(res)

	# Fallback inference.
	if item is Spell:
		return int(SlotKind.SPELL)
	if item is Shield:
		return int(SlotKind.SHIELD)
	if item is Weapon:
		# Default to MELEE if weapon doesn't specify.
		return int(SlotKind.MELEE)

	return int(SlotKind.MELEE)


static func is_item_valid_for_slot(item: Node, slot_kind: int) -> bool:
	if item == null:
		return true

	match slot_kind:
		SlotKind.MELEE:
			if not (item is Weapon):
				return false
			return item_slot_kind(item) == int(SlotKind.MELEE)

		SlotKind.RANGED:
			if not (item is Weapon):
				return false
			return item_slot_kind(item) == int(SlotKind.RANGED)

		SlotKind.SPELL:
			return item is Spell

		SlotKind.SHIELD:
			return item is Shield

		_:
			return false


# --- Swap API with validation (does NOT drop; returns replaced item) ---
func swap_item_in_slot(slot_kind: int, new_item: Node) -> Node:
	print("\n---- EQUIPMENT swap_item_in_slot ----")
	print("slot_kind:", slot_kind, "(", slot_kind_name(slot_kind), ")")
	print("new_item:", new_item)

	if new_item == null:
		print("[Equipment] FAIL: new_item is null")
		return null

	if not is_item_valid_for_slot(new_item, slot_kind):
		push_warning("Equipment: swap rejected. Item '%s' not valid for slot %s." %
			[new_item.name, slot_kind_name(slot_kind)])
		print("[Equipment] FAIL: validation rejected")
		return null

	var slot_path := _slot_path_from_kind(slot_kind)
	print("[Equipment] slot_path:", slot_path)
	var slot := _slot(slot_path)
	print("[Equipment] slot node:", slot)
	if slot == null:
		push_warning("Equipment: swap rejected. Missing slot node for %s." % slot_kind_name(slot_kind))
		print("[Equipment] FAIL: slot node missing")
		return null

	var old_item: Node = null
	if slot.has_method("set_item"):
		old_item = slot.call("set_item", new_item, false) as Node
		print("[Equipment] slot.set_item returned old_item:", old_item)
		print("[Equipment] new_item parent after set_item:", new_item.get_parent())
	else:
		print("[Equipment] WARNING: slot has no set_item(), using fallback")
		old_item = _get_equipped(slot)
		if old_item != null:
			slot.remove_child(old_item)
		for c in slot.get_children():
			(c as Node).queue_free()
		slot.add_child(new_item)

	print("---- END EQUIPMENT swap_item_in_slot ----\n")
	return old_item


# --- Internals ---
func _slot_path_from_kind(kind: int) -> NodePath:
	match kind:
		SlotKind.MELEE: return melee_slot_path
		SlotKind.RANGED: return ranged_slot_path
		SlotKind.SPELL: return spell_slot_path
		SlotKind.SHIELD: return shield_slot_path
		_: return NodePath("")

func _slot(path: NodePath) -> Node:
	if path == NodePath(""):
		return null
	return get_node_or_null(path)

func _get_equipped(slot: Node) -> Node:
	if slot == null:
		return null
	if slot.has_method("get_item"):
		return slot.call("get_item") as Node
	if slot.get_child_count() == 0:
		return null
	return slot.get_child(0) as Node

func _kind_name(kind: int) -> String:
	match kind:
		Combat.AttackKind.MELEE: return "MELEE"
		Combat.AttackKind.RANGED: return "RANGED"
		Combat.AttackKind.SPELL: return "SPELL"
		Combat.AttackKind.NONE: return "NONE"
		_: return "UNKNOWN(%d)" % kind


# ------------------------------------------------------------
# Debug/UI helper (read-only)
# ------------------------------------------------------------
func get_equipped_items_debug() -> Dictionary[String, Node]:
	# Stable, explicit view of what’s equipped. Used by DebugHUD.
	var out: Dictionary[String, Node] = {}
	out["MELEE"] = _get_equipped(_slot(melee_slot_path))
	out["RANGED"] = _get_equipped(_slot(ranged_slot_path))
	out["SPELL"] = _get_equipped(_slot(spell_slot_path))
	out["SHIELD"] = _get_equipped(_slot(shield_slot_path))
	return out

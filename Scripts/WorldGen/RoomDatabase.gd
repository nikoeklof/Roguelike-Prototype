extends Node
class_name RoomDatabase
## RoomDatabase
## - Scans a directory for RoomChunk scenes (.tscn)
## - Infers exits bitmask from presence of Exits/Exit_* markers
## - Provides deterministic selection for a given exits mask
##
## IMPORTANT:
## We do NOT instantiate PackedScenes to infer exits, to avoid TileMap/TileSet init spam.
## Instead we inspect the PackedScene's SceneState and read node paths.

const N: int = 1
const E: int = 2
const S: int = 4
const W: int = 8

@export_dir var rooms_dir: String = "res://Scenes/Templates/World/RoomGen"
@export var fallback_room_scene: PackedScene


class RoomEntry extends RefCounted:
	var scene: PackedScene
	var scene_path: String
	var exits_mask: int

	func _init(p_scene: PackedScene, p_path: String, p_mask: int) -> void:
		scene = p_scene
		scene_path = p_path
		exits_mask = p_mask


# Godot 4 note: nested typed collections are not supported.
# Keys: int exits_mask
# Values: Array[RoomEntry]
var _by_mask: Dictionary = {}
var _all: Array[RoomEntry] = []


func rebuild() -> void:
	_by_mask.clear()
	_all.clear()

	if rooms_dir.is_empty():
		push_warning("RoomDatabase: rooms_dir is empty; using fallback only.")
		return

	var paths: Array[String] = []
	_collect_room_scene_paths(rooms_dir, paths)

	for p: String in paths:
		var ps: PackedScene = load(p) as PackedScene
		if ps == null:
			continue

		var mask: int = _infer_exits_mask_from_scene_state(ps)
		var entry := RoomEntry.new(ps, p, mask)
		_all.append(entry)

		var list: Array[RoomEntry]
		if _by_mask.has(mask):
			list = _by_mask[mask] as Array[RoomEntry]
		else:
			list = []
			_by_mask[mask] = list

		list.append(entry)

	if _all.is_empty() and fallback_room_scene == null:
		push_warning("RoomDatabase: no room scenes found and no fallback_room_scene set.")


func pick_scene(exits_mask: int, rng: RandomNumberGenerator) -> PackedScene:
	var list: Array[RoomEntry] = []
	if _by_mask.has(exits_mask):
		list = _by_mask[exits_mask] as Array[RoomEntry]

	if not list.is_empty():
		var idx: int = rng.randi_range(0, list.size() - 1)
		return list[idx].scene

	if fallback_room_scene != null:
		return fallback_room_scene

	if not _all.is_empty():
		var idx2: int = rng.randi_range(0, _all.size() - 1)
		push_warning("RoomDatabase: no match for exits_mask=%d; using %s" % [exits_mask, _all[idx2].scene_path])
		return _all[idx2].scene

	return null


func debug_summary() -> String:
	var keys: Array = _by_mask.keys()
	keys.sort()

	var lines: PackedStringArray = []
	lines.append("RoomDatabase: %d scenes" % _all.size())
	for k_var: Variant in keys:
		var k: int = int(k_var)
		var list: Array[RoomEntry] = _by_mask[k] as Array[RoomEntry]
		lines.append("  mask %2d : %d" % [k, list.size()])
	return "\n".join(lines)


func _collect_room_scene_paths(dir_path: String, out_paths: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_warning("RoomDatabase: cannot open dir: %s" % dir_path)
		return

	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue

		var full: String = dir_path.path_join(name)
		if dir.current_is_dir():
			_collect_room_scene_paths(full, out_paths)
			continue

		if not name.ends_with(".tscn"):
			continue
		if name.find("RoomChunk") == -1:
			continue

		out_paths.append(full)

	dir.list_dir_end()


func _infer_exits_mask_from_scene_state(ps: PackedScene) -> int:
	var state: SceneState = ps.get_state()
	if state == null:
		return 0

	var node_count: int = state.get_node_count()
	if node_count <= 0:
		return 0

	var mask: int = 0
	for i: int in range(node_count):
		# Godot 4: SceneState.get_node_path(i) returns a NodePath.
		var np: NodePath = state.get_node_path(i)
		var p: String = String(np)

		# Paths look like: "RoomChunk/Exits/Exit_N" or "Exits/Exit_N" depending on root name.
		# Using ends_with keeps it resilient.
		if p.ends_with("Exits/Exit_N"):
			mask |= N
		elif p.ends_with("Exits/Exit_E"):
			mask |= E
		elif p.ends_with("Exits/Exit_S"):
			mask |= S
		elif p.ends_with("Exits/Exit_W"):
			mask |= W

	return mask

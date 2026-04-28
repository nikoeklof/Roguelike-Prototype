extends Node
class_name RoomLayoutDatabase
## Scans a directory for RoomLayout scenes (.tscn).
## Groups by exits_mask + room kind (inferred from subdirectory name).
## Kind subdirs: Boss/, Start/ — everything else is NORMAL.
##
## Exits mask is inferred the same way as RoomDatabase:
## presence of Exits/Exit_N/E/S/W markers in SceneState.

const N: int = 1
const E: int = 2
const S: int = 4
const W: int = 8

@export_dir var layouts_dir: String = "res://Scenes/Templates/World/RoomGen"
@export var fallback_layout_scene: PackedScene


class LayoutEntry extends RefCounted:
	var scene: PackedScene
	var scene_path: String
	var exits_mask: int
	var kind: StringName

	func _init(p_scene: PackedScene, p_path: String, p_mask: int, p_kind: StringName) -> void:
		scene = p_scene
		scene_path = p_path
		exits_mask = p_mask
		kind = p_kind


# Keys: String "%d|%s" % [exits_mask, kind]
# Values: Array[LayoutEntry]
var _by_key: Dictionary = {}
var _all: Array[LayoutEntry] = []


func rebuild() -> void:
	_by_key.clear()
	_all.clear()

	if layouts_dir.is_empty():
		push_warning("RoomLayoutDatabase: layouts_dir is empty; using fallback only.")
		return

	var paths: Array[String] = []
	_collect_layout_scene_paths(layouts_dir, paths)

	for p: String in paths:
		var ps: PackedScene = load(p) as PackedScene
		if ps == null:
			continue

		var mask: int = _infer_exits_mask_from_filename(p.get_file())
		var kind: StringName = _infer_kind_from_path(p)
		var entry := LayoutEntry.new(ps, p, mask, kind)
		_all.append(entry)

		var key: String = _make_key(mask, kind)
		var list: Array[LayoutEntry]
		if _by_key.has(key):
			list = _by_key[key] as Array[LayoutEntry]
		else:
			list = []
			_by_key[key] = list
		list.append(entry)

	if _all.is_empty() and fallback_layout_scene == null:
		push_warning("RoomLayoutDatabase: no layout scenes found and no fallback_layout_scene set.")


func pick_layout(exits_mask: int, kind: StringName, rng: RandomNumberGenerator) -> PackedScene:
	# 1. Exact match.
	var list := _get_list(exits_mask, kind)
	if not list.is_empty():
		return list[rng.randi_range(0, list.size() - 1)].scene

	# 2. Fall back to NORMAL for unknown kinds.
	if kind != &"NORMAL":
		list = _get_list(exits_mask, &"NORMAL")
		if not list.is_empty():
			push_warning("RoomLayoutDatabase: no '%s' layout for mask=%d; using NORMAL." % [String(kind), exits_mask])
			return list[rng.randi_range(0, list.size() - 1)].scene

	# 3. Fallback scene.
	if fallback_layout_scene != null:
		return fallback_layout_scene

	# 4. Any layout at all.
	if not _all.is_empty():
		var idx: int = rng.randi_range(0, _all.size() - 1)
		push_warning("RoomLayoutDatabase: no match for mask=%d kind=%s; using %s" % [exits_mask, String(kind), _all[idx].scene_path])
		return _all[idx].scene

	return null


func debug_summary() -> String:
	var keys: Array = _by_key.keys()
	keys.sort()
	var lines: PackedStringArray = []
	lines.append("RoomLayoutDatabase: %d layouts" % _all.size())
	for k: Variant in keys:
		var list: Array[LayoutEntry] = _by_key[k] as Array[LayoutEntry]
		lines.append("  %-12s : %d" % [str(k), list.size()])
	return "\n".join(lines)


func _get_list(exits_mask: int, kind: StringName) -> Array[LayoutEntry]:
	var key: String = _make_key(exits_mask, kind)
	if _by_key.has(key):
		return _by_key[key] as Array[LayoutEntry]
	return []


func _make_key(exits_mask: int, kind: StringName) -> String:
	return "%d|%s" % [exits_mask, String(kind)]


func _infer_kind_from_path(path: String) -> StringName:
	# Check directory components (lowercase) for kind markers.
	var parts := path.to_lower().split("/")
	for part: String in parts:
		if part == "boss":
			return &"BOSS"
		if part == "start":
			return &"START"
	return &"NORMAL"


func _collect_layout_scene_paths(dir_path: String, out_paths: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_warning("RoomLayoutDatabase: cannot open dir: %s" % dir_path)
		return

	dir.list_dir_begin()
	while true:
		var entry_name: String = dir.get_next()
		if entry_name.is_empty():
			break
		if entry_name.begins_with("."):
			continue

		var full: String = dir_path.path_join(entry_name)
		if dir.current_is_dir():
			_collect_layout_scene_paths(full, out_paths)
			continue

		if not entry_name.ends_with(".tscn"):
			continue
		if entry_name.find("RoomLayout") == -1:
			continue
		if entry_name.ends_with("_template.tscn"):
			continue

		out_paths.append(full)

	dir.list_dir_end()


# Parses exits from filename. Expects segment after first underscore to be the exits string.
# e.g. "RoomLayout_NESW_01.tscn" → segment "NESW" → mask 15
#      "RoomLayout_XL_NESW_01.tscn" → skips "XL", reads "NESW"
func _infer_exits_mask_from_filename(filename: String) -> int:
	var parts := filename.get_basename().split("_")
	var mask: int = 0
	for part: String in parts:
		# Skip known non-exit segments.
		if part in ["RoomLayout", "XL", "Boss", "Start", "Normal"]:
			continue
		# First segment that contains only N/E/S/W characters is the exits string.
		var is_exits := true
		for ch: String in part.split(""):
			if ch not in ["N", "E", "S", "W"]:
				is_exits = false
				break
		if not is_exits or part.is_empty():
			continue
		if "N" in part: mask |= N
		if "E" in part: mask |= E
		if "S" in part: mask |= S
		if "W" in part: mask |= W
		break
	return mask

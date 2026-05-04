extends Node
class_name RoomLayoutDatabase
## Scans a directory for RoomLayout scenes (.tscn).
## Groups by room kind only (inferred from subdirectory name).
## Kind subdirs: Boss/, Start/ — everything else is NORMAL.
## Layouts are content-only overlays (props, spawns) and fit any exit configuration.

@export_dir var layouts_dir: String = "res://Scenes/Templates/World/RoomGen"
@export var fallback_layout_scene: PackedScene


class LayoutEntry extends RefCounted:
	var scene: PackedScene
	var scene_path: String
	var kind: StringName

	func _init(p_scene: PackedScene, p_path: String, p_kind: StringName) -> void:
		scene = p_scene
		scene_path = p_path
		kind = p_kind


# Keys: StringName kind  Values: Array[LayoutEntry]
var _by_kind: Dictionary = {}
var _all: Array[LayoutEntry] = []


func rebuild() -> void:
	_by_kind.clear()
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

		var kind: StringName = _infer_kind_from_path(p)
		var entry := LayoutEntry.new(ps, p, kind)
		_all.append(entry)

		var list: Array[LayoutEntry]
		if _by_kind.has(kind):
			list = _by_kind[kind] as Array[LayoutEntry]
		else:
			list = []
			_by_kind[kind] = list
		list.append(entry)

	if _all.is_empty() and fallback_layout_scene == null:
		push_warning("RoomLayoutDatabase: no layout scenes found and no fallback_layout_scene set.")


func pick_layout(kind: StringName, rng: RandomNumberGenerator, used_paths: Array[String] = []) -> PackedScene:
	# 1. Exact kind match, preferring unused layouts.
	var list := _get_list(kind)
	var scene := _pick_preferring_unused(list, rng, used_paths)
	if scene != null:
		return scene

	# 2. Fall back to NORMAL.
	if kind != &"NORMAL":
		list = _get_list(&"NORMAL")
		scene = _pick_preferring_unused(list, rng, used_paths)
		if scene != null:
			return scene

	# 3. Fallback scene.
	if fallback_layout_scene != null:
		return fallback_layout_scene

	# 4. Any layout at all.
	if not _all.is_empty():
		var idx: int = rng.randi_range(0, _all.size() - 1)
		push_warning("RoomLayoutDatabase: no layout for kind=%s; using %s" % [String(kind), _all[idx].scene_path])
		return _all[idx].scene

	return null


func _pick_preferring_unused(list: Array[LayoutEntry], rng: RandomNumberGenerator, used_paths: Array[String]) -> PackedScene:
	if list.is_empty():
		return null
	var unused: Array[LayoutEntry] = []
	for e: LayoutEntry in list:
		if e.scene_path not in used_paths:
			unused.append(e)
	var pool := unused if not unused.is_empty() else list
	return pool[rng.randi_range(0, pool.size() - 1)].scene


func debug_summary() -> String:
	var lines: PackedStringArray = []
	lines.append("RoomLayoutDatabase: %d layouts" % _all.size())
	for kind: Variant in _by_kind.keys():
		var list: Array[LayoutEntry] = _by_kind[kind] as Array[LayoutEntry]
		lines.append("  %-12s : %d" % [String(kind as StringName), list.size()])
	return "\n".join(lines)


func _get_list(kind: StringName) -> Array[LayoutEntry]:
	if _by_kind.has(kind):
		return _by_kind[kind] as Array[LayoutEntry]
	return []


func _infer_kind_from_path(path: String) -> StringName:
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
		if entry_name.to_lower().ends_with("_template.tscn") or entry_name.to_lower().ends_with("xltemplate.tscn"):
			continue

		out_paths.append(full)

	dir.list_dir_end()

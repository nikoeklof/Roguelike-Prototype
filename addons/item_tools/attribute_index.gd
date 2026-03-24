@tool
extends RefCounted
class_name AttributeIndex

var attribute_root: String = "res://Resources/Items/Attributes"

# Cached scan results: Array[ItemAttribute] + metadata
var _attributes: Array[Resource] = []
var _meta_by_path: Dictionary = {} # path -> { "path", "name", "group", "compat" }

enum Compat { ANY, MELEE, RANGED }

func refresh() -> void:
	_attributes.clear()
	_meta_by_path.clear()

	var paths: Array[String] = []
	_collect_resource_paths(attribute_root, paths)

	for p in paths:
		var res := ResourceLoader.load(p)
		if res == null:
			continue
		# We only care about ItemAttribute resources (by script class name).
		# This is robust even if the resource is a .tres with a script.
		if res is ItemAttribute:
			_attributes.append(res)
			_meta_by_path[p] = _build_meta(p, res)

func all_attributes() -> Array[Resource]:
	return _attributes

func meta_for(res: Resource) -> Dictionary:
	if res == null:
		return {}
	var p := res.resource_path
	return _meta_by_path.get(p, {})

func filtered_and_grouped(item_category: String) -> Dictionary:
	# returns group_name -> Array[Resource]
	var result: Dictionary = {}
	var want := _category_to_compat(item_category)

	for a in _attributes:
		if a == null:
			continue
		var m := meta_for(a)
		var compat: int = int(m.get("compat", Compat.ANY))
		if not _compat_ok(want, compat):
			continue

		var group_name := StringName(m.get("group", &"General"))
		if not result.has(group_name):
			result[group_name] = []
		result[group_name].append(a)

	# Sort each group by filename (stable + predictable)
	for k in result.keys():
		var arr: Array = result[k]
		arr.sort_custom(func(x: Resource, y: Resource) -> bool:
			return x.resource_path.get_file() < y.resource_path.get_file()
		)
		result[k] = arr

	return result

func infer_group_from_filename(file_name: String) -> StringName:
	# "Ranged_ExtraProjectiles.tres" -> "Ranged"
	var base := file_name.get_basename()
	var idx := base.find("_")
	if idx <= 0:
		return &"General"
	return StringName(base.substr(0, idx))

func infer_compat_from_filename(file_name: String) -> int:
	# Prefix-based compat:
	#   Melee_*  -> MELEE
	#   Ranged_* -> RANGED
	# else ANY
	var base := file_name.get_basename()
	if base.begins_with("Melee_"):
		return Compat.MELEE
	if base.begins_with("Ranged_"):
		return Compat.RANGED
	return Compat.ANY

func _build_meta(path: String, res: Resource) -> Dictionary:
	var file := path.get_file()
	return {
		"path": path,
		"name": file.get_basename(),
		"group": infer_group_from_filename(file),
		"compat": infer_compat_from_filename(file),
	}

func _collect_resource_paths(root: String, out_paths: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(root):
		return

	var dir := DirAccess.open(root)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue

		var full := root.path_join(name)
		if dir.current_is_dir():
			_collect_resource_paths(full, out_paths)
		else:
			# We only scan .tres/.res; cheap filter
			if full.ends_with(".tres") or full.ends_with(".res"):
				out_paths.append(full)
	dir.list_dir_end()

func _category_to_compat(category: String) -> int:
	# Your ItemDef.category is currently shown as "Ranged"/"Melee".
	# If it’s an enum internally, it still converts to a string in the inspector.
	match category:
		"Melee":
			return Compat.MELEE
		"Ranged":
			return Compat.RANGED
		_:
			return Compat.ANY

func _compat_ok(want: int, have: int) -> bool:
	if want == Compat.ANY:
		return true
	return have == Compat.ANY or have == want

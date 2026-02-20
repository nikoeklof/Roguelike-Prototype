extends Node
class_name Tags

## Simple tag set. Use StringName for speed and typo-safety.
signal tag_added(tag: StringName)
signal tag_removed(tag: StringName)
signal tags_changed()

@export var initial_tags: Array[StringName] = []

var _tags: Dictionary = {} # tag:StringName -> true

func _ready() -> void:
	for t in initial_tags:
		add_tag(t)

func has_tag(tag: StringName) -> bool:
	return _tags.has(tag)

func has_any(tags: Array[StringName]) -> bool:
	for t in tags:
		if _tags.has(t):
			return true
	return false

func has_all(tags: Array[StringName]) -> bool:
	for t in tags:
		if not _tags.has(t):
			return false
	return true

func add_tag(tag: StringName) -> void:
	if tag == &"":
		return
	if _tags.has(tag):
		return
	_tags[tag] = true
	tag_added.emit(tag)
	tags_changed.emit()

func remove_tag(tag: StringName) -> void:
	if not _tags.has(tag):
		return
	_tags.erase(tag)
	tag_removed.emit(tag)
	tags_changed.emit()

func clear() -> void:
	if _tags.is_empty():
		return
	_tags.clear()
	tags_changed.emit()

func list() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_tags.keys())
	return out

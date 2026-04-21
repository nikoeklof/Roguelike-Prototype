@tool
extends Resource
class_name ItemTypeRegistry

const SCAN_PATH     := "res://Resources/Items/BaseTypes/"
const REGISTRY_PATH := "res://Resources/Items/ItemTypeRegistry.tres"

@export var entries: Array[BaseItemType] = []

@export_tool_button("Refresh Registry") var _refresh_btn = func() -> void: refresh()


func refresh() -> void:
	if not Engine.is_editor_hint():
		push_warning("[ItemTypeRegistry] refresh() only works in the editor.")
		return
	entries.clear()
	var dir := DirAccess.open(SCAN_PATH)
	if dir == null:
		push_error("[ItemTypeRegistry] Cannot open: %s" % SCAN_PATH)
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres") and not file.to_lower().contains("template"):
			var res: Resource = ResourceLoader.load(SCAN_PATH + file)
			if res is BaseItemType:
				entries.append(res as BaseItemType)
				print("[ItemTypeRegistry] +  %s" % file)
		file = dir.get_next()
	dir.list_dir_end()
	ResourceSaver.save(self, REGISTRY_PATH)
	print("[ItemTypeRegistry] Saved %d entries → %s" % [entries.size(), REGISTRY_PATH])


func get_for_category(category: int) -> Array[BaseItemType]:
	var out: Array[BaseItemType] = []
	for bt: BaseItemType in entries:
		if bt != null and bt.item_def != null and int(bt.item_def.category) == category:
			out.append(bt)
	return out


static func load_registry() -> ItemTypeRegistry:
	if not ResourceLoader.exists(REGISTRY_PATH):
		push_error("[ItemTypeRegistry] Not found at %s. Create a new ItemTypeRegistry resource there and click 'Refresh Registry'." % REGISTRY_PATH)
		return null
	var res: Resource = ResourceLoader.load(REGISTRY_PATH)
	if not (res is ItemTypeRegistry):
		push_error("[ItemTypeRegistry] Resource at %s is not an ItemTypeRegistry." % REGISTRY_PATH)
		return null
	return res as ItemTypeRegistry

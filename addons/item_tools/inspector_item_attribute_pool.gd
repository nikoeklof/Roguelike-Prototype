@tool
extends EditorInspectorPlugin
class_name InspectorItemAttributePool

# Legacy manual attribute pool editor  has been removed.
# This inspector plugin is kept as a stub for backwards compatibility with the addon
# registration, but it no longer injects any UI.

func _can_handle(_object: Object) -> bool:
	return false

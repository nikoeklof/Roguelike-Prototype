@tool
extends EditorPlugin

var _preview: InspectorBaseItemPreview


func _enter_tree() -> void:
	_preview = InspectorBaseItemPreview.new()
	_preview.set_editor_interface(get_editor_interface())
	add_inspector_plugin(_preview)


func _exit_tree() -> void:
	if _preview != null:
		remove_inspector_plugin(_preview)
		_preview = null

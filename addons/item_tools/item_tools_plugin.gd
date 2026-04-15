@tool
extends EditorPlugin

var _preview: InspectorBaseItemPreview
var _melee_editor: InspectorMeleeDefEditor


func _enter_tree() -> void:
	_preview = InspectorBaseItemPreview.new()
	_preview.set_editor_interface(get_editor_interface())
	add_inspector_plugin(_preview)

	_melee_editor = InspectorMeleeDefEditor.new()
	add_inspector_plugin(_melee_editor)


func _exit_tree() -> void:
	if _preview != null:
		remove_inspector_plugin(_preview)
		_preview = null

	if _melee_editor != null:
		remove_inspector_plugin(_melee_editor)
		_melee_editor = null

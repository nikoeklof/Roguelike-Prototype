@tool
extends PopupPanel
class_name AttributePicker

signal attribute_chosen(attr: ItemAttribute)

var _index: AttributeIndex
var _category: String = "Any"

var _search: LineEdit
var _tree: Tree
var _refresh_btn: Button

func setup(index: AttributeIndex, category: String) -> void:
	_index = index
	_category = category

func _ready() -> void:
	size = Vector2(520, 520)

	var root := VBoxContainer.new()
	add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)

	_search = LineEdit.new()
	_search.placeholder_text = "Search attributes…"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_search)

	_refresh_btn = Button.new()
	_refresh_btn.text = "Rescan"
	top.add_child(_refresh_btn)

	_tree = Tree.new()
	_tree.hide_root = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_tree)

	_search.text_changed.connect(_rebuild)
	_refresh_btn.pressed.connect(_on_rescan_pressed)
	_tree.item_activated.connect(_on_item_activated)

	_rebuild()

func _on_rescan_pressed() -> void:
	if _index != null:
		_index.refresh()
	_rebuild()

func _rebuild(_unused := "") -> void:
	_tree.clear()
	if _index == null:
		return

	var grouped := _index.filtered_and_grouped(_category)
	var tree_root := _tree.create_item()

	var query := _search.text.strip_edges().to_lower()

	# Keep groups stable sorted by name
	var group_names := grouped.keys()
	group_names.sort()

	for g in group_names:
		var group_item := _tree.create_item(tree_root)
		group_item.set_text(0, str(g))
		group_item.set_selectable(0, false)

		var attrs: Array = grouped[g]
		for a in attrs:
			if a == null:
				continue
			var meta := _index.meta_for(a)
			var display_name := str(meta.get("name", a.resource_path.get_file().get_basename()))
			if query != "":
				if display_name.to_lower().find(query) == -1:
					continue
			var child := _tree.create_item(group_item)
			child.set_text(0, display_name)
			child.set_metadata(0, a.resource_path)
			child.set_tooltip_text(0, _make_tooltip(a, display_name))

func _on_item_activated() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	var path = item.get_metadata(0)
	if typeof(path) != TYPE_STRING:
		return

	var res := ResourceLoader.load(path)
	if res is ItemAttribute:
		attribute_chosen.emit(res)
		hide()

func _make_tooltip(attr: ItemAttribute, display_name: String) -> String:
	var lines: Array[String] = []
	lines.append(display_name)

	if attr.id != StringName() and not String(attr.id).is_empty():
		lines.append("ID: %s" % String(attr.id))

	if not attr.resource_path.is_empty():
		lines.append(attr.resource_path)

	if "editor_description" in attr and String(attr.editor_description).strip_edges() != "":
		lines.append("")
		lines.append(String(attr.editor_description).strip_edges())

	return "\n".join(lines)

@tool
extends EditorInspectorPlugin
class_name InspectorMeleeDefEditor

## Adds an editable "Attack Style" panel at the top of the inspector when a
## MeleeItemDef resource is opened directly (e.g. from the FileSystem dock).
## The same panel appears inside BaseItemType via InspectorBaseItemPreview.

func _can_handle(object: Object) -> bool:
	return object is MeleeItemDef


func _parse_begin(object: Object) -> void:
	var melee_def: MeleeItemDef = object as MeleeItemDef
	if melee_def == null:
		return

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 5)

	var title: Label = Label.new()
	title.text = "Attack Style"
	title.add_theme_font_size_override("font_size", 15)
	root.add_child(title)

	_add_option_row(root, "Swing Style",
		["SWING  (bilateral arc)", "OVERHEAD  (power slam)", "STAB  (linear thrust)"],
		int(melee_def.swing_style),
		func(idx: int) -> void:
			melee_def.swing_style = idx
			melee_def.emit_changed()
	)
	_add_spin_row(root, "Arc Degrees", melee_def.arc_degrees, 30.0, 270.0, 5.0,
		func(val: float) -> void:
			melee_def.arc_degrees = val
			melee_def.emit_changed()
	)
	_add_spin_row(root, "Shield Penetration", melee_def.shield_penetration, 0.0, 1.0, 0.05,
		func(val: float) -> void:
			melee_def.shield_penetration = val
			melee_def.emit_changed()
	)
	_add_spin_row(root, "Lunge Speed (px/s)", melee_def.lunge_speed, 0.0, 800.0, 10.0,
		func(val: float) -> void:
			melee_def.lunge_speed = val
			melee_def.emit_changed()
	)

	var save_btn: Button = Button.new()
	save_btn.text = "Save Def"
	save_btn.tooltip_text = "Saves MeleeItemDef changes to disk immediately."
	save_btn.pressed.connect(func() -> void:
		if melee_def.resource_path != "":
			ResourceSaver.save(melee_def, melee_def.resource_path)
	)
	root.add_child(save_btn)

	var sep: HSeparator = HSeparator.new()
	root.add_child(sep)

	add_custom_control(root)


func _add_option_row(parent: VBoxContainer, label_text: String, options: Array, current_idx: int, on_change: Callable) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var btn: OptionButton = OptionButton.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i: int in range(options.size()):
		btn.add_item(options[i], i)
	btn.select(clampi(current_idx, 0, options.size() - 1))
	btn.item_selected.connect(on_change)
	row.add_child(btn)


func _add_spin_row(parent: VBoxContainer, label_text: String, current_val: float, min_val: float, max_val: float, step: float, on_change: Callable) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var spin: SpinBox = SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step
	spin.value = current_val
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(on_change)
	row.add_child(spin)

@tool
extends EditorInspectorPlugin
class_name InspectorBaseItemPreview

var _editor_iface: EditorInterface


func set_editor_interface(iface: EditorInterface) -> void:
	_editor_iface = iface


func _can_handle(object: Object) -> bool:
	return object is BaseItemType or object is ItemSpawner


func _parse_begin(object: Object) -> void:
	var bt: BaseItemType = null
	var spawner: ItemSpawner = null
	var title_prefix: String = ""

	if object is BaseItemType:
		bt = object as BaseItemType
		title_prefix = "BaseItemType"
	elif object is ItemSpawner:
		spawner = object as ItemSpawner
		bt = spawner.base_type_override
		title_prefix = "ItemSpawner"

	_add_preview_panel(bt, spawner, title_prefix)
	_add_item_def_editor(bt)


# ------------------------------------------------------------
# Roll preview panel
# ------------------------------------------------------------

func _add_preview_panel(bt: BaseItemType, spawner: ItemSpawner, title_prefix: String) -> void:
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)

	var title: Label = Label.new()
	title.text = "Roll Preview"
	title.add_theme_font_size_override("font_size", 16)
	root.add_child(title)

	var row: HBoxContainer = HBoxContainer.new()
	root.add_child(row)

	var seed_label: Label = Label.new()
	seed_label.text = "Seed"
	row.add_child(seed_label)

	var seed_box: SpinBox = SpinBox.new()
	seed_box.min_value = 0
	seed_box.max_value = 2147483647
	seed_box.step = 1
	seed_box.value = 12345
	seed_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(seed_box)

	var roll_btn: Button = Button.new()
	roll_btn.text = "Roll"
	row.add_child(roll_btn)

	var copy_btn: Button = Button.new()
	copy_btn.text = "Copy"
	row.add_child(copy_btn)

	var output: RichTextLabel = RichTextLabel.new()
	output.fit_content = true
	output.scroll_active = false
	output.bbcode_enabled = true
	root.add_child(output)

	var set_text: Callable = func(s: String) -> void:
		output.clear()
		output.append_text(s)

	# Use spawner-category header when no fixed base type is pinned.
	var header_text: Callable = func() -> String:
		if spawner != null and bt == null:
			return _build_spawner_header_text(spawner, title_prefix)
		return _build_header_text(bt, title_prefix)

	var do_roll: Callable = func() -> void:
		var seed_val: int = int(seed_box.value)
		var rolled_bt: BaseItemType = bt
		var inst: ItemInstance = null

		if spawner != null and bt == null:
			# Category-based: pick base type from registry, then roll.
			var result: Dictionary = ItemSpawner.roll_preview_from_seed(
				int(spawner.spawn_category), seed_val
			)
			if result.is_empty():
				set_text.call(header_text.call() + "\n[Registry missing or no entries for this category]\n")
				return
			rolled_bt = result.get("base_type") as BaseItemType
			inst     = result.get("instance")  as ItemInstance
		else:
			if rolled_bt == null:
				set_text.call(header_text.call())
				return
			inst = ItemSpawner.roll_preview(rolled_bt, seed_val)

		var text: String = header_text.call()
		if rolled_bt != null and rolled_bt != bt:
			text += "Rolled Type: %s\n" % rolled_bt.resource_path.get_file()
		text += "Seed: %d\n" % seed_val
		text += _build_mode_line(inst)
		text += _build_shield_line(inst)
		text += _build_attr_lines(inst)
		text += _build_stats_lines(inst)
		set_text.call(text)

	set_text.call(header_text.call())

	roll_btn.pressed.connect(func() -> void: do_roll.call())
	copy_btn.pressed.connect(func() -> void: DisplayServer.clipboard_set(output.get_parsed_text()))

	add_custom_control(root)


# ------------------------------------------------------------
# Item def inline editor — only shown when the def has extra
# typed properties that wouldn't otherwise be reachable here.
# ------------------------------------------------------------

func _add_item_def_editor(bt: BaseItemType) -> void:
	if bt == null or bt.item_def == null:
		return

	var melee_def: MeleeItemDef = bt.item_def as MeleeItemDef
	if melee_def != null:
		_add_melee_style_editor(melee_def)
		return


func _add_melee_style_editor(melee_def: MeleeItemDef) -> void:
	var sep: HSeparator = HSeparator.new()
	add_custom_control(sep)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 5)

	var title: Label = Label.new()
	title.text = "Attack Style  [MeleeItemDef]"
	title.add_theme_font_size_override("font_size", 14)
	root.add_child(title)

	# Swing style — OptionButton
	_add_option_row(root, "Swing Style",
		["SWING  (bilateral arc, fully blocked)", "OVERHEAD  (power slam, partial block)", "STAB  (linear thrust, bypasses shield)"],
		int(melee_def.swing_style),
		func(idx: int) -> void:
			melee_def.swing_style = idx
			melee_def.emit_changed()
	)

	# Arc degrees — only meaningful for SWING / OVERHEAD
	_add_spin_row(root, "Arc Degrees", melee_def.arc_degrees, 30.0, 270.0, 5.0,
		func(val: float) -> void:
			melee_def.arc_degrees = val
			melee_def.emit_changed()
	)

	# Shield penetration
	_add_spin_row(root, "Shield Penetration", melee_def.shield_penetration, 0.0, 1.0, 0.05,
		func(val: float) -> void:
			melee_def.shield_penetration = val
			melee_def.emit_changed()
	)

	# Lunge speed
	_add_spin_row(root, "Lunge Speed (px/s)", melee_def.lunge_speed, 0.0, 800.0, 10.0,
		func(val: float) -> void:
			melee_def.lunge_speed = val
			melee_def.emit_changed()
	)

	# Save button — explicitly persists the def .tres file
	var save_btn: Button = Button.new()
	save_btn.text = "Save Def"
	save_btn.tooltip_text = "Saves MeleeItemDef changes to disk immediately."
	save_btn.pressed.connect(func() -> void:
		if melee_def.resource_path != "":
			ResourceSaver.save(melee_def, melee_def.resource_path)
	)
	root.add_child(save_btn)

	add_custom_control(root)


# --- Reusable row builders ---

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


# ------------------------------------------------------------
# Text builders


func _build_spawner_header_text(spawner: ItemSpawner, title_prefix: String) -> String:
	var cat_name: String = ItemSpawner.SpawnCategory.keys()[spawner.spawn_category]
	var s: String = "%s preview\n" % title_prefix
	s += "Category: %s\n" % cat_name
	s += "Base Type: <rolls from registry>\n"
	return s
# ------------------------------------------------------------

func _build_header_text(bt: BaseItemType, title_prefix: String) -> String:
	var s: String = ""
	s += "%s preview\n" % title_prefix

	if bt == null:
		s += "Base Type: <missing>\n"
		s += "\nAssign a BaseItemType to preview rolling.\n"
		return s

	var bt_name: String = bt.resource_path.get_file() if bt.resource_path != "" else "BaseItemType"
	s += "Base Type: %s\n" % bt_name

	var def: ItemDef = bt.item_def
	if def == null:
		s += "Item Def: <null>\n"
	else:
		var def_name: String = def.resource_path.get_file() if def.resource_path != "" else def.display_name
		s += "Item Def: %s\n" % def_name

		var cat: String = "Any"
		match int(def.category):
			ItemDef.Category.MELEE:
				cat = "MELEE"
			ItemDef.Category.RANGED:
				cat = "RANGED"
			ItemDef.Category.SPELL:
				cat = "SPELL"
			ItemDef.Category.SHIELD:
				cat = "SHIELD"
			_:
				cat = "Any"
		s += "Category: %s\n" % cat

	var token: String = String(bt.auto_weapon_token)
	if token != "":
		s += "Token: %s\n" % token

	s += "Attr Count: %d..%d\n" % [bt.min_attribute_count, bt.max_attribute_count]
	return s


func _build_mode_line(inst: ItemInstance) -> String:
	if inst == null:
		return "Mode: <n/a>\n"
	if inst.def == null or int(inst.def.category) != ItemDef.Category.RANGED:
		return ""
	var mode: int = int(RangedShotData.ShotMode.PROJECTILE)
	if int(inst.ranged_mode) >= 0:
		mode = int(inst.ranged_mode)
	return "Mode: %s\n" % _mode_to_string(mode)


func _build_shield_line(inst: ItemInstance) -> String:
	if inst == null or inst.def == null:
		return ""
	if int(inst.def.category) != ItemDef.Category.SHIELD:
		return ""
	var shield_def: ShieldItemDef = inst.def as ShieldItemDef
	if shield_def == null:
		return ""
	var shield_type: String = ShieldItemDef.ShieldType.keys()[shield_def.shield_type]
	return "Shield Type: %s\n" % shield_type


func _build_attr_lines(inst: ItemInstance) -> String:
	if inst == null:
		return "\nAttributes:\n  <none>\n"

	var attrs: Array[ItemAttribute] = []
	for v: Variant in inst.attributes:
		if v is ItemAttribute:
			attrs.append(v as ItemAttribute)

	if attrs.is_empty():
		return "\nAttributes:\n  <none>\n"

	attrs.sort_custom(func(a: ItemAttribute, b: ItemAttribute) -> bool:
		var aid: String = String(a.id)
		var bid: String = String(b.id)
		if aid != bid:
			return aid < bid
		return a.resource_path.get_file() < b.resource_path.get_file()
	)

	var s: String = "\nAttributes:\n"
	for a: ItemAttribute in attrs:
		var label: String = ""
		if a.display_name != "":
			label = a.display_name
		elif a.id != &"":
			label = String(a.id)
		else:
			label = a.resource_path.get_file()
		s += "  • %s  [%s]\n" % [label, a.resource_path.get_file()]
	return s


func _build_stats_lines(inst: ItemInstance) -> String:
	if inst == null:
		return "\nStats:\n  <n/a>\n"
	if not inst.has_method(&"compute_stats"):
		return "\nStats:\n  <unavailable>\n"

	var stats_v: Variant = inst.call(&"compute_stats", null)
	if stats_v == null or not (stats_v is ItemStats):
		return "\nStats:\n  <unavailable>\n"

	var stats: ItemStats = stats_v as ItemStats
	var s: String = "\nStats:\n"

	# Shield items use ShieldItemDef for most display properties.
	if inst.def != null and int(inst.def.category) == ItemDef.Category.SHIELD:
		var shield_def: ShieldItemDef = inst.def as ShieldItemDef
		if shield_def != null:
			match shield_def.shield_type:
				ShieldItemDef.ShieldType.ACTIVE:
					s += "  Block Damage Reduction: %.0f%%\n" % (shield_def.block_damage_reduction * 100.0)
					s += "  Movement Speed While Blocking: %.0f%%\n" % (shield_def.movement_speed_mult_while_blocking * 100.0)
					if shield_def.shield_max_hp > 0.0:
						s += "  Shield HP: %.0f  (regen %.1f/s after %.1fs)\n" % [
							shield_def.shield_max_hp, shield_def.shield_regen_rate, shield_def.shield_regen_delay
						]
				ShieldItemDef.ShieldType.PASSIVE:
					s += "  Damage Reduction: %.0f%%\n" % (shield_def.passive_damage_reduction_mult * 100.0)
					s += "  Movement Speed: %.0f%%\n" % (shield_def.passive_movement_speed_mult * 100.0)
					var flat_dr: float = shield_def.stats.flat_damage_reduction if shield_def.stats != null else 0.0
					if not is_equal_approx(flat_dr, 0.0):
						s += "  Flat Damage Reduction: %.1f\n" % flat_dr
			return s

	# Melee items: show style info + relevant stats.
	if inst.def != null and int(inst.def.category) == ItemDef.Category.MELEE:
		var melee_def: MeleeItemDef = inst.def as MeleeItemDef
		if melee_def != null:
			s += "  Style: %s  |  Arc: %.0f°  |  Penetration: %.0f%%  |  Lunge: %.0f\n" % [
				_swing_style_name(int(melee_def.swing_style)),
				melee_def.arc_degrees,
				melee_def.shield_penetration * 100.0,
				melee_def.lunge_speed,
			]

	# Numeric stat fields (skip internal / metadata fields).
	for p: Dictionary in stats.get_property_list():
		var n: StringName = p.name
		var ns: String = String(n)
		if ns.begins_with("_"):
			continue
		if n == &"resource_name" or n == &"resource_path":
			continue
		var v: Variant = stats.get(n)
		var t: int = typeof(v)
		if t == TYPE_INT or t == TYPE_FLOAT or t == TYPE_VECTOR2 or t == TYPE_VECTOR2I:
			s += "  %s: %s\n" % [ns, str(v)]

	if s == "\nStats:\n" or s == "\nStats:\n  Style: %s\n" % "":
		s += "  <no numeric fields>\n"

	return s


func _mode_to_string(mode: int) -> String:
	match mode:
		RangedShotData.ShotMode.PROJECTILE:
			return "PROJECTILE"
		RangedShotData.ShotMode.HITSCAN:
			return "HITSCAN"
		RangedShotData.ShotMode.BEAM:
			return "BEAM"
		_:
			return "UNKNOWN(%d)" % mode


func _swing_style_name(style: int) -> String:
	match style:
		0: return "SWING"
		1: return "OVERHEAD"
		2: return "STAB"
		_: return "UNKNOWN(%d)" % style

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
	var title_prefix: String = ""

	if object is BaseItemType:
		bt = object as BaseItemType
		title_prefix = "BaseItemType"
	elif object is ItemSpawner:
		var sp: ItemSpawner = object as ItemSpawner
		bt = sp.base_type
		title_prefix = "ItemSpawner"

	_add_preview_panel(bt, title_prefix)


# ------------------------------------------------------------
# UI construction
# ------------------------------------------------------------

func _add_preview_panel(bt: BaseItemType, title_prefix: String) -> void:
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

	# Lambdas must be assigned to variables in Godot 4 (no nested funcs).
	var set_text: Callable = func(s: String) -> void:
		output.clear()
		output.append_text(s)

	var header_text: Callable = func() -> String:
		return _build_header_text(bt, title_prefix)

	var do_roll: Callable = func() -> void:
		if bt == null:
			set_text.call(header_text.call())
			return

		var seed: int = int(seed_box.value)
		var inst: ItemInstance = ItemSpawner.roll_preview(bt, seed)

		var text: String = ""
		text += header_text.call()
		text += "Seed: %d\n" % seed
		text += _build_mode_line(inst)
		text += _build_shield_line(inst)
		text += _build_attr_lines(inst)
		text += _build_stats_lines(inst)

		set_text.call(text)

	# Initial render
	set_text.call(header_text.call())

	roll_btn.pressed.connect(func() -> void:
		do_roll.call()
	)

	copy_btn.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(output.get_parsed_text())
	)

	add_custom_control(root)


# ------------------------------------------------------------
# Text builders (top-level methods, tool-safe)
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

	# Tool-safe: read export directly; do NOT call methods on placeholder instances.
	# BaseItemType has @export var auto_weapon_token
	var token: String = ""
	token = String(bt.auto_weapon_token)
	if token != "":
		s += "Token: %s\n" % token

	s += "Attr Count: %d..%d\n" % [bt.min_attribute_count, bt.max_attribute_count]
	return s


func _build_mode_line(inst: ItemInstance) -> String:
	if inst == null:
		return "Mode: <n/a>\n"

	# Only show mode for ranged items
	if inst.def == null or int(inst.def.category) != ItemDef.Category.RANGED:
		return ""

	var mode: int = int(RangedShotData.ShotMode.PROJECTILE)
	if int(inst.ranged_mode) >= 0:
		mode = int(inst.ranged_mode)
	return "Mode: %s\n" % _mode_to_string(mode)


func _build_shield_line(inst: ItemInstance) -> String:
	"""Display shield type for shield items"""
	if inst == null or inst.def == null:
		return ""

	# Only show for shields
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

	# Special handling for shields
	if inst.def != null and int(inst.def.category) == ItemDef.Category.SHIELD:
		var shield_def: ShieldItemDef = inst.def as ShieldItemDef
		if shield_def != null:
			match shield_def.shield_type:
				ShieldItemDef.ShieldType.ACTIVE:
					s += "  Block Damage Reduction: %.0f%%\n" % (shield_def.block_damage_reduction * 100.0)
					s += "  Movement Speed While Blocking: %.0f%%\n" % (shield_def.movement_speed_mult_while_blocking * 100.0)
				
				ShieldItemDef.ShieldType.PASSIVE:
					s += "  Damage Reduction: %.0f%%\n" % (shield_def.passive_damage_reduction_mult * 100.0)
					s += "  Movement Speed: %.0f%%\n" % (shield_def.passive_movement_speed_mult * 100.0)
					if not is_equal_approx(shield_def.flat_damage_reduction, 0.0):
						s += "  Flat Damage Reduction: %.1f\n" % shield_def.flat_damage_reduction
			return s

	# Standard stat display for non-shields
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

	if s == "\nStats:\n":
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

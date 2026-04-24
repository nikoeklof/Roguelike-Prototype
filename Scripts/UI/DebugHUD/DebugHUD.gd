extends CanvasLayer
class_name DebugHUD

@export var player_root_path: NodePath
@export var toggle_action: StringName = &"ui_debug_toggle"
@export_range(0.01, 0.5, 0.01) var update_tick_rate: float = 0.1

@onready var tab_bar: HBoxContainer = %TabBar
@onready var info_label: RichTextLabel = %InfoLabel
@onready var inventory_container: VBoxContainer = %InventoryContainer
@onready var equip_list: ItemList = %EquipList
@onready var details: RichTextLabel = %Details

const TAB_INVENTORY := 4

var _player: Node2D = null
var _equipment: Equipment = null
var _stats: Stats = null
var _passive_shield_activator: PassiveShieldAttributeActivator = null

var _sections: Array[DebugHUDSection] = []
var _active_tab: int = 0
var _update_timer: float = 0.0
var _last_output: String = ""


func _ready() -> void:
	_collect_sections()
	_bind_player()
	_wire_tabs()
	_wire_inventory_ui()
	_apply_font_sizes()
	call_deferred("_refresh_inventory")
	_update_tab_highlights()


func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= update_tick_rate:
		_update_timer = 0.0
		_rebuild_display()


func _unhandled_input(event: InputEvent) -> void:
	if toggle_action == StringName():
		return
	if not InputMap.has_action(toggle_action):
		return
	if event.is_action_pressed(toggle_action):
		visible = not visible


# -------------------------
# Section discovery
# -------------------------

func _collect_sections() -> void:
	_sections.clear()
	for child: Node in get_children():
		if child is DebugHUDSection:
			_sections.append(child as DebugHUDSection)


# -------------------------
# Tab wiring
# -------------------------

func _wire_tabs() -> void:
	if tab_bar == null:
		return
	var buttons: Array[Node] = tab_bar.get_children()
	for i: int in buttons.size():
		var btn: Button = buttons[i] as Button
		if btn == null:
			continue
		btn.pressed.connect(_on_tab_pressed.bind(i))


func _on_tab_pressed(idx: int) -> void:
	_active_tab = idx
	_last_output = ""
	_rebuild_display()
	_update_tab_highlights()


func _update_tab_highlights() -> void:
	if tab_bar == null:
		return
	var buttons: Array[Node] = tab_bar.get_children()
	for i: int in buttons.size():
		var btn: Button = buttons[i] as Button
		if btn == null:
			continue
		btn.flat = (i != _active_tab)


# -------------------------
# Display rebuild
# -------------------------

func _rebuild_display() -> void:
	var is_inventory := (_active_tab == TAB_INVENTORY)
	info_label.visible = not is_inventory
	inventory_container.visible = is_inventory

	if is_inventory:
		return

	if info_label == null:
		return

	var section_idx: int = _active_tab
	if section_idx < 0 or section_idx >= _sections.size():
		info_label.clear()
		return

	var ctx: DebugHUDContext = _build_context()
	var section: DebugHUDSection = _sections[section_idx]
	var body: String = section.build_text(ctx)

	var output: String = ""
	if not body.is_empty():
		output = "[b]%s[/b]\n" % section.section_name()
		output += body

	if output == _last_output:
		return
	_last_output = output

	info_label.clear()
	info_label.append_text(output)


func _build_context() -> DebugHUDContext:
	var ctx := DebugHUDContext.new()
	ctx.player = _player
	ctx.player_equipment = _equipment
	ctx.player_stats = _stats
	ctx.player_passive_shield = _passive_shield_activator
	ctx.tree = get_tree()

	if _player != null:
		ctx.player_health = _player.get_node_or_null("Health") as Health

	ctx.enemies = _find_enemies()
	return ctx


func _find_enemies() -> Array[Node]:
	var enemies: Array[Node] = []
	if get_tree() == null:
		return enemies

	for node: Node in get_tree().get_nodes_in_group("enemy"):
		enemies.append(node)

	if enemies.is_empty():
		_scan_for_enemy_ai(get_tree().root, enemies)

	return enemies


func _scan_for_enemy_ai(root: Node, out: Array[Node]) -> void:
	if root == null:
		return
	for child: Node in root.get_children():
		if child is EnemyAI:
			var entity: Node = child.get_parent()
			if entity != null and not out.has(entity):
				out.append(entity)
		_scan_for_enemy_ai(child, out)


# -------------------------
# Binding
# -------------------------

func _bind_player() -> void:
	if player_root_path != NodePath():
		_player = get_node_or_null(player_root_path) as Node2D
	else:
		_player = get_tree().get_first_node_in_group("player") as Node2D

	if _player == null:
		push_warning("DebugHUD: Player not found.")
		return

	var eq_node: Node = _player.get_node_or_null("Equipment")
	_equipment = eq_node as Equipment
	if _equipment == null:
		push_warning("DebugHUD: Player has no Equipment.")
		return

	_stats = _player.get_node_or_null("Stats") as Stats
	_passive_shield_activator = _player.get_node_or_null("PassiveShieldAttributeActivator") as PassiveShieldAttributeActivator

	if _equipment != null and not _equipment.active_slot_changed.is_connected(_on_equipment_changed):
		_equipment.active_slot_changed.connect(_on_equipment_changed)

	_connect_slot_changed(_equipment.melee_slot_path)
	_connect_slot_changed(_equipment.ranged_slot_path)
	_connect_slot_changed(_equipment.spell_slot_path)
	_connect_slot_changed(_equipment.shield_slot_path)


func _connect_slot_changed(path: NodePath) -> void:
	if _equipment == null or path == NodePath(""):
		return
	var slot_node: Node = _equipment.get_node_or_null(path)
	if slot_node == null:
		return
	if slot_node.has_signal("changed") and not slot_node.is_connected("changed", _on_slot_changed):
		slot_node.connect("changed", _on_slot_changed)


func _wire_inventory_ui() -> void:
	if equip_list != null and not equip_list.item_selected.is_connected(_on_item_selected):
		equip_list.item_selected.connect(_on_item_selected)


# -------------------------
# Font sizes
# -------------------------

func _apply_font_sizes() -> void:
	var label_font_size := 11
	var btn_font_size := 10
	var list_font_size := 11

	if info_label != null:
		info_label.add_theme_font_size_override("normal_font_size", label_font_size)
		info_label.add_theme_font_size_override("bold_font_size", label_font_size)

	if details != null:
		details.add_theme_font_size_override("normal_font_size", label_font_size)
		details.add_theme_font_size_override("bold_font_size", label_font_size)

	if equip_list != null:
		equip_list.add_theme_font_size_override("font_size", list_font_size)

	if tab_bar != null:
		for child: Node in tab_bar.get_children():
			var btn: Button = child as Button
			if btn != null:
				btn.add_theme_font_size_override("font_size", btn_font_size)


# -------------------------
# Inventory panel
# -------------------------

func _on_equipment_changed(_prev: int, _new: int, _reason: String) -> void:
	_refresh_inventory()

func _on_slot_changed(_new_item: Node, _old_item: Node) -> void:
	_refresh_inventory()

func _refresh_inventory() -> void:
	if equip_list == null or details == null:
		return

	equip_list.clear()
	details.clear()

	if _equipment == null:
		return

	var equipped: Dictionary[String, Node] = _equipment.get_equipped_items_debug()
	if equipped.is_empty():
		return

	var keys: Array[String] = []
	for k in equipped.keys():
		keys.append(str(k))
	keys.sort()

	equip_list.set_meta("slot_keys", keys)

	for k: String in keys:
		var item: Node = equipped.get(k)
		if item == null:
			equip_list.add_item("%s: (empty)" % k)
		else:
			equip_list.add_item("%s: %s" % [k, _get_item_display_name(item)])


func _get_item_display_name(item: Node) -> String:
	if item.has_method("get_item_instance"):
		var inst: ItemInstance = item.call("get_item_instance") as ItemInstance
		if inst != null and inst.def != null:
			var display: String = inst.def.display_name.strip_edges()
			if not display.is_empty():
				var rarity: int = inst.attributes.size()
				if rarity > 0:
					return "%s [%d attr]" % [display, rarity]
				return display

	if "item_def" in item:
		var def: ItemDef = item.get("item_def") as ItemDef
		if def != null:
			var display: String = def.display_name.strip_edges()
			if not display.is_empty():
				return display

	return str(item.name)


func _on_item_selected(index: int) -> void:
	if details == null:
		return
	details.clear()

	if _equipment == null:
		return

	var keys: Array[String] = []
	if equip_list.has_meta("slot_keys"):
		keys = equip_list.get_meta("slot_keys") as Array[String]

	if index < 0 or index >= keys.size():
		return

	var equipped: Dictionary[String, Node] = _equipment.get_equipped_items_debug()
	var slot_name: String = keys[index]
	var item: Node = equipped.get(slot_name)

	if item == null:
		details.append_text("Empty slot.")
		return

	details.append_text(ItemTooltipFormatter.format_expanded(item))

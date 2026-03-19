extends CanvasLayer
class_name DebugHUD

@export var floor_spawner_path: NodePath
@export var player_root_path: NodePath
@export var toggle_action: StringName = &"ui_debug_toggle"
@export_range(0.01, 0.5, 0.01) var update_tick_rate: float = 0.1

@onready var minimap: MinimapControl = %Minimap
@onready var seed_label: Label = %SeedLabel
@onready var equip_list: ItemList = %EquipList
@onready var details: RichTextLabel = %Details

var _floor_spawner: Node = null
var _player: Node2D = null
var _equipment: Equipment = null
var _stats: Stats = null

var _update_timer: float = 0.0
var _last_move_speed: float = 0.0
var _last_cooldown: float = -1.0
var _last_buffs: String = ""

# Track buff durations
var _buff_timers: Dictionary = {}  # key -> end_time


func _ready() -> void:
	_bind_floor_spawner()
	_bind_player()
	_wire_ui()

	call_deferred("_pull_existing_floor_plan")
	call_deferred("_refresh_inventory")


func _process(delta: float) -> void:
	if minimap == null:
		return
	if _player == null:
		return

	minimap.set_player_cell(_world_to_cell(_player.global_position))
	
	_update_timer += delta
	if _update_timer >= update_tick_rate:
		_update_timer = 0.0
		_update_realtime_values()


func _unhandled_input(event: InputEvent) -> void:
	if toggle_action == StringName():
		return
	if not InputMap.has_action(toggle_action):
		return
	if event.is_action_pressed(toggle_action):
		visible = not visible


# -------------------------
# Binding
# -------------------------

func _bind_floor_spawner() -> void:
	if floor_spawner_path != NodePath():
		_floor_spawner = get_node_or_null(floor_spawner_path)
	else:
		_floor_spawner = get_tree().get_first_node_in_group("floor_spawner")

	if _floor_spawner == null:
		push_warning("DebugHUD: FloorSpawner not found.")
		return

	if _floor_spawner.has_signal("floor_plan_generated"):
		if not _floor_spawner.is_connected("floor_plan_generated", _on_floor_plan_generated):
			_floor_spawner.connect("floor_plan_generated", _on_floor_plan_generated)
	else:
		push_warning("DebugHUD: FloorSpawner has no signal 'floor_plan_generated'.")


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
		push_warning("DebugHUD: Player has no Equipment (or wrong type).")
		return

	_stats = _player.get_node_or_null("Stats") as Stats
	if _stats == null:
		push_warning("DebugHUD: Player has no Stats component.")
		return

	if not _stats.changed.is_connected(_on_stats_changed):
		_stats.changed.connect(_on_stats_changed)

	if not _equipment.active_slot_changed.is_connected(_on_equipment_changed):
		_equipment.active_slot_changed.connect(_on_equipment_changed)

	_connect_slot_changed(_equipment.melee_slot_path)
	_connect_slot_changed(_equipment.ranged_slot_path)
	_connect_slot_changed(_equipment.spell_slot_path)
	_connect_slot_changed(_equipment.shield_slot_path)
	
	_update_stats_display()


func _connect_slot_changed(path: NodePath) -> void:
	if _equipment == null:
		return
	if path == NodePath(""):
		return

	var slot_node: Node = _equipment.get_node_or_null(path)
	if slot_node == null:
		return

	if slot_node.has_signal("changed"):
		if not slot_node.is_connected("changed", _on_slot_changed):
			slot_node.connect("changed", _on_slot_changed)


func _wire_ui() -> void:
	if equip_list == null:
		return
	if not equip_list.item_selected.is_connected(_on_item_selected):
		equip_list.item_selected.connect(_on_item_selected)


# -------------------------
# Floor plan
# -------------------------

func _pull_existing_floor_plan() -> void:
	if _floor_spawner == null:
		return
	if _floor_spawner.has_method("get_floor_plan"):
		var plan: Variant = _floor_spawner.call("get_floor_plan")
		if plan != null:
			_on_floor_plan_generated(plan)


func _on_floor_plan_generated(plan: FloorGenerator.FloorPlan) -> void:
	print("[DebugHUD] got floor plan. coords=", plan.coords.size())
	if minimap != null:
		minimap.set_floor_plan(plan)
	if seed_label != null:
		var seed_text: String = "Seed: %d" % int(plan.seed)
		if seed_label.text.contains("\n"):
			var lines: PackedStringArray = seed_label.text.split("\n")
			lines[0] = seed_text
			seed_label.text = "\n".join(lines)
		else:
			seed_label.text = seed_text


# -------------------------
# Stats Display
# -------------------------

func _on_stats_changed() -> void:
	_update_stats_display()


func _update_realtime_values() -> void:
	"""Update only the values that change frequently"""
	if _stats == null or seed_label == null:
		return
	
	var base_move_speed: float = 250.0
	var current_move_speed: float = base_move_speed * _stats.move_speed_mult()
	var cooldown_remaining: float = _stats.get_spell_cooldown_remaining()
	var buffs_text: String = _get_active_buffs_text()
	
	# Only update if something actually changed
	if current_move_speed == _last_move_speed and cooldown_remaining == _last_cooldown and buffs_text == _last_buffs:
		return
	
	_last_move_speed = current_move_speed
	_last_cooldown = cooldown_remaining
	_last_buffs = buffs_text
	
	# Rebuild ONLY the stats text, keep seed
	var text: String = ""
	if seed_label.text.begins_with("Seed:"):
		var first_line: String = seed_label.text.split("\n")[0]
		text = first_line
	else:
		text = "Seed: 0"
	
	text += "\n\nMovement Speed Mult: %.2fx" % _stats.move_speed_mult()
	text += "\nEffective Move Speed: %.1f" % current_move_speed
	text += "\nAccel Mult: %.2fx" % _stats.accel_mult()
	text += "\nFriction Mult: %.2fx" % _stats.friction_mult()
	text += "\n\nAttack Speed Mult: %.2fx" % _stats.attack_speed_mult()
	text += "\nDamage Taken Mult: %.2fx" % _stats.damage_taken_mult()
	text += "\nFlat Damage Reduction: %.1f" % _stats.flat_damage_reduction()
	text += "\n\nSpell Cooldown: "
	if cooldown_remaining > 0.0:
		text += "%.2fs" % cooldown_remaining
	else:
		text += "Ready"
	text += buffs_text
	
	seed_label.text = text


func _update_stats_display() -> void:
	"""Full update when stats change"""
	if _stats == null or seed_label == null:
		return
	
	var base_move_speed: float = 250.0
	var effective_move_speed: float = base_move_speed * _stats.move_speed_mult()
	
	var stats_text: String = "Seed: 0"
	if seed_label.text.begins_with("Seed:"):
		var first_line: String = seed_label.text.split("\n")[0]
		stats_text = first_line
	
	stats_text += "\n\nMovement Speed Mult: %.2fx" % _stats.move_speed_mult()
	stats_text += "\nEffective Move Speed: %.1f" % effective_move_speed
	stats_text += "\nAccel Mult: %.2fx" % _stats.accel_mult()
	stats_text += "\nFriction Mult: %.2fx" % _stats.friction_mult()
	stats_text += "\n\nAttack Speed Mult: %.2fx" % _stats.attack_speed_mult()
	stats_text += "\nDamage Taken Mult: %.2fx" % _stats.damage_taken_mult()
	stats_text += "\nFlat Damage Reduction: %.1f" % _stats.flat_damage_reduction()
	
	var cooldown_remaining := _stats.get_spell_cooldown_remaining()
	stats_text += "\n\nSpell Cooldown: "
	if cooldown_remaining > 0.0:
		stats_text += "%.2fs" % cooldown_remaining
	else:
		stats_text += "Ready"
	
	stats_text += _get_active_buffs_text()
	
	seed_label.text = stats_text
	_last_move_speed = base_move_speed * _stats.move_speed_mult()
	_last_cooldown = cooldown_remaining
	_last_buffs = _get_active_buffs_text()


func _get_active_buffs_text() -> String:
	var buffs: Array[String] = []
	var now: float = Time.get_ticks_msec() / 1000.0
	
	# Collect all active buff keys with their remaining durations
	_collect_buffs_with_duration(buffs, _stats._move_speed_mult_mods, now)
	_collect_buffs_with_duration(buffs, _stats._accel_mult_mods, now)
	_collect_buffs_with_duration(buffs, _stats._friction_mult_mods, now)
	_collect_buffs_with_duration(buffs, _stats._attack_speed_mult_mods, now)
	_collect_buffs_with_duration(buffs, _stats._damage_taken_mult_mods, now)
	_collect_buffs_with_duration(buffs, _stats._flat_damage_reduction_mods, now)
	_collect_buffs_with_duration(buffs, _stats._melee_damage_mult_mods, now)
	_collect_buffs_with_duration(buffs, _stats._ranged_damage_mult_mods, now)
	
	if buffs.is_empty():
		return "\n\nActive Buffs: (none)"
	
	# Remove duplicates using a dictionary
	var unique_buffs: Dictionary = {}
	for buff: String in buffs:
		unique_buffs[buff] = true
	
	# Convert back to Array[String] and sort
	var sorted_buffs: Array[String] = []
	for buff_name: String in unique_buffs.keys():
		sorted_buffs.append(buff_name)
	sorted_buffs.sort()
	
	var text: String = "\n\nActive Buffs:"
	for buff: String in sorted_buffs:
		# Extract buff name and get remaining duration
		var remaining: float = _buff_timers.get(buff, 0.0) - now
		if remaining > 0.0:
			text += "\n  • %s (%.1fs)" % [buff, remaining]
		else:
			text += "\n  • %s" % buff
	
	return text


func _collect_buffs_with_duration(buffs: Array[String], mods: Dictionary, now: float) -> void:
	for key: StringName in mods.keys():
		var buff_name: String = str(key)
		buffs.append(buff_name)
		
		# If this is a new buff, estimate its duration based on buff type
		if not _buff_timers.has(buff_name):
			# Default duration estimates based on buff key patterns
			var duration: float = 5.0  # Default
			if "battle_trance" in buff_name:
				duration = 5.0
			elif "stone_skin" in buff_name:
				duration = 6.0
			# Add more patterns as needed
			_buff_timers[buff_name] = now + duration
		
		# Remove expired timers
		if _buff_timers[buff_name] <= now:
			_buff_timers.erase(buff_name)


# -------------------------
# Inventory
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
			var item_name: String = "(unnamed)"
			if item.get("name") != null:
				item_name = str(item.get("name"))
			equip_list.add_item("%s: %s" % [k, item_name])

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

	var item_name: String = "(unnamed)"
	if item.get("name") != null:
		item_name = str(item.get("name"))

	details.append_text("[b]%s[/b]\n\n" % item_name)

	for p in item.get_property_list():
		if typeof(p) == TYPE_DICTIONARY and p.has("usage") and p.has("name"):
			var usage: int = int(p["usage"])
			if usage & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
				var prop_name: String = str(p["name"])
				var value: Variant = item.get(prop_name)
				details.append_text("%s: %s\n" % [prop_name, str(value)])


# -------------------------
# Helpers
# -------------------------

func _world_to_cell(world_pos: Vector2) -> Vector2i:
	const CELL_SIZE_WORLD: float = 528.0
	return Vector2i(
		roundi(world_pos.x / CELL_SIZE_WORLD),
		roundi(world_pos.y / CELL_SIZE_WORLD)
	)

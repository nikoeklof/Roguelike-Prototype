extends Node2D
class_name FloorSpawner

signal floor_spawned(start_room: Node2D)
signal floor_plan_generated(plan: FloorGenerator.FloorPlan)
signal player_room_changed(coord: Vector2i)

@export var room_scene: PackedScene
@export var room_database: RoomDatabase
@export var xl_room_database: RoomDatabase
@export_range(0.0, 1.0, 0.05) var xl_room_chance: float = 0.25

# --------------------------------------------------
# Layout databases (gameplay layer on top of shells)
# --------------------------------------------------
@export var layout_database: RoomLayoutDatabase
@export var xl_layout_database: RoomLayoutDatabase

# --------------------------------------------------
# Floor theming
# --------------------------------------------------
@export var floor_depth: int = 1
@export var themes: Array[FloorTheme] = []

# --------------------------------------------------
# Seed control
# --------------------------------------------------
@export var randomize_seed: bool = true
@export var seed: int = 12345
@export var print_seed_to_console: bool = true

var runtime_seed: int = 0

# --------------------------------------------------
# Floor size
# --------------------------------------------------
@export var main_len: int = 18

@export_range(0.0, 2.0, 0.05) var branch_density: float = 0.35
@export_range(0.0, 1.0, 0.05) var branch_len_ratio: float = 0.35
@export_range(1, 10, 1) var branch_len_min: int = 2
@export_range(1, 30, 1) var branch_len_max_cap: int = 8

@export_range(0.0, 10.0, 0.1) var clump_penalty: float = 3.0
@export_range(0.0, 5.0, 0.05) var straight_bias: float = 0.9
@export_range(0, 3, 1) var min_separation: int = 1

# Debug minimap (world space one)
@export var draw_debug_minimap: bool = true
@export var minimap_cell_px: int = 24
@export var minimap_offset: Vector2 = Vector2(16, 16)

# Player placement
@export var player_path: NodePath
@export var player_spawn_marker_name: StringName = &"PlayerSpawn"

# Doors
@export var apply_door_colliders: bool = true
@export var door_scene: PackedScene

const ROOM_SIZE: Vector2i = Vector2i(800, 800)
const XL_ROOM_SIZE: Vector2i = Vector2i(1600, 1600)

var _gen: FloorGenerator
var _plan: FloorGenerator.FloorPlan
var _room_instances: Dictionary = {}
var _used_layout_paths: Array[String] = []
var _used_xl_layout_paths: Array[String] = []

# If true, the FloorSpawner will find ItemSpawner nodes inside each room and
# call spawn_with_run_seed(runtime_seed) deterministically.
@export var spawn_room_items: bool = true

@export var spawn_room_enemies: bool = true
@export var enemy_scenes: Array[PackedScene] = []
@export_range(0.0, 1.0, 0.05) var combat_chance: float = 0.6
@export_range(0.0, 1.0, 0.05) var boss_combat_chance: float = 1.0


# --------------------------------------------------

func _ready() -> void:
	add_to_group("floor_spawner")

	if room_scene == null and room_database == null:
		push_error("FloorSpawner: set room_scene OR room_database.")
		return

	if room_database != null:
		room_database.rebuild()
		print(room_database.debug_summary())

	if xl_room_database != null:
		xl_room_database.rebuild()
		print(xl_room_database.debug_summary())

	if layout_database != null:
		layout_database.rebuild()
		print(layout_database.debug_summary())

	if xl_layout_database != null:
		xl_layout_database.rebuild()
		print(xl_layout_database.debug_summary())

	# ---- seed selection ----
	runtime_seed = seed
	if randomize_seed:
		var unix_time: int = int(Time.get_unix_time_from_system())
		var frames: int = int(Engine.get_frames_drawn())
		runtime_seed = unix_time ^ frames

	if print_seed_to_console:
		print("FLOOR SEED: ", runtime_seed)

	# ---- generation ----
	_gen = FloorGenerator.new()

	_plan = _gen.generate(
		runtime_seed,
		main_len,
		branch_density,
		branch_len_ratio,
		branch_len_min,
		branch_len_max_cap,
		clump_penalty,
		straight_bias,
		min_separation,
		xl_room_chance
	)
	if _plan == null:
		push_error("FloorSpawner: generator returned NULL plan!")
		return

	_spawn(_plan)
	_place_player_in_start_room(_plan)

	# 🔹 Emit AFTER everything is ready
	floor_plan_generated.emit(_plan)
	print("Generated plan:", _plan)
	print("Coords count:", _plan.coords.size() if _plan != null else -1)
	queue_redraw()


# --------------------------------------------------
# Public API (for DebugHUD)
# --------------------------------------------------

func get_floor_plan() -> FloorGenerator.FloorPlan:
	return _plan


# --------------------------------------------------

func _spawn(plan: FloorGenerator.FloorPlan) -> void:
	for child: Node in get_children():
		child.queue_free()

	_room_instances.clear()
	_used_layout_paths.clear()
	_used_xl_layout_paths.clear()

	for coord: Vector2i in plan.coords:
		var rn: FloorGenerator.RoomNode = plan.rooms[coord] as FloorGenerator.RoomNode

		if rn.kind == &"XL_OCCUPIED":
			continue

		var is_xl: bool = rn.kind == &"XL"
		var ps: PackedScene

		if is_xl:
			if xl_room_database != null:
				var rng: RandomNumberGenerator = RandomNumberGenerator.new()
				rng.seed = _room_pick_seed(plan.seed, coord, rn.exits_mask, rn.kind)
				ps = xl_room_database.pick_scene(rn.exits_mask, rng)
		else:
			ps = room_scene
			if room_database != null:
				var rng: RandomNumberGenerator = RandomNumberGenerator.new()
				rng.seed = _room_pick_seed(plan.seed, coord, rn.exits_mask, rn.kind)
				ps = room_database.pick_scene(rn.exits_mask, rng)

		if ps == null:
			push_error("FloorSpawner: no scene for coord=%s kind=%s" % [str(coord), String(rn.kind)])
			continue

		var inst: Node2D = ps.instantiate() as Node2D
		if inst == null:
			push_error("FloorSpawner: failed to instantiate room scene.")
			continue

		add_child(inst)
		inst.position = Vector2(coord.x * float(ROOM_SIZE.x), coord.y * float(ROOM_SIZE.y))
		inst.name = "%s_%d_%d" % [String(rn.kind), coord.x, coord.y]

		if apply_door_colliders:
			if is_xl:
				_apply_door_state_xl(inst, rn.xl_exits_mask)
			else:
				_apply_door_state(inst, rn.exits_mask)

		_inject_wall_theme(inst)
		_inject_floor_theme(inst)
		_inject_door_theme(inst)
		_inject_layout(inst, rn, is_xl, coord)

		if spawn_room_items:
			_wire_item_spawners_for_room(inst, coord)

		if spawn_room_enemies and rn.kind != &"START":
			if _room_rolls_combat(coord, rn.kind):
				_setup_room_controller(inst, rn, is_xl, coord)

		_add_room_tracker(inst, coord, is_xl)
		_room_instances[coord] = inst


func _wire_item_spawners_for_room(room: Node2D, coord: Vector2i) -> void:
	# Find ItemSpawner nodes that are authored inside the room scene.
	# (Room scenes can place one or more ItemSpawner nodes, e.g. under a "Spawns" node.)
	var nodes: Array[Node] = room.find_children("", "ItemSpawner", true, false)
	if nodes.is_empty():
		return

	var spawners: Array[ItemSpawner] = []
	for n: Node in nodes:
		if n is ItemSpawner:
			spawners.append(n as ItemSpawner)

	if spawners.is_empty():
		return

	# Stable ordering: by position, then by node path.
	spawners.sort_custom(Callable(self, "_item_spawner_sort"))

	for i: int in range(spawners.size()):
		var s: ItemSpawner = spawners[i]
		s.auto_room_coord = coord
		s.auto_room_local_index = i
		s.spawn_with_run_seed(runtime_seed)


func _item_spawner_sort(a: ItemSpawner, b: ItemSpawner) -> bool:
	var pa: Vector2 = a.global_position
	var pb: Vector2 = b.global_position

	if pa.x == pb.x:
		if pa.y == pb.y:
			return String(a.get_path()) < String(b.get_path())
		return pa.y < pb.y
	return pa.x < pb.x


# --------------------------------------------------

func _apply_door_state(room: Node2D, exits_mask: int) -> void:
	if door_scene == null:
		push_error("FloorSpawner: door_scene not set.")
		return
	var doors_node := Node2D.new()
	doors_node.name = "Doors"
	room.add_child(doors_node)

	var defs := [
		["Door_N", Vector2(400, 8),   0.0,   (exits_mask & FloorGenerator.N) != 0],
		["Door_S", Vector2(400, 792), 180.0, (exits_mask & FloorGenerator.S) != 0],
		["Door_E", Vector2(792, 400), 90.0,  (exits_mask & FloorGenerator.E) != 0],
		["Door_W", Vector2(8,   400), -90.0, (exits_mask & FloorGenerator.W) != 0],
	]
	for d in defs:
		_spawn_door(doors_node, d[0], d[1], d[2], d[3])


func _apply_door_state_xl(room: Node2D, xl_mask: int) -> void:
	if door_scene == null:
		push_error("FloorSpawner: door_scene not set.")
		return
	var doors_node := Node2D.new()
	doors_node.name = "Doors"
	room.add_child(doors_node)

	var defs := [
		["Door_N1", Vector2(400,  8),    0.0,   (xl_mask & FloorGenerator.XL_N1) != 0],
		["Door_N2", Vector2(1200, 8),    0.0,   (xl_mask & FloorGenerator.XL_N2) != 0],
		["Door_S1", Vector2(400,  1592), 180.0, (xl_mask & FloorGenerator.XL_S1) != 0],
		["Door_S2", Vector2(1200, 1592), 180.0, (xl_mask & FloorGenerator.XL_S2) != 0],
		["Door_E1", Vector2(1592, 400),  90.0,  (xl_mask & FloorGenerator.XL_E1) != 0],
		["Door_E2", Vector2(1592, 1200), 90.0,  (xl_mask & FloorGenerator.XL_E2) != 0],
		["Door_W1", Vector2(8,    400),  -90.0, (xl_mask & FloorGenerator.XL_W1) != 0],
		["Door_W2", Vector2(8,    1200), -90.0, (xl_mask & FloorGenerator.XL_W2) != 0],
	]
	for d in defs:
		_spawn_door(doors_node, d[0], d[1], d[2], d[3])


func _spawn_door(parent: Node2D, door_name: String, pos: Vector2, rot_deg: float, is_exit: bool) -> void:
	var door := door_scene.instantiate() as Door
	door.name = door_name
	door.position = pos
	door.rotation_degrees = rot_deg
	door.initial_state = Door.DoorState.OPEN if is_exit else Door.DoorState.CLOSED
	parent.add_child(door)
	if is_exit:
		door.open()
	else:
		door.close()


# --------------------------------------------------
# Theme + layout injection
# --------------------------------------------------

func _get_active_theme() -> FloorTheme:
	for theme: FloorTheme in themes:
		if theme != null and theme.covers_depth(floor_depth):
			return theme
	return null


func _inject_wall_theme(room: Node2D) -> void:
	var theme := _get_active_theme()
	if theme == null or theme.wall_theme_scene == null:
		return
	var wall_visual: Node = theme.wall_theme_scene.instantiate()
	if wall_visual == null:
		return
	room.add_child(wall_visual)


func _inject_floor_theme(room: Node2D) -> void:
	var theme := _get_active_theme()
	if theme == null or theme.floor_tileset == null:
		return
	for node: Node in room.find_children("", "TileMapLayer", true, false):
		var layer := node as TileMapLayer
		if layer != null:
			layer.tile_set = theme.floor_tileset


func _inject_door_theme(room: Node2D) -> void:
	var theme := _get_active_theme()
	if theme == null or theme.door_texture == null:
		return
	for node: Node in room.find_children("", "Door", true, false):
		var door := node as Door
		if door != null:
			door.apply_theme(theme.door_texture)


func _inject_layout(room: Node2D, rn: FloorGenerator.RoomNode, is_xl: bool, coord: Vector2i) -> void:
	var db: RoomLayoutDatabase = xl_layout_database if is_xl else layout_database
	if db == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _room_pick_seed(runtime_seed, coord, rn.exits_mask, rn.kind) ^ 0xCAFE
	var used: Array[String] = _used_xl_layout_paths if is_xl else _used_layout_paths
	var layout_scene: PackedScene = db.pick_layout(rn.kind, rng, used)
	if layout_scene == null:
		return
	var layout: Node = layout_scene.instantiate()
	if layout == null:
		return
	room.add_child(layout)
	used.append(layout_scene.resource_path)
	for node: Node in layout.find_children("", "TileMapLayer", true, false):
		(node as TileMapLayer).z_index = -1


# --------------------------------------------------

func _place_player_in_start_room(plan: FloorGenerator.FloorPlan) -> void:
	if player_path.is_empty():
		return

	var player_node: Node = get_node_or_null(player_path)
	if player_node == null:
		push_warning("FloorSpawner: player_path invalid: %s" % String(player_path))
		return

	var player_2d: Node2D = player_node as Node2D
	if player_2d == null:
		return

	var start_coord: Vector2i = _find_start_coord(plan)
	if not _room_instances.has(start_coord):
		return

	var start_room: Node2D = _room_instances[start_coord]
	player_2d.global_position = _get_player_spawn_position_in_room(start_room)

	emit_signal("floor_spawned", start_room)
	queue_redraw()


func _find_start_coord(plan: FloorGenerator.FloorPlan) -> Vector2i:
	for coord: Vector2i in plan.coords:
		var rn: FloorGenerator.RoomNode = plan.rooms[coord]
		if rn.kind == &"START":
			return coord
	return Vector2i.ZERO


func _get_player_spawn_position_in_room(room: Node2D) -> Vector2:
	var marker: Node2D = room.get_node_or_null(NodePath("Spawns/%s" % String(player_spawn_marker_name)))
	if marker != null:
		return marker.global_position

	return room.global_position + Vector2(float(ROOM_SIZE.x) * 0.5, float(ROOM_SIZE.y) * 0.5)


# --------------------------------------------------

func _room_pick_seed(floor_seed: int, coord: Vector2i, exits_mask: int, kind: StringName) -> int:
	return hash("%d|%d|%d|%d|%s" % [floor_seed, coord.x, coord.y, exits_mask, String(kind)])


func _room_rolls_combat(coord: Vector2i, kind: StringName) -> bool:
	var chance: float = boss_combat_chance if kind == &"BOSS" else combat_chance
	if chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|%d|%d|cbt" % [runtime_seed, coord.x, coord.y])
	return rng.randf() < chance


# --------------------------------------------------

func _has_enemy_spawns(room: Node2D) -> bool:
	return not room.find_children("EnemySpawner_*", "Marker2D", true, false).is_empty()


func _setup_room_controller(room: Node2D, rn: FloorGenerator.RoomNode, is_xl: bool, coord: Vector2i) -> void:
	if not _has_enemy_spawns(room):
		return
	var ctrl := RoomController.new()
	room.add_child(ctrl)
	var spawn_seed: int = _room_pick_seed(runtime_seed, coord, rn.exits_mask, rn.kind) ^ 0xBEEF
	ctrl.setup(room, rn.exits_mask, rn.xl_exits_mask, is_xl, enemy_scenes, spawn_seed)


func _add_room_tracker(room: Node2D, coord: Vector2i, is_xl: bool) -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2  # Player physics layer
	area.monitoring = true
	area.monitorable = false

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	if is_xl:
		rect.size = Vector2(1580.0, 1580.0)
		shape.position = Vector2(800.0, 800.0)
	else:
		rect.size = Vector2(780.0, 780.0)
		shape.position = Vector2(400.0, 400.0)
	shape.shape = rect

	area.add_child(shape)
	area.body_entered.connect(func(body: Node) -> void:
		if body.is_in_group("player"):
			player_room_changed.emit(coord)
	)
	room.add_child(area)

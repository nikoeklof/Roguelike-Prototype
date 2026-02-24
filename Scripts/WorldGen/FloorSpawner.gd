extends Node2D
class_name FloorSpawner

signal floor_spawned(start_room: Node2D)
signal floor_plan_generated(plan: FloorGenerator.FloorPlan)

@export var room_scene: PackedScene
@export var room_database: RoomDatabase

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

const ROOM_SIZE: Vector2i = Vector2i(528, 528)

var _gen: FloorGenerator
var _plan: FloorGenerator.FloorPlan
var _room_instances: Dictionary = {}


# --------------------------------------------------

func _ready() -> void:
	add_to_group("floor_spawner")

	if room_scene == null and room_database == null:
		push_error("FloorSpawner: set room_scene OR room_database.")
		return

	if room_database != null:
		room_database.rebuild()
		print(room_database.debug_summary())

	# ---- seed selection ----
	runtime_seed = seed
	if randomize_seed:
		runtime_seed = int(Time.get_unix_time_from_system()) ^ Engine.get_frames_drawn()

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
		min_separation
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

	for coord: Vector2i in plan.coords:
		var rn: FloorGenerator.RoomNode = plan.rooms[coord] as FloorGenerator.RoomNode

		var ps: PackedScene = room_scene
		if room_database != null:
			var rng := RandomNumberGenerator.new()
			rng.seed = _room_pick_seed(plan.seed, coord, rn.exits_mask, rn.kind)
			ps = room_database.pick_scene(rn.exits_mask, rng)

		if ps == null:
			push_error("FloorSpawner: no scene available for coord=%s mask=%d" % [str(coord), rn.exits_mask])
			continue

		var inst: Node2D = ps.instantiate() as Node2D
		if inst == null:
			push_error("FloorSpawner: failed to instantiate room scene.")
			continue

		add_child(inst)
		inst.position = Vector2(coord.x * float(ROOM_SIZE.x), coord.y * float(ROOM_SIZE.y))
		inst.name = "%s_%d_%d" % [String(rn.kind), coord.x, coord.y]

		if apply_door_colliders:
			_apply_door_state(inst, rn.exits_mask)

		_room_instances[coord] = inst


# --------------------------------------------------

func _apply_door_state(room: Node2D, exits_mask: int) -> void:
	_set_door_collider_open(room, "RoomCollision/NorthWall_Door", (exits_mask & FloorGenerator.N) != 0)
	_set_door_collider_open(room, "RoomCollision/EastWall_Door",  (exits_mask & FloorGenerator.E) != 0)
	_set_door_collider_open(room, "RoomCollision/SouthWall_Door", (exits_mask & FloorGenerator.S) != 0)
	_set_door_collider_open(room, "RoomCollision/WestWall_Door",  (exits_mask & FloorGenerator.W) != 0)


func _set_door_collider_open(room: Node2D, path: String, should_be_open: bool) -> void:
	var n: Node = room.get_node_or_null(NodePath(path))
	if n == null:
		return

	if n is CollisionShape2D:
		(n as CollisionShape2D).set_deferred("disabled", should_be_open)
		return
	if n is CollisionPolygon2D:
		(n as CollisionPolygon2D).set_deferred("disabled", should_be_open)
		return

	n.set_deferred("disabled", should_be_open)


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

extends Node2D
class_name FloorSpawner

signal floor_spawned(start_room: Node2D)
signal floor_plan_generated(plan: FloorGenerator.FloorPlan)

@export var room_scene: PackedScene
@export var room_database: RoomDatabase
@export var xl_room_database: RoomDatabase
@export_range(0.0, 1.0, 0.05) var xl_room_chance: float = 0.25

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

const ROOM_SIZE: Vector2i = Vector2i(800, 800)
const XL_ROOM_SIZE: Vector2i = Vector2i(1600, 1600)

var _gen: FloorGenerator
var _plan: FloorGenerator.FloorPlan
var _room_instances: Dictionary = {}

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

		if spawn_room_items:
			_wire_item_spawners_for_room(inst, coord)

		if spawn_room_enemies and rn.kind != &"START":
			if _room_rolls_combat(coord, rn.kind):
				_setup_room_controller(inst, rn, is_xl, coord)

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
	_set_door_collider_open(room, "RoomCollision/NorthWall_Door", (exits_mask & FloorGenerator.N) != 0)
	_set_door_collider_open(room, "RoomCollision/EastWall_Door",  (exits_mask & FloorGenerator.E) != 0)
	_set_door_collider_open(room, "RoomCollision/SouthWall_Door", (exits_mask & FloorGenerator.S) != 0)
	_set_door_collider_open(room, "RoomCollision/WestWall_Door",  (exits_mask & FloorGenerator.W) != 0)


func _apply_door_state_xl(room: Node2D, xl_mask: int) -> void:
	_set_door_collider_open(room, "RoomCollision/NorthWall_Door1", (xl_mask & FloorGenerator.XL_N1) != 0)
	_set_door_collider_open(room, "RoomCollision/NorthWall_Door2", (xl_mask & FloorGenerator.XL_N2) != 0)
	_set_door_collider_open(room, "RoomCollision/EastWall_Door1",  (xl_mask & FloorGenerator.XL_E1) != 0)
	_set_door_collider_open(room, "RoomCollision/EastWall_Door2",  (xl_mask & FloorGenerator.XL_E2) != 0)
	_set_door_collider_open(room, "RoomCollision/SouthWall_Door1", (xl_mask & FloorGenerator.XL_S1) != 0)
	_set_door_collider_open(room, "RoomCollision/SouthWall_Door2", (xl_mask & FloorGenerator.XL_S2) != 0)
	_set_door_collider_open(room, "RoomCollision/WestWall_Door1",  (xl_mask & FloorGenerator.XL_W1) != 0)
	_set_door_collider_open(room, "RoomCollision/WestWall_Door2",  (xl_mask & FloorGenerator.XL_W2) != 0)


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
	var spawns := room.get_node_or_null("Spawns")
	if spawns == null:
		return false
	for child: Node in spawns.get_children():
		if child.name.begins_with("EnemySpawn_"):
			return true
	return false


func _setup_room_controller(room: Node2D, rn: FloorGenerator.RoomNode, is_xl: bool, coord: Vector2i) -> void:
	if not _has_enemy_spawns(room):
		return
	var ctrl := RoomController.new()
	room.add_child(ctrl)
	var spawn_seed: int = _room_pick_seed(runtime_seed, coord, rn.exits_mask, rn.kind) ^ 0xBEEF
	ctrl.setup(room, rn.exits_mask, rn.xl_exits_mask, is_xl, enemy_scenes, spawn_seed)

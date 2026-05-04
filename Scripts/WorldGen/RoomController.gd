extends Node
class_name RoomController

enum EncounterState { IDLE, ACTIVE, CLEARED }

signal encounter_started
signal encounter_cleared

var state: EncounterState = EncounterState.IDLE

var _room: Node2D
var _exits_mask: int = 0
var _xl_exits_mask: int = 0
var _is_xl: bool = false
var _enemies_remaining: int = 0
var _enemy_scenes: Array = []
var _spawn_seed: int = 0
var _detection_area: Area2D = null
var _player_caps: Capabilities = null


func setup(
	room: Node2D,
	exits_mask: int,
	xl_exits_mask: int,
	is_xl: bool,
	enemy_scenes: Array,
	spawn_seed: int
) -> void:
	_room = room
	_exits_mask = exits_mask
	_xl_exits_mask = xl_exits_mask
	_is_xl = is_xl
	_enemy_scenes = enemy_scenes
	_spawn_seed = spawn_seed
	_add_detection_area()


# --------------------------------------------------
# Detection
# --------------------------------------------------

func _add_detection_area() -> void:
	_detection_area = Area2D.new()
	_detection_area.collision_layer = 0
	_detection_area.collision_mask = 2  # Player physics layer
	_detection_area.monitoring = true
	_detection_area.monitorable = false

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	if _is_xl:
		rect.size = Vector2(1580.0, 1580.0)
		shape.position = Vector2(800.0, 800.0)
	else:
		rect.size = Vector2(780.0, 780.0)
		shape.position = Vector2(400.0, 400.0)
	shape.shape = rect

	_detection_area.add_child(shape)
	_detection_area.body_entered.connect(_on_body_entered)
	_room.add_child(_detection_area)


func _on_body_entered(body: Node) -> void:
	if state != EncounterState.IDLE:
		return
	if not body.is_in_group("player"):
		return
	_player_caps = body.get_node_or_null("Capabilities") as Capabilities
	_start_encounter()


# --------------------------------------------------
# Encounter lifecycle
# --------------------------------------------------

func _start_encounter() -> void:
	state = EncounterState.ACTIVE
	encounter_started.emit()

	# Block player input — natural momentum carries them into the room.
	if _player_caps != null:
		_player_caps.block(Capabilities.CAN_MOVE,   &"room_entry")
		_player_caps.block(Capabilities.CAN_ATTACK, &"room_entry")
		_player_caps.block(Capabilities.CAN_CAST,   &"room_entry")

	# 0.4s: player glides in, then lock doors + spawn.
	await get_tree().create_timer(0.4).timeout
	_lock_doors()
	_spawn_enemies()
	print("[RoomController] Encounter started — enemies: ", _enemies_remaining)

	# 0.2s grace period before player can act.
	await get_tree().create_timer(0.2).timeout
	if _player_caps != null:
		_player_caps.unblock(Capabilities.CAN_MOVE,   &"room_entry")
		_player_caps.unblock(Capabilities.CAN_ATTACK, &"room_entry")
		_player_caps.unblock(Capabilities.CAN_CAST,   &"room_entry")

	# If no enemies were registered (e.g. scenes list empty), clear immediately.
	if _enemies_remaining <= 0:
		_clear_encounter()


func _spawn_enemies() -> void:
	if _enemy_scenes.is_empty():
		return

	var markers := _find_enemy_spawn_markers()
	if markers.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = _spawn_seed

	for marker: Marker2D in markers:
		var idx: int = rng.randi_range(0, _enemy_scenes.size() - 1)
		var scene := _enemy_scenes[idx] as PackedScene
		if scene == null:
			continue

		var enemy := scene.instantiate() as Node2D
		if enemy == null:
			continue

		_room.add_child(enemy)
		enemy.global_position = marker.global_position

		var health := _find_health(enemy)
		if health != null:
			health.died.connect(_on_enemy_died)
			_enemies_remaining += 1


func _find_enemy_spawn_markers() -> Array[Marker2D]:
	var result: Array[Marker2D] = []
	# Search recursively — markers may live in root Spawns/ or inside a layout child.
	var all_markers := _room.find_children("EnemySpawner_*", "Marker2D", true, false)
	for node: Node in all_markers:
		var m := node as Marker2D
		if m != null:
			result.append(m)
	return result


func _find_health(entity: Node) -> Health:
	var h := entity.get_node_or_null("Health") as Health
	if h != null:
		return h
	var found := entity.find_children("", "Health", true, false)
	if not found.is_empty():
		return found[0] as Health
	return null


func _on_enemy_died() -> void:
	_enemies_remaining -= 1
	if _enemies_remaining <= 0:
		_clear_encounter()


func _clear_encounter() -> void:
	state = EncounterState.CLEARED
	_unlock_doors()
	if is_instance_valid(_detection_area):
		_detection_area.queue_free()
	encounter_cleared.emit()
	print("[RoomController] Encounter cleared")


# --------------------------------------------------
# Door locking
# --------------------------------------------------

func _lock_doors() -> void:
	var doors := _get_active_doors()
	if doors.is_empty():
		_legacy_set_exits_locked(true)
		return
	for door in doors:
		door.close()


func _unlock_doors() -> void:
	var doors := _get_active_doors()
	if doors.is_empty():
		_legacy_set_exits_locked(false)
		return
	for door in doors:
		door.set_state(door.initial_state)


# Returns all Door nodes under Doors/ that are actual exits (not walled off).
func _get_active_doors() -> Array[Door]:
	var doors_node := _room.get_node_or_null("Doors")
	if doors_node == null:
		return []
	var result: Array[Door] = []
	for child in doors_node.get_children():
		var door := child as Door
		if door != null:
			result.append(door)
	return result


# Legacy fallback for old RoomChunk scenes without Door nodes.
func _legacy_set_exits_locked(locked: bool) -> void:
	if _is_xl:
		_legacy_set_xl_doors_locked(locked)
	else:
		_legacy_set_normal_doors_locked(locked)


func _legacy_set_normal_doors_locked(locked: bool) -> void:
	if (_exits_mask & FloorGenerator.N) != 0:
		_legacy_set_collider_disabled("RoomCollision/NorthWall_Door", not locked)
	if (_exits_mask & FloorGenerator.E) != 0:
		_legacy_set_collider_disabled("RoomCollision/EastWall_Door", not locked)
	if (_exits_mask & FloorGenerator.S) != 0:
		_legacy_set_collider_disabled("RoomCollision/SouthWall_Door", not locked)
	if (_exits_mask & FloorGenerator.W) != 0:
		_legacy_set_collider_disabled("RoomCollision/WestWall_Door", not locked)


func _legacy_set_xl_doors_locked(locked: bool) -> void:
	if (_xl_exits_mask & FloorGenerator.XL_N1) != 0:
		_legacy_set_collider_disabled("RoomCollision/NorthWall_Door1", not locked)
	if (_xl_exits_mask & FloorGenerator.XL_N2) != 0:
		_legacy_set_collider_disabled("RoomCollision/NorthWall_Door2", not locked)
	if (_xl_exits_mask & FloorGenerator.XL_E1) != 0:
		_legacy_set_collider_disabled("RoomCollision/EastWall_Door1", not locked)
	if (_xl_exits_mask & FloorGenerator.XL_E2) != 0:
		_legacy_set_collider_disabled("RoomCollision/EastWall_Door2", not locked)
	if (_xl_exits_mask & FloorGenerator.XL_S1) != 0:
		_legacy_set_collider_disabled("RoomCollision/SouthWall_Door1", not locked)
	if (_xl_exits_mask & FloorGenerator.XL_S2) != 0:
		_legacy_set_collider_disabled("RoomCollision/SouthWall_Door2", not locked)
	if (_xl_exits_mask & FloorGenerator.XL_W1) != 0:
		_legacy_set_collider_disabled("RoomCollision/WestWall_Door1", not locked)
	if (_xl_exits_mask & FloorGenerator.XL_W2) != 0:
		_legacy_set_collider_disabled("RoomCollision/WestWall_Door2", not locked)


func _legacy_set_collider_disabled(path: String, disabled: bool) -> void:
	var n := _room.get_node_or_null(NodePath(path))
	if n is CollisionShape2D:
		(n as CollisionShape2D).set_deferred("disabled", disabled)
	elif n is CollisionPolygon2D:
		(n as CollisionPolygon2D).set_deferred("disabled", disabled)

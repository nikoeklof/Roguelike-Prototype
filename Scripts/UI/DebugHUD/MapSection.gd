extends Control
class_name MapSection
## Self-contained map section for the debug HUD.
## Auto-hides when no floor plan is available.
## Place this as a child of the VBoxContainer that holds InfoLabel.

@export var floor_spawner_path: NodePath
@export var player_root_path: NodePath

@onready var minimap: MinimapControl = %Minimap
@onready var map_label: Label = %Label

var _floor_spawner: Node = null
var _player: Node2D = null
var _has_floor_plan: bool = false


func _ready() -> void:
	_bind_floor_spawner()
	_bind_player()
	call_deferred("_pull_existing_floor_plan")
	_update_visibility()


func _process(_delta: float) -> void:
	if _player != null and minimap != null and _has_floor_plan:
		minimap.set_player_cell(_world_to_cell(_player.global_position))


func _bind_floor_spawner() -> void:
	if floor_spawner_path != NodePath():
		_floor_spawner = get_node_or_null(floor_spawner_path)
	else:
		var tree: SceneTree = get_tree()
		if tree != null:
			_floor_spawner = tree.get_first_node_in_group("floor_spawner")

	if _floor_spawner == null:
		return

	if _floor_spawner.has_signal("floor_plan_generated"):
		if not _floor_spawner.is_connected("floor_plan_generated", _on_floor_plan_generated):
			_floor_spawner.connect("floor_plan_generated", _on_floor_plan_generated)


func _bind_player() -> void:
	if player_root_path != NodePath():
		_player = get_node_or_null(player_root_path) as Node2D
	else:
		var tree: SceneTree = get_tree()
		if tree != null:
			_player = tree.get_first_node_in_group("player") as Node2D


func _pull_existing_floor_plan() -> void:
	if _floor_spawner == null:
		return
	if _floor_spawner.has_method("get_floor_plan"):
		var plan: Variant = _floor_spawner.call("get_floor_plan")
		if plan != null:
			_on_floor_plan_generated(plan)
	_update_visibility()


func _on_floor_plan_generated(plan: FloorGenerator.FloorPlan) -> void:
	_has_floor_plan = true
	if minimap != null:
		minimap.set_floor_plan(plan)
	if map_label != null:
		map_label.text = "MAP — Seed: %d" % int(plan.seed)
	_update_visibility()


func _update_visibility() -> void:
	visible = _has_floor_plan


func _world_to_cell(world_pos: Vector2) -> Vector2i:
	const CELL_SIZE_WORLD: float = 528.0
	return Vector2i(
		roundi(world_pos.x / CELL_SIZE_WORLD),
		roundi(world_pos.y / CELL_SIZE_WORLD)
	)

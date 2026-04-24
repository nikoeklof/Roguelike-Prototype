extends Control
class_name MapSection

@export var floor_spawner_path: NodePath

@onready var minimap: MinimapControl = %Minimap
@onready var map_label: Label = %Label

var _floor_spawner: Node = null
var _has_floor_plan: bool = false


func _ready() -> void:
	_bind_floor_spawner()
	call_deferred("_pull_existing_floor_plan")
	_update_visibility()


func _on_player_room_changed(coord: Vector2i) -> void:
	if minimap != null:
		minimap.set_player_cell(coord)


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

	if _floor_spawner.has_signal("player_room_changed"):
		if not _floor_spawner.is_connected("player_room_changed", _on_player_room_changed):
			_floor_spawner.connect("player_room_changed", _on_player_room_changed)


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

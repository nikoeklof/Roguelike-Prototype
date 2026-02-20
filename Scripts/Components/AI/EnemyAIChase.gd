@tool
extends Node
class_name EnemyAIChase

@export var target_group: StringName = &"player"
@export_range(0.0, 500.0, 0.5) var attack_range := 28.0
@export_range(0.0, 500.0, 0.5) var stop_distance := 18.0
@export_range(0.01, 5.0, 0.01) var repath_interval := 0.2
@export_node_path("NavigationAgent2D") var nav_agent_path: NodePath = ^"../NavAgent"

var _target: Node2D
var _repath_t := 0.0

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var entity := get_parent() as Entity
	if entity == null:
		return

	var control := entity.get_component(&"EnemyControl")
	if control == null:
		return

	var agent := get_node_or_null(nav_agent_path) as NavigationAgent2D
	if agent == null:
		return

	_repath_t += delta
	if _target == null or _repath_t >= repath_interval:
		_repath_t = 0.0
		var nodes := get_tree().get_nodes_in_group(target_group)
		_target = nodes[0] if nodes.size() > 0 else null

	if _target == null:
		return

	var to_target := _target.global_position - entity.global_position
	var dist := to_target.length()

	agent.target_position = _target.global_position
	var dir := (agent.get_next_path_position() - entity.global_position).normalized()

	if dist <= stop_distance:
		control.set_move_intent(Vector2.ZERO)
	else:
		control.set_move_intent(dir)

	if dist <= attack_range:
		control.press_attack(to_target.normalized(), Combat.AttackKind.MELEE)

extends Resource
class_name MeleeAttack

# Optional override. If empty/broken, we auto-find the first AttackController in the actor.
@export_node_path("AttackController") var attack_controller_path: NodePath
@export_range(0.0, 2.0, 0.01) var windup_lock_sec: float = 0.0

var actor: Node = null


func _get_attack_controller() -> AttackController:
	if actor == null:
		return null

	var atk: AttackController = null

	if attack_controller_path != NodePath(""):
		var node := actor.get_node_or_null(attack_controller_path)
		if node is AttackController:
			atk = node as AttackController
			return atk

	# QoL: discover (BFS) using your existing helper
	var found_node: Node = EntityComponents.resolve_in_tree(actor, &"AttackController")
	if found_node is AttackController:
		return found_node as AttackController

	return null


func try_attack(dir: Vector2) -> bool:
	if actor == null:
		return false

	var atk := _get_attack_controller()
	if atk == null:
		return false

	# Preserve your existing behavior: AttackController likely exposes methods you already use.
	if "swing" in atk:
		atk.swing(dir)
	elif "try_swing" in atk:
		atk.try_swing(dir)

	# Locking is handled by Capabilities/State elsewhere; windup lock is optional helper.
	return true

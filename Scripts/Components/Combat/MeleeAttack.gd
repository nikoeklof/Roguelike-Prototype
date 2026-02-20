extends Resource
class_name MeleeAttack

# Optional override. If empty/broken, we auto-find the first AttackController in the actor.
@export_node_path("AttackController") var attack_controller_path: NodePath
@export_range(0.0, 2.0, 0.01) var windup_lock_sec := 0.0

var actor: Node = null


func _get_attack_controller() -> AttackController:
	if actor == null:
		return null
	var atk := actor.get_node_or_null(attack_controller_path) as AttackController
	if atk != null:
		return atk
	# QoL: discover
	var found := EntityComponents.get_in_tree(actor, &"AttackController")
	return found as AttackController


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

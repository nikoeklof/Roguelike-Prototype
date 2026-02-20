extends Weapon
class_name MeleeWeapon

@export var damage: float = 1.0
@export_node_path("AttackController") var attack_controller_path: NodePath = ^"AttackController"

var _warned_missing_controller := false


func try_attack(dir: Vector2, owner_entity: Node) -> bool:
	if owner_entity == null or not can_attack():
		return false

	var atk := _get_attack_controller(owner_entity)
	if atk == null:
		if not _warned_missing_controller:
			_warned_missing_controller = true
			push_warning("%s: missing AttackController at %s (owner=%s)" % [
				name, str(attack_controller_path), owner_entity.name
			])
		return false

	_warned_missing_controller = false
	_commit_cooldown()

	# Your AttackController signature:
	# start_attack(dir: Vector2, dmg: float = 1.0, src: Node = null)
	atk.start_attack(dir, damage, owner_entity)
	# Prefer your helper if it exists
	if atk.has_method("connect_finished"):
		atk.connect_finished(Callable(self, "_on_attack_finished"))
	elif atk.has_signal("finished"):
		atk.finished.connect(Callable(self, "_on_attack_finished"), CONNECT_ONE_SHOT)

	return true


func stop() -> void:
	# If you later want interrupt support:
	# var atk := _get_attack_controller(owner_entity)
	# if atk and atk.has_method("stop_attack"): atk.stop_attack()
	pass


func _on_attack_finished() -> void:
	attack_finished.emit()


func _get_attack_controller(owner_entity: Node) -> Node:
	# Look up relative to the OWNER ENTITY, not relative to the weapon node
	var node := owner_entity.get_node_or_null(attack_controller_path)
	if node is AttackController:
		return node

	# QoL: common default name
	node = owner_entity.get_node_or_null("AttackController")
	if node is AttackController:
		return node

	# QoL: search anywhere under the entity (cached)
	return EntityComponents.resolve_in_tree(owner_entity, &"AttackController")

extends Resource
class_name RangedAttack

@export var projectile_scene: PackedScene

# Optional override. If empty/broken, we auto-find VisualRoot/WeaponSocket.
@export_node_path("Node2D") var spawn_path: NodePath
@export var muzzle_offset: Vector2 = Vector2.ZERO

@export_range(0.0, 5000.0, 1.0) var speed := 450.0
@export_range(-2000.0, 2000.0, 1.0) var gravity := 0.0              # 0 for straight shots, >0 for arcing
@export_range(0.0, 1.0, 0.01) var inherit_owner_velocity := 0.0 # 0..1

var actor: Node = null


func _resolve_spawn(owner_entity: Node) -> Node2D:
	if owner_entity == null:
		return null
	var n := owner_entity.get_node_or_null(spawn_path) as Node2D
	if n != null:
		return n
	# common defaults
	n = owner_entity.get_node_or_null("VisualRoot/WeaponSocket") as Node2D
	if n != null:
		return n
	n = owner_entity.get_node_or_null("WeaponSocket") as Node2D
	if n != null:
		return n
	n = owner_entity.get_node_or_null("VisualRoot/AttackPivot") as Node2D
	return n


func try_attack(dir: Vector2) -> bool:
	if actor == null or projectile_scene == null:
		return false

	var owner_entity := actor
	var spawn := _resolve_spawn(owner_entity)
	if spawn == null:
		return false

	var p := projectile_scene.instantiate()
	if p == null:
		return false

	# Try to set common projectile fields if they exist.
	if p is Node2D:
		(p as Node2D).global_position = spawn.global_position + muzzle_offset.rotated(dir.angle())
	if "setup" in p:
		p.setup(owner_entity, dir, speed, gravity, inherit_owner_velocity)
	elif "dir" in p:
		p.dir = dir

	owner_entity.get_tree().current_scene.add_child(p)
	return true

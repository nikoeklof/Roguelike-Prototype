extends Weapon
class_name RangedWeapon

@export var projectile_scene: PackedScene
@export_node_path("Node2D") var spawn_path: NodePath = ^"VisualRoot/WeaponSocket"
@export var muzzle_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 5000.0, 1.0) var speed: float = 450.0
@export_range(-2000.0, 2000.0, 1.0) var gravity: float = 0.0
@export_range(0.0, 1.0, 0.01) var inherit_owner_velocity: float = 0.0 # 0..1
@export_range(0.0, 45.0, 0.1) var spread_degrees: float = 0.0
@export_range(1, 20, 1) var shots_per_attack: int = 1
@export_range(0.0, 1.0, 0.01) var burst_interval_sec: float = 0.08
@export_range(0.05, 30.0, 0.05) var lifetime_sec: float = 2.0
@export_range(0, 9999, 1) var damage: int = 1
@export_range(0, 50, 1) var pierce: int = 0

func try_attack(dir: Vector2, owner_entity: Node) -> bool:
	if owner_entity == null or projectile_scene == null or not can_attack():
		return false

	var d := dir
	if d.length() < 0.001:
		d = Vector2.RIGHT
	else:
		d = d.normalized()

	var spawn := owner_entity.get_node_or_null(spawn_path) as Node2D
	if spawn == null:
		# QoL fallbacks
		spawn = owner_entity.get_node_or_null("VisualRoot/WeaponSocket") as Node2D
		if spawn == null:
			spawn = owner_entity.get_node_or_null("WeaponSocket") as Node2D
		if spawn == null:
			spawn = owner_entity.get_node_or_null("VisualRoot/AttackPivot") as Node2D
		if spawn == null:
			push_warning("RangedWeapon: missing spawn node (set spawn_path or add VisualRoot/WeaponSocket)")
			return false

	_commit_cooldown()

	_fire_one(owner_entity, spawn, d)

	if shots_per_attack > 1:
		for i in range(1, shots_per_attack):
			var t := Timer.new()
			t.one_shot = true
			t.wait_time = burst_interval_sec * i
			owner_entity.add_child(t)
			t.timeout.connect(func():
				if is_instance_valid(owner_entity):
					var sp := owner_entity.get_node_or_null(spawn_path) as Node2D
					if sp:
						_fire_one(owner_entity, sp, d, i)
				t.queue_free()
			)
			t.start()

	# For ranged we emit finished immediately (you can later change this if you want)
	attack_finished.emit()
	return true

func _fire_one(owner_entity: Node, spawn: Node2D, dir: Vector2, _index: int = 0) -> void:
	var shot_dir := dir

	if spread_degrees != 0.0:
		var half := spread_degrees * 0.5
		var a := deg_to_rad(randf_range(-half, half))
		shot_dir = shot_dir.rotated(a).normalized()

	var p := projectile_scene.instantiate() as Projectile
	if p == null:
		push_warning("RangedWeapon: projectile_scene is not a Projectile.")
		return

	# Spawn position
	var origin := spawn.global_position + muzzle_offset.rotated(spawn.global_rotation)
	p.global_position = origin

	# Velocity
	var v := shot_dir * speed

	if inherit_owner_velocity > 0.0 and owner_entity is CharacterBody2D:
		var ov := (owner_entity as CharacterBody2D).velocity
		v += ov * clampf(inherit_owner_velocity, 0.0, 1.0)

	# Setup projectile
	p.setup(v, gravity, lifetime_sec, damage, pierce, owner_entity)

	# Add to the scene (same parent as entity, usually World/YSort layer)
	var root := owner_entity.get_tree().current_scene
	if owner_entity.get_parent() != null:
		owner_entity.get_parent().add_child(p)
	else:
		root.add_child(p)

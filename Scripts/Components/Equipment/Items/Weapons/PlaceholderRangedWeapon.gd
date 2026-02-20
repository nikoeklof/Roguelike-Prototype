extends Weapon
class_name PlaceholderRangedWeapon

@export var label: String = "PlaceholderRanged"

# Projectile tuning
@export var damage: float = 1.0
@export var projectile_speed: float = 650.0
@export var projectile_lifetime: float = 1.2
@export var projectile_radius: float = 4.0
@export var knockback: float = 0.0

# Spread + multishot
@export_range(0.0, 45.0, 0.1) var spread_degrees: float = 0.0
@export_range(1, 16, 1) var projectiles_per_shot: int = 1

# Piercing
@export_range(1, 16, 1) var max_hits: int = 1


func try_attack(dir: Vector2, owner_entity: Node) -> bool:
	if owner_entity == null or not can_attack():
		return false

	_commit_cooldown()

	var d: Vector2 = dir
	if d.length() < 0.001:
		d = Vector2.RIGHT
	else:
		d = d.normalized()

	_fire_projectiles(owner_entity, d)

	print("[%s] attack_finished" % label)
	attack_finished.emit()
	return true


func _fire_projectiles(owner_entity: Node, dir: Vector2) -> void:
	var origin: Vector2 = Vector2.ZERO
	if owner_entity is Node2D:
		origin = (owner_entity as Node2D).global_position

	var parent_for_proj: Node = owner_entity.get_parent()
	if parent_for_proj == null:
		parent_for_proj = owner_entity

	# Multi-shot spread: center shots around aim dir
	var n: int = max(1, projectiles_per_shot)
	var total_rad: float = deg_to_rad(spread_degrees)
	var step: float = 0.0
	if n > 1:
		step = total_rad / float(n - 1)

	for i in n:
		var angle_offset: float = 0.0
		if n == 1:
			angle_offset = randf_range(-total_rad * 0.5, total_rad * 0.5) if spread_degrees > 0.0 else 0.0
		else:
			angle_offset = -total_rad * 0.5 + step * float(i)

		var shot_dir: Vector2 = dir.rotated(angle_offset).normalized()

		var p: PlaceholderProjectile = PlaceholderProjectile.new()
		p.global_position = origin
		p.rotation = shot_dir.angle()
		p.setup(owner_entity, shot_dir, damage, projectile_speed, projectile_lifetime, projectile_radius, knockback, max_hits)
		parent_for_proj.add_child(p)

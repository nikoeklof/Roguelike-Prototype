extends Weapon
class_name PlaceholderRangedWeapon

@export var label: String = "PlaceholderRanged"

@export_range(0.0, 10.0, 0.01) var cooldown_sec: float = 0.25
@export var projectile_scene: PackedScene
@export var speed: float = 520.0
@export var lifetime_sec: float = 1.6
@export var damage: float = 1.0


func try_attack(dir: Vector2, owner_entity: Node) -> bool:
	if owner_entity == null or projectile_scene == null:
		return false
	if not can_attack():
		return false

	var d := dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT

	commit_cooldown(cooldown_sec)

	var p := projectile_scene.instantiate() as Projectile
	if p == null:
		push_warning("PlaceholderRangedWeapon: projectile_scene is not a Projectile.")
		return false

	var origin := Vector2.ZERO
	if owner_entity is Node2D:
		origin = (owner_entity as Node2D).global_position

	p.global_position = origin
	p.setup(d * speed, 0.0, lifetime_sec, int(round(damage)), 0, owner_entity)

	if owner_entity.get_parent():
		owner_entity.get_parent().add_child(p)
	else:
		owner_entity.get_tree().current_scene.add_child(p)

	attack_finished.emit()
	return true

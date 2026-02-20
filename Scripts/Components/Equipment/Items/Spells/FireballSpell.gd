extends Spell
class_name FireballSpell

@export var projectile_scene: PackedScene
@export_node_path("Node2D") var spawn_path: NodePath = ^"../VisualRoot/WeaponSocket"
@export var speed: float = 520.0
@export var lifetime_sec: float = 2.0
@export var damage: int = 2

func _ready() -> void:
	spell_type = SpellType.OFFENSIVE

func _do_cast(owner_entity: Node, dir: Vector2) -> void:
	if projectile_scene == null:
		return

	var d := dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT

	var spawn := owner_entity.get_node_or_null(spawn_path) as Node2D
	if spawn == null and owner_entity is Node2D:
		spawn = owner_entity as Node2D
	if spawn == null:
		return

	var p := projectile_scene.instantiate() as Projectile
	if p == null:
		return

	p.global_position = spawn.global_position
	p.setup(d * speed, 0.0, lifetime_sec, damage, 0, owner_entity)

	if owner_entity.get_parent():
		owner_entity.get_parent().add_child(p)
	else:
		owner_entity.get_tree().current_scene.add_child(p)

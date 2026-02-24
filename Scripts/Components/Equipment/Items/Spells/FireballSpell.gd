extends Spell
class_name FireballSpell

@export var projectile_scene: PackedScene
@export_node_path("Node2D") var spawn_path: NodePath = ^"../VisualRoot/WeaponSocket"
@export var speed: float = 520.0
@export var lifetime_sec: float = 2.0

func _ready() -> void:
	spell_type = SpellType.OFFENSIVE


func _do_cast(owner_entity: Node, dir: Vector2) -> void:
	if projectile_scene == null or owner_entity == null:
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

	# Damage from ItemStats
	var dmg_int := 1
	if get_item_instance() != null:
		var ctx := CombatContext.new()
		ctx.owner = owner_entity
		ctx.aim_dir = d
		ctx.item = self
		ctx.item_instance = get_item_instance()

		if owner_entity is Entity:
			var ent := owner_entity as Entity
			ctx.stats = ent.find_component(&"Stats")
			ctx.tags = ent.find_component(&"Tags")
			ctx.faction = ent.find_component(&"Faction")
			ctx.capabilities = ent.find_component(&"Capabilities")

		var stats := get_item_instance().compute_stats(ctx)
		dmg_int = int(round(stats.damage))

	p.global_position = spawn.global_position
	p.setup(d * speed, 0.0, lifetime_sec, dmg_int, 0, owner_entity)

	if owner_entity.get_parent():
		owner_entity.get_parent().add_child(p)
	else:
		owner_entity.get_tree().current_scene.add_child(p)

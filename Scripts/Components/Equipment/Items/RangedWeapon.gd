extends Weapon
class_name RangedWeapon

@export var projectile_scene: PackedScene
@export_node_path("Node2D") var spawn_path: NodePath = ^"VisualRoot/WeaponSocket"
@export var muzzle_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 5000.0, 1.0) var speed: float = 450.0
@export_range(-2000.0, 2000.0, 1.0) var gravity: float = 0.0
@export_range(0.0, 1.0, 0.01) var inherit_owner_velocity: float = 0.0
@export_range(0.0, 45.0, 0.1) var spread_degrees: float = 0.0
@export_range(0.0, 1.0, 0.01) var burst_interval_sec: float = 0.08
@export_range(0.05, 30.0, 0.05) var lifetime_sec: float = 2.0

@export var item_def: ItemDef
@export var item_seed: int = 0
@export_range(0, 8, 1) var editor_attribute_count: int = 0

var _instance: ItemInstance = null


func _ready() -> void:
	if _instance != null:
		return
	if item_def == null:
		push_warning("%s: item_def is null (RangedWeapon expects ItemDef)." % name)
		return

	_instance = ItemInstance.new()
	_instance.def = item_def
	_instance.seed = item_seed
	_instance.ensure_initialized()
	if editor_attribute_count > 0:
		_instance.roll_attributes(editor_attribute_count)


func get_item_instance() -> ItemInstance:
	return _instance


func set_item_instance(inst: ItemInstance) -> void:
	_instance = inst
	if _instance != null and _instance.def != null:
		item_def = _instance.def
		item_seed = _instance.seed


func try_attack(dir: Vector2, owner_entity: Node) -> bool:
	if owner_entity == null or projectile_scene == null or not can_attack():
		return false

	var d := dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT

	var spawn := owner_entity.get_node_or_null(spawn_path) as Node2D
	if spawn == null:
		spawn = owner_entity.get_node_or_null("VisualRoot/WeaponSocket") as Node2D
		if spawn == null:
			spawn = owner_entity.get_node_or_null("WeaponSocket") as Node2D
		if spawn == null:
			push_warning("RangedWeapon: missing spawn node (set spawn_path or add VisualRoot/WeaponSocket)")
			return false

	var ctx := CombatContext.new()
	ctx.owner = owner_entity
	ctx.aim_dir = d
	ctx.item = self
	ctx.item_instance = _instance
	if owner_entity is Entity:
		var ent := owner_entity as Entity
		ctx.stats = ent.find_component(&"Stats")
		ctx.tags = ent.find_component(&"Tags")
		ctx.faction = ent.find_component(&"Faction")
		ctx.capabilities = ent.find_component(&"Capabilities")

	var cooldown_sec := 0.0
	var dmg_int := 1
	var projectile_count := 1
	var pierce := 0

	if _instance != null:
		var s := _instance.compute_stats(ctx)
		cooldown_sec = s.cooldown_sec
		dmg_int = int(round(s.damage))
		projectile_count = maxi(1, s.projectile_count)
		pierce = maxi(0, s.pierce)

	commit_cooldown(cooldown_sec)

	for i in range(projectile_count):
		_fire_one(ctx, spawn, d, dmg_int, pierce, i)

	attack_finished.emit()
	return true


func _fire_one(ctx: CombatContext, spawn: Node2D, dir: Vector2, damage: int, pierce: int, _index: int = 0) -> void:
	var shot_dir := dir

	if spread_degrees != 0.0:
		var half := spread_degrees * 0.5
		var a := deg_to_rad(randf_range(-half, half))
		shot_dir = shot_dir.rotated(a).normalized()

	var p := projectile_scene.instantiate() as Projectile
	if p == null:
		push_warning("RangedWeapon: projectile_scene is not a Projectile.")
		return

	var origin := spawn.global_position + muzzle_offset.rotated(spawn.global_rotation)
	p.global_position = origin

	var v := shot_dir * speed
	if inherit_owner_velocity > 0.0 and ctx.owner is CharacterBody2D:
		var ov := (ctx.owner as CharacterBody2D).velocity
		v += ov * clampf(inherit_owner_velocity, 0.0, 1.0)

	p.setup(v, gravity, lifetime_sec, damage, pierce, ctx.owner)

	# Attribute hook: projectile spawn
	if _instance != null:
		for a in _instance.attributes:
			if a == null:
				continue
			a.on_projectile_spawn(ctx, p, _instance)

	if ctx.owner != null and ctx.owner.get_parent() != null:
		ctx.owner.get_parent().add_child(p)
	else:
		get_tree().current_scene.add_child(p)

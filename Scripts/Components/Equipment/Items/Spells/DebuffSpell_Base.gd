extends Spell
class_name DebuffSpell


func _do_cast(owner_entity: Node, dir: Vector2) -> void:
	if _instance == null or owner_entity == null:
		return
	var spell_def: SpellItemDef = _instance.def as SpellItemDef
	if spell_def == null or spell_def.core_effect == null:
		return

	var ctx: CombatContext = _make_context(owner_entity, dir)

	var mode: int = _instance.spell_delivery_mode
	if mode < 0:
		mode = SpellItemDef.DeliveryMode.PROJECTILE

	match mode:
		SpellItemDef.DeliveryMode.PROJECTILE:
			_cast_projectile(ctx, owner_entity, dir, spell_def)
		SpellItemDef.DeliveryMode.AOE:
			_cast_aoe(ctx, owner_entity, spell_def)


# ------------------------------------------------------------------ #

func _cast_projectile(ctx: CombatContext, owner_entity: Node, dir: Vector2, spell_def: SpellItemDef) -> void:
	var config: Dictionary = spell_def.get_projectile_config()
	var scene: PackedScene = config.get("scene") as PackedScene
	if scene == null:
		push_error("[DebuffSpell] projectile_scene is null on '%s'" % spell_def.id)
		return

	var node: Node = scene.instantiate()
	var projectile: Projectile = node as Projectile
	if projectile == null:
		push_error("[DebuffSpell] projectile_scene root is not a Projectile")
		node.queue_free()
		return

	var d: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT

	var launch: ProjectileLaunchData = ProjectileLaunchData.new()
	launch.context     = ctx
	launch.snapshot    = null
	launch.owner       = owner_entity
	launch.origin      = (owner_entity as Node2D).global_position if owner_entity is Node2D else Vector2.ZERO
	launch.direction   = d
	launch.velocity    = d * config.get("speed", 450.0)

	var inherit_vel: float = config.get("inherit_velocity", 0.0)
	if inherit_vel > 0.0 and owner_entity is CharacterBody2D:
		launch.velocity += (owner_entity as CharacterBody2D).velocity * clampf(inherit_vel, 0.0, 1.0)

	launch.gravity         = config.get("gravity", 0.0)
	launch.lifetime_sec    = config.get("lifetime", 2.0)
	launch.damage          = 0.0
	launch.pierce          = 0
	launch.radius          = maxf(1.0, config.get("radius", 6.0))
	launch.max_range       = maxf(0.0, config.get("range", 0.0))
	launch.collision_mask  = config.get("collision_mask", 0x7FFFFFFF)
	launch.sprite_texture  = config.get("texture")
	launch.sprite_tint     = config.get("tint", Color.WHITE)

	projectile.global_position = launch.origin
	projectile.setup(launch)

	projectile.area_entered.connect(
		_on_projectile_hit.bind(ctx, _instance, projectile),
		CONNECT_ONE_SHOT
	)

	var parent: Node = owner_entity.get_parent() if owner_entity.get_parent() != null else get_tree().current_scene
	parent.add_child(projectile)


func _on_projectile_hit(area: Area2D, ctx: CombatContext, inst: ItemInstance, proj: Projectile) -> void:
	if area == null or ctx == null or not is_instance_valid(ctx.owner):
		return
	var spell_def: SpellItemDef = inst.def as SpellItemDef
	if spell_def == null or spell_def.core_effect == null:
		return

	var caster_faction: Faction = _get_faction(ctx.owner)
	if caster_faction == null:
		return

	var target: Node = _entity_root(area.get_parent())
	if target == null or not caster_faction.is_hostile_to(target):
		return

	spell_def.core_effect.apply_debuff(target, ctx, inst)

	if is_instance_valid(proj):
		proj.queue_free()


# ------------------------------------------------------------------ #

func _cast_aoe(ctx: CombatContext, owner_entity: Node, spell_def: SpellItemDef) -> void:
	var config: Dictionary = spell_def.get_aoe_config()
	var aoe_r: float    = config.get("radius", 150.0)
	var instant: bool   = config.get("instant", true)
	var travel: float   = config.get("travel_time", 0.5)
	var origin: Vector2 = (owner_entity as Node2D).global_position if owner_entity is Node2D else Vector2.ZERO

	if instant:
		_apply_aoe(ctx, owner_entity, origin, aoe_r, spell_def)
	else:
		var t: Timer = Timer.new()
		t.one_shot   = true
		t.wait_time  = travel
		owner_entity.add_child(t)
		t.timeout.connect(func() -> void:
			if is_instance_valid(owner_entity):
				_apply_aoe(ctx, owner_entity, origin, aoe_r, spell_def)
			if is_instance_valid(t):
				t.queue_free()
		, CONNECT_ONE_SHOT)
		t.start()


func _apply_aoe(ctx: CombatContext, owner_entity: Node, origin: Vector2, aoe_r: float, spell_def: SpellItemDef) -> void:
	if not (owner_entity is Node2D):
		return
	var space: PhysicsDirectSpaceState2D = (owner_entity as Node2D).get_world_2d().direct_space_state
	if space == null:
		return

	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = aoe_r

	var q: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	q.shape             = shape
	q.transform         = Transform2D(0.0, origin)
	q.collide_with_areas  = false
	q.collide_with_bodies = true

	var caster_faction: Faction = _get_faction(ctx.owner)
	var processed: Dictionary  = {}

	for h: Dictionary in space.intersect_shape(q, 32):
		var c: Variant = h.get("collider")
		if not (c is Node):
			continue
		var n: Node = c as Node
		if n == owner_entity:
			continue
		if caster_faction != null and not caster_faction.is_hostile_to(n):
			continue

		var root: Node = _entity_root(n)
		if root == null or processed.has(root):
			continue
		processed[root] = true

		spell_def.core_effect.apply_debuff(root, ctx, _instance)


# ------------------------------------------------------------------ #

func _entity_root(n: Node) -> Node:
	var cur: Node = n
	while cur != null:
		if cur is Entity:
			return cur
		cur = cur.get_parent()
	return null


func _get_faction(entity: Node) -> Faction:
	if entity == null or not is_instance_valid(entity):
		return null
	if entity is Entity:
		return (entity as Entity).find_component(&"Faction") as Faction
	return entity.get_node_or_null("Faction") as Faction

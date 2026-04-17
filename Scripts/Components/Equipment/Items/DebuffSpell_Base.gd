extends Spell
class_name DebuffSpell


func _do_cast(owner_entity: Node, _dir: Vector2) -> void:
	if _instance == null or owner_entity == null:
		print("[DebuffSpell] Cannot cast: instance=%s, owner=%s" % [_instance, owner_entity])
		return

	# GET ACTUAL AIM DIRECTION FROM AIMRAY ROTATION
	var actual_dir: Vector2 = _dir
	print("[DebuffSpell] DEBUG - Initial _dir: %s" % _dir)
	
	if owner_entity is Entity:
		var facing_pointer: FacingPointer = (owner_entity as Entity).find_component(&"FacingPointer") as FacingPointer
		print("[DebuffSpell] DEBUG - Found FacingPointer: %s" % (facing_pointer != null))
		if facing_pointer != null:
			var aim_ray: AimRay = facing_pointer.get_node_or_null("AimRay") as AimRay
			print("[DebuffSpell] DEBUG - Found AimRay: %s" % (aim_ray != null))
			if aim_ray != null:
				# Convert rotation back to direction vector
				actual_dir = Vector2.RIGHT.rotated(aim_ray.global_rotation)
				print("[DebuffSpell] DEBUG - AimRay rotation: %s, direction: %s" % [aim_ray.global_rotation, actual_dir])
	else:
		var facing_pointer: FacingPointer = owner_entity.get_node_or_null("FacingPointer") as FacingPointer
		print("[DebuffSpell] DEBUG - Found FacingPointer (fallback): %s" % (facing_pointer != null))
		if facing_pointer != null:
			var aim_ray: AimRay = facing_pointer.get_node_or_null("AimRay") as AimRay
			print("[DebuffSpell] DEBUG - Found AimRay (fallback): %s" % (aim_ray != null))
			if aim_ray != null:
				# Convert rotation back to direction vector
				actual_dir = Vector2.RIGHT.rotated(aim_ray.global_rotation)
				print("[DebuffSpell] DEBUG - AimRay rotation (fallback): %s, direction: %s" % [aim_ray.global_rotation, actual_dir])

	# GET DELIVERY MODE FROM SPELLITEMDEF
	var delivery_mode: int = SpellItemDef.DeliveryMode.PROJECTILE
	if _instance != null and _instance.def != null and _instance.def is SpellItemDef:
		var spell_def: SpellItemDef = _instance.def as SpellItemDef
		delivery_mode = spell_def.delivery_mode

	print("[DebuffSpell] Casting debuff spell '%s', mode=%s, direction=%s" % [name, SpellItemDef.DeliveryMode.keys()[delivery_mode], actual_dir])
	
	var ctx: CombatContext = _make_context(owner_entity, actual_dir)

	match delivery_mode:
		SpellItemDef.DeliveryMode.PROJECTILE:
			print("[DebuffSpell] Casting PROJECTILE debuff with direction: %s" % actual_dir)
			_cast_projectile_debuff(ctx, owner_entity, actual_dir)
		SpellItemDef.DeliveryMode.AOE:
			print("[DebuffSpell] Casting AOE debuff")
			_cast_aoe_debuff(ctx, owner_entity)


func _cast_projectile_debuff(ctx: CombatContext, owner_entity: Node, dir: Vector2) -> void:
	print("[DebuffSpell] _cast_projectile_debuff called with dir: %s" % dir)
	
	var config: Dictionary = {}
	if _instance != null and _instance.def != null and _instance.def is SpellItemDef:
		var spell_def: SpellItemDef = _instance.def as SpellItemDef
		config = spell_def.get_projectile_config()
	
	var scene: PackedScene = config.get("scene", preload("res://Scenes/Templates/EquipmentItems/Projectile_template.tscn"))
	
	if scene == null:
		push_error("[DebuffSpell] projectile_scene is null!")
		return

	print("[DebuffSpell] Instantiating projectile scene: %s" % scene.resource_path)
	
	var node: Node = scene.instantiate()
	var projectile: Projectile = node as Projectile
	if projectile == null:
		push_error("[DebuffSpell] projectile_scene '%s' is not a Projectile!" % scene.resource_path)
		if is_instance_valid(node):
			node.queue_free()
		return

	# Create launch data from spell def config
	var launch: ProjectileLaunchData = ProjectileLaunchData.new()
	launch.context = ctx
	launch.snapshot = null
	launch.owner = owner_entity
	launch.origin = owner_entity.global_position if owner_entity is Node2D else Vector2.ZERO
	launch.direction = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	launch.velocity = launch.direction * config.get("speed", 450.0)
	
	print("[DebuffSpell] DEBUG - Launch direction: %s, velocity: %s" % [launch.direction, launch.velocity])
	
	# Inherit owner velocity if configured
	var inherit_vel: float = config.get("inherit_velocity", 0.0)
	if inherit_vel > 0.0 and owner_entity is CharacterBody2D:
		var owner_body: CharacterBody2D = owner_entity as CharacterBody2D
		launch.velocity += owner_body.velocity * clampf(inherit_vel, 0.0, 1.0)

	launch.gravity = config.get("gravity", 0.0)
	launch.lifetime_sec = config.get("lifetime", 2.0)
	launch.damage = 0.0  # Debuff projectiles deal NO damage
	launch.pierce = 0
	launch.radius = max(1.0, config.get("radius", 6.0))
	launch.max_range = max(0.0, config.get("range", 0.0))
	launch.collision_mask = config.get("collision_mask", 0x7FFFFFFF)
	launch.sprite_texture = config.get("texture")
	launch.sprite_tint = config.get("tint", Color.WHITE)

	projectile.global_position = launch.origin
	projectile.setup(launch)

	# Hook into projectile collision to apply debuff
	if not projectile.area_entered.is_connected(_on_projectile_hit):
		projectile.area_entered.connect(_on_projectile_hit.bindv([ctx, _instance]))

	# Add to scene
	var parent: Node = owner_entity.get_parent() if owner_entity.get_parent() != null else get_tree().current_scene
	print("[DebuffSpell] Adding projectile to parent: %s at position %s" % [parent.name, launch.origin])
	parent.add_child(projectile)
	print("[DebuffSpell] ✓ Projectile spawned successfully")


func _on_projectile_hit(area: Area2D, ctx: CombatContext, item_instance: ItemInstance) -> void:
	if area == null:
		return

	var caster_faction: Faction = _get_faction(ctx.owner)
	if caster_faction == null:
		return

	# Walk up hierarchy to find the Entity root
	var parent: Node = area.get_parent()
	while parent != null:
		if parent is Entity:
			if not caster_faction.is_hostile_to(parent):
				break

			# Dispatch to all debuff attributes
			for attr: ItemAttribute in item_instance.attributes:
				if attr == null or not attr is DebuffSpellAttribute:
					continue
				(attr as DebuffSpellAttribute).apply_debuff_to_target(parent, ctx, item_instance)

			# Remove the projectile after applying debuff
			if area.get_parent() is Projectile:
				area.get_parent().queue_free()
			break
		parent = parent.get_parent()


func _cast_aoe_debuff(ctx: CombatContext, owner_entity: Node) -> void:
	# Get AOE config from SpellItemDef
	var aoe_radius: float = 150.0
	var aoe_instant: bool = true
	var aoe_travel_time: float = 0.5
	
	if _instance != null and _instance.def != null and _instance.def is SpellItemDef:
		var spell_def: SpellItemDef = _instance.def as SpellItemDef
		var config: Dictionary = spell_def.get_aoe_config()
		aoe_radius = config.get("radius", 150.0)
		aoe_instant = config.get("instant", true)
		aoe_travel_time = config.get("travel_time", 0.5)
	
	var caster_pos: Vector2 = owner_entity.global_position if owner_entity is Node2D else Vector2.ZERO

	if aoe_instant:
		_apply_aoe_debuff_instantly(ctx, caster_pos, owner_entity, aoe_radius)
	else:
		# Create a timer for travel time, then apply
		var t: Timer = Timer.new()
		t.one_shot = true
		t.wait_time = aoe_travel_time
		owner_entity.add_child(t)
		t.timeout.connect(Callable(self, "_apply_aoe_debuff_instantly").bindv([ctx, caster_pos, owner_entity, aoe_radius]), CONNECT_ONE_SHOT)
		t.start()


func _apply_aoe_debuff_instantly(ctx: CombatContext, origin: Vector2, owner_entity: Node, aoe_radius: float) -> void:
	print("[DebuffSpell] Applying AOE debuff at %s with radius %f" % [origin, aoe_radius])

	if not owner_entity is Node2D:
		push_warning("[DebuffSpell] owner_entity must be Node2D for AoE")
		return

	var owner_2d: Node2D = owner_entity as Node2D
	var space: PhysicsDirectSpaceState2D = owner_2d.get_world_2d().direct_space_state
	
	# Query for entities in AoE radius
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = aoe_radius
	query.shape = circle

	var transform: Transform2D = Transform2D()
	transform.origin = origin
	query.transform = transform

	# Query for entities
	var results: Array[Dictionary] = space.intersect_shape(query)
	print("[DebuffSpell] AoE query found %d results" % results.size())
	
	var caster_faction: Faction = _get_faction(ctx.owner)
	var targets_hit: Array[String] = []
	var processed_entities: Dictionary = {}
	
	for result: Dictionary in results:
		var collider: Node2D = result.get("collider")
		if collider == null:
			continue

		# SKIP CASTER'S COLLIDERS
		var collider_parent: Node = collider.get_parent()
		if collider_parent == ctx.owner or collider == ctx.owner:
			continue

		# Walk up hierarchy to find the Entity
		var entity: Node = collider
		var found_entity: Entity = null
		
		while entity != null:
			if entity is Entity:
				found_entity = entity as Entity
				break
			entity = entity.get_parent()
		
		if found_entity == null:
			continue
		
		# PREVENT DUPLICATE PROCESSING
		if found_entity in processed_entities:
			continue
		
		processed_entities[found_entity] = true
		
		# Only apply debuff to hostile entities
		if caster_faction == null or not caster_faction.is_hostile_to(found_entity):
			continue
		
		targets_hit.append(found_entity.name)
		
		# Dispatch to all debuff attributes
		for attr: ItemAttribute in ctx.item_instance.attributes:
			if attr == null or not attr is DebuffSpellAttribute:
				continue
			var debuff_attr: DebuffSpellAttribute = attr as DebuffSpellAttribute
			debuff_attr.apply_debuff_to_target(found_entity, ctx, ctx.item_instance)
	
	# Print summary of targets hit
	if targets_hit.is_empty():
		print("[DebuffSpell] ✗ No valid targets hit")
	else:
		print("[DebuffSpell] ✓ Debuff applied to: %s" % ", ".join(targets_hit))


func _get_faction(entity: Node) -> Faction:
	"""Helper to get Faction component from an entity"""
	if entity == null:
		return null
	
	if entity is Entity:
		return (entity as Entity).find_component(&"Faction") as Faction
	
	# Fallback for non-Entity nodes
	return entity.get_node_or_null("Faction") as Faction

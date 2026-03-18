extends Spell
class_name DebuffSpell

enum DebuffMode { PROJECTILE, AOE }

# Debuff configuration
@export var debuff_mode: DebuffMode = DebuffMode.PROJECTILE
@export_range(50.0, 500.0, 10.0) var aoe_radius: float = 150.0
@export var aoe_instant: bool = true
@export_range(0.1, 5.0, 0.1) var aoe_travel_time: float = 0.5

@export var projectile_spec: ProjectileSpec
@export var projectile_scene: PackedScene = preload("res://Scenes/Templates/EquipmentItems/Projectile_template.tscn")
@export_range(0.0, 5000.0, 1.0) var projectile_speed: float = 450.0
@export_range(-5000.0, 5000.0, 1.0) var projectile_gravity: float = 0.0
@export_range(0.05, 30.0, 0.05) var projectile_lifetime_sec: float = 2.0
@export_range(1.0, 256.0, 1.0) var projectile_radius: float = 6.0
@export_range(0.0, 1.0, 0.01) var inherit_owner_velocity: float = 0.0
@export_range(0.0, 5000.0, 1.0) var projectile_range: float = 0.0
@export var projectile_collision_mask: int = 0x7FFFFFFF
@export var projectile_sprite_texture: Texture2D
@export var projectile_sprite_tint: Color = Color.WHITE


func _do_cast(owner_entity: Node, dir: Vector2) -> void:
	if _instance == null or owner_entity == null:
		print("[DebuffSpell] Cannot cast: instance=%s, owner=%s" % [_instance, owner_entity])
		return

	print("[DebuffSpell] Casting debuff spell '%s', mode=%s" % [name, DebuffMode.keys()[debuff_mode]])
	
	var ctx: CombatContext = _make_context(owner_entity, dir)

	match debuff_mode:
		DebuffMode.PROJECTILE:
			print("[DebuffSpell] Casting PROJECTILE debuff")
			_cast_projectile_debuff(ctx, owner_entity, dir)
		DebuffMode.AOE:
			print("[DebuffSpell] Casting AOE debuff")
			_cast_aoe_debuff(ctx, owner_entity)


func _cast_projectile_debuff(ctx: CombatContext, owner_entity: Node, dir: Vector2) -> void:
	var scene: PackedScene = projectile_scene
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

	# Create launch data
	var launch: ProjectileLaunchData = ProjectileLaunchData.new()
	launch.context = ctx
	launch.snapshot = null
	launch.owner = owner_entity
	launch.origin = owner_entity.global_position if owner_entity is Node2D else Vector2.ZERO
	launch.direction = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	launch.velocity = launch.direction * projectile_speed
	
	# Inherit owner velocity if configured
	if inherit_owner_velocity > 0.0 and owner_entity is CharacterBody2D:
		var owner_body: CharacterBody2D = owner_entity as CharacterBody2D
		launch.velocity += owner_body.velocity * clampf(inherit_owner_velocity, 0.0, 1.0)

	launch.gravity = projectile_gravity
	launch.lifetime_sec = projectile_lifetime_sec
	launch.damage = 0.0  # Debuff projectiles deal NO damage
	launch.pierce = 0
	launch.radius = max(1.0, projectile_radius)
	launch.max_range = max(0.0, projectile_range)
	launch.collision_mask = projectile_collision_mask
	launch.sprite_texture = projectile_sprite_texture
	launch.sprite_tint = projectile_sprite_tint

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

	print("[DebuffSpell] Projectile hit: %s" % area.name)

	# Check if this is an entity with a hurtbox
	var parent: Node = area.get_parent()
	while parent != null:
		if parent is Entity:
			print("[DebuffSpell] Applying debuff to entity: %s" % parent.name)
			
			# Apply debuff via attributes
			var hit_event: HitEvent = HitEvent.new()
			hit_event.victim = parent
			hit_event.attacker = ctx.owner
			hit_event.damage = 0.0
			
			# Dispatch to all attributes
			for attr: ItemAttribute in item_instance.attributes:
				if attr == null:
					continue
				print("[DebuffSpell] Applying attribute: %s" % attr.get_class())
				attr.on_hit(ctx, hit_event, item_instance)
			
			# Remove the projectile after applying debuff
			if area.get_parent() is Projectile:
				area.get_parent().queue_free()
			break
		parent = parent.get_parent()


func _cast_aoe_debuff(ctx: CombatContext, owner_entity: Node) -> void:
	var caster_pos: Vector2 = owner_entity.global_position if owner_entity is Node2D else Vector2.ZERO

	if aoe_instant:
		_apply_aoe_debuff_instantly(ctx, caster_pos, owner_entity)
	else:
		# Create a timer for travel time, then apply
		var t: Timer = Timer.new()
		t.one_shot = true
		t.wait_time = aoe_travel_time
		owner_entity.add_child(t)
		t.timeout.connect(Callable(self, "_apply_aoe_debuff_instantly").bindv([ctx, caster_pos, owner_entity]), CONNECT_ONE_SHOT)
		t.start()


func _apply_aoe_debuff_instantly(ctx: CombatContext, origin: Vector2, owner_entity: Node) -> void:
	print("[DebuffSpell] Applying AOE debuff at %s with radius %f" % [origin, aoe_radius])

	# Get the world space for queries
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
	
	for result: Dictionary in results:
		var collider: Node2D = result.get("collider")
		if collider == null:
			continue

		# Check if it's an entity
		var entity: Node = collider
		if entity is Entity:
			print("[DebuffSpell] Applying debuff to entity: %s" % entity.name)
			
			var hit_event: HitEvent = HitEvent.new()
			hit_event.victim = entity
			hit_event.attacker = ctx.owner
			hit_event.damage = 0.0
			
			# Dispatch to all attributes
			for attr: ItemAttribute in ctx.item_instance.attributes:
				if attr == null:
					continue
				print("[DebuffSpell] Applying attribute: %s" % attr.get_class())
				attr.on_hit(ctx, hit_event, ctx.item_instance)

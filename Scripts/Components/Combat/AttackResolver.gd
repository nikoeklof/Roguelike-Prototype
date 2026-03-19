extends RefCounted
class_name AttackResolver


static func resolve(ctx: CombatContext, variant: AttackVariant) -> AttackSnapshot:
	var snap: AttackSnapshot = AttackSnapshot.new()
	snap.context = ctx
	snap.item_instance = ctx.item_instance
	snap.spread_roll = ctx.spread_roll if ctx != null else 0

	var stats: ItemStats = null
	if ctx != null and ctx.item_instance != null:
		stats = ctx.item_instance.compute_stats(ctx)
	else:
		stats = ItemStats.new()

	snap.stats = stats

	if stats != null:
		snap.damage = float(stats.damage)
		snap.cooldown_sec = float(stats.cooldown_sec)
		snap.windup_time = float(stats.windup_time)
		snap.active_time = float(stats.active_time)
		snap.recovery_time = float(stats.recovery_time)
		snap.knockback = float(stats.knockback)
		snap.hitbox_offset = stats.hitbox_offset
		snap.hitbox_size = stats.hitbox_size
		snap.projectile_count = maxi(1, stats.projectile_count)
		snap.pierce = maxi(0, stats.pierce)

		# New: stats own runtime spread values.
		snap.spread_degrees = max(0.0, stats.spread_degrees)
		snap.spread_pattern_degrees = max(0.0, stats.spread_pattern_degrees)
		snap.muzzle_offset = stats.muzzle_offset

	if ctx != null and ctx.item_instance != null:
		snap.ranged_mode = int(ctx.item_instance.ranged_mode)

	_apply_variant_defaults(snap, variant)
	_apply_item_defaults(snap, ctx.item if ctx != null else null)
	
	# Apply attack speed multiplier from entity stats
	if ctx != null and ctx.owner != null:
		var entity_stats: Stats = _find_entity_stats(ctx.owner)
		if entity_stats != null:
			var attack_speed_mult: float = entity_stats.attack_speed_mult()
			if attack_speed_mult != 1.0:
				snap.cooldown_sec /= attack_speed_mult
				snap.windup_time /= attack_speed_mult
				snap.recovery_time /= attack_speed_mult
	
	return snap


static func _find_entity_stats(owner: Node) -> Stats:
	if owner == null:
		return null
	
	# Try direct node lookup first
	var direct: Stats = owner.get_node_or_null("Stats") as Stats
	if direct != null:
		return direct
	
	# Fallback to Entity component system
	if owner is Entity:
		var entity: Entity = owner as Entity
		var found: Stats = entity.get_component(&"Stats") as Stats
		if found != null:
			return found
	
	return null


static func _apply_variant_defaults(snap: AttackSnapshot, variant: AttackVariant) -> void:
	if snap == null or variant == null:
		return

	if snap.windup_time <= 0.0:
		snap.windup_time = max(0.0, variant.windup_time)

	if snap.recovery_time <= 0.0:
		snap.recovery_time = max(0.0, variant.recovery_time)

	if variant is MeleeSlashVariant:
		var melee: MeleeSlashVariant = variant as MeleeSlashVariant
		if snap.hitbox_offset == Vector2.ZERO:
			snap.hitbox_offset = melee.offset
		if snap.hitbox_size == Vector2.ZERO:
			snap.hitbox_size = melee.size

	if variant is RangedFireVariant:
		var ranged: RangedFireVariant = variant as RangedFireVariant

		if snap.ranged_mode < 0:
			snap.ranged_mode = int(ranged.default_mode)

		# Stats take priority. Variant/profile only fills defaults.
		if snap.muzzle_offset == Vector2.ZERO:
			snap.muzzle_offset = ranged.muzzle_offset

		if snap.spread_degrees <= 0.0:
			snap.spread_degrees = max(0.0, ranged.spread_degrees)

		if snap.spread_pattern_degrees <= 0.0:
			snap.spread_pattern_degrees = max(0.0, ranged.spread_pattern_degrees)

		snap.hitscan_range = max(1.0, ranged.hitscan_range)
		snap.beam_range = max(1.0, ranged.beam_range)
		snap.beam_duration_sec = max(0.01, ranged.beam_duration_sec)
		snap.beam_tick_sec = max(0.01, ranged.beam_tick_sec)

		if ranged.projectile_spec != null:
			snap.projectile_spec = ranged.projectile_spec
			snap.projectile_scene = ranged.projectile_spec.scene
			snap.projectile_speed = ranged.projectile_spec.speed
			snap.projectile_gravity = ranged.projectile_spec.gravity
			snap.projectile_lifetime_sec = ranged.projectile_spec.lifetime_sec
			snap.projectile_radius = max(1.0, ranged.projectile_spec.radius)
			snap.projectile_inherit_owner_velocity = clampf(ranged.projectile_spec.inherit_owner_velocity, 0.0, 1.0)
			snap.projectile_range = max(0.0, ranged.projectile_spec.range)
			snap.projectile_collision_mask = ranged.projectile_spec.collision_mask
			snap.projectile_sprite_texture = ranged.projectile_spec.sprite_texture
			snap.projectile_sprite_tint = ranged.projectile_spec.sprite_tint
		else:
			snap.projectile_scene = ranged.projectile_scene
			snap.projectile_speed = ranged.projectile_speed
			snap.projectile_gravity = ranged.projectile_gravity
			snap.projectile_lifetime_sec = ranged.projectile_lifetime_sec
			snap.projectile_radius = max(1.0, ranged.projectile_radius)
			snap.projectile_inherit_owner_velocity = clampf(ranged.inherit_owner_velocity, 0.0, 1.0)
			snap.projectile_range = max(0.0, ranged.projectile_range)
			snap.projectile_collision_mask = ranged.projectile_collision_mask
			snap.projectile_sprite_texture = ranged.projectile_sprite_texture
			snap.projectile_sprite_tint = ranged.projectile_sprite_tint


static func _apply_item_defaults(snap: AttackSnapshot, item: Node) -> void:
	if snap == null or item == null:
		return

	if item is MeleeWeapon:
		var melee: MeleeWeapon = item as MeleeWeapon

		if snap.hitbox_offset == Vector2.ZERO:
			snap.hitbox_offset = melee.default_hitbox_offset

		if snap.hitbox_size == Vector2.ZERO:
			snap.hitbox_size = melee.default_hitbox_size

		if snap.active_time <= 0.0:
			snap.active_time = max(0.01, melee.default_active_time)

		if is_zero_approx(snap.knockback):
			snap.knockback = max(0.0, melee.default_knockback)

		if snap.windup_time <= 0.0:
			snap.windup_time = max(0.0, melee.default_windup)

		if snap.recovery_time <= 0.0:
			snap.recovery_time = max(0.0, melee.default_recovery)

	elif item is RangedWeapon:
		var ranged: RangedWeapon = item as RangedWeapon

		if snap.windup_time <= 0.0:
			snap.windup_time = max(0.0, ranged.default_windup)

		if snap.recovery_time <= 0.0:
			snap.recovery_time = max(0.0, ranged.default_recovery)

		if snap.projectile_spec == null and snap.projectile_scene == null:
			if ranged.projectile_spec != null:
				snap.projectile_spec = ranged.projectile_spec
				snap.projectile_scene = ranged.projectile_spec.scene
				snap.projectile_speed = ranged.projectile_spec.speed
				snap.projectile_gravity = ranged.projectile_spec.gravity
				snap.projectile_lifetime_sec = ranged.projectile_spec.lifetime_sec
				snap.projectile_radius = max(1.0, ranged.projectile_spec.radius)
				snap.projectile_inherit_owner_velocity = clampf(ranged.projectile_spec.inherit_owner_velocity, 0.0, 1.0)
				snap.projectile_range = max(0.0, ranged.projectile_spec.range)
				snap.projectile_collision_mask = ranged.projectile_spec.collision_mask
				snap.projectile_sprite_texture = ranged.projectile_spec.sprite_texture
				snap.projectile_sprite_tint = ranged.projectile_spec.sprite_tint
			else:
				snap.projectile_scene = ranged.projectile_scene
				snap.projectile_speed = ranged.projectile_speed
				snap.projectile_gravity = ranged.projectile_gravity
				snap.projectile_lifetime_sec = ranged.projectile_lifetime_sec
				snap.projectile_radius = max(1.0, ranged.projectile_radius)
				snap.projectile_inherit_owner_velocity = clampf(ranged.inherit_owner_velocity, 0.0, 1.0)
				snap.projectile_range = max(0.0, ranged.projectile_range)
				snap.projectile_collision_mask = ranged.projectile_collision_mask
				snap.projectile_sprite_texture = ranged.projectile_sprite_texture
				snap.projectile_sprite_tint = ranged.projectile_sprite_tint

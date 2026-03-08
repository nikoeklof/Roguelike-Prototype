extends RefCounted
class_name AttackResolver


static func resolve(ctx: CombatContext, variant: AttackVariant) -> AttackSnapshot:
	var snap: AttackSnapshot = AttackSnapshot.new()
	snap.context = ctx
	snap.item_instance = ctx.item_instance
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
	if ctx != null and ctx.item_instance != null:
		snap.ranged_mode = int(ctx.item_instance.ranged_mode)
	_apply_variant_defaults(snap, variant)
	_apply_item_defaults(snap, ctx.item if ctx != null else null)
	return snap


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

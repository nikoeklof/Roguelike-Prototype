extends RefCounted
class_name StatId

const DAMAGE: StringName = &"damage"
const COOLDOWN_SEC: StringName = &"cooldown_sec"
const WINDUP_TIME: StringName = &"windup_time"
const RECOVERY_TIME: StringName = &"recovery_time"

const PROJECTILE_COUNT: StringName = &"projectile_count"
const PIERCE: StringName = &"pierce"
const SPREAD_DEGREES: StringName = &"spread_degrees"
const SPREAD_PATTERN_DEGREES: StringName = &"spread_pattern_degrees"
const MUZZLE_OFFSET: StringName = &"muzzle_offset"

const MOVE_SPEED_MULT: StringName = &"move_speed_mult"
const DAMAGE_TAKEN_MULT: StringName = &"damage_taken_mult"
const FLAT_DAMAGE_REDUCTION: StringName = &"flat_damage_reduction"

const BONUS_MAX_HP: StringName = &"bonus_max_hp"
const HEAL_ON_EQUIP: StringName = &"heal_on_equip"

const ACTIVE_TIME: StringName = &"active_time"
const KNOCKBACK: StringName = &"knockback"
const HITBOX_OFFSET: StringName = &"hitbox_offset"
const HITBOX_SIZE: StringName = &"hitbox_size"

static func all() -> PackedStringArray:
	return PackedStringArray([
		String(DAMAGE),
		String(COOLDOWN_SEC),
		String(WINDUP_TIME),
		String(RECOVERY_TIME),
		String(PROJECTILE_COUNT),
		String(PIERCE),
		String(SPREAD_DEGREES),
		String(SPREAD_PATTERN_DEGREES),
		String(MUZZLE_OFFSET),
		String(MOVE_SPEED_MULT),
		String(DAMAGE_TAKEN_MULT),
		String(FLAT_DAMAGE_REDUCTION),
		String(BONUS_MAX_HP),
		String(HEAL_ON_EQUIP),
		String(ACTIVE_TIME),
		String(KNOCKBACK),
		String(HITBOX_OFFSET),
		String(HITBOX_SIZE),
	])

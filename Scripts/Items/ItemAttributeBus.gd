extends RefCounted
class_name ItemAttributeBus

# Centralized, deterministic dispatch for attribute hooks.
# This prevents every executor/system from hand-looping attributes.

const DOMAIN_STATS: StringName = &"stats"
const DOMAIN_ATTACK_START: StringName = &"attack_start"
const DOMAIN_HIT: StringName = &"hit"
const DOMAIN_PROJECTILE_SPAWN: StringName = &"projectile_spawn"
const DOMAIN_RANGED_SHOT: StringName = &"ranged_shot"
const DOMAIN_CAST: StringName = &"cast"
const DOMAIN_PARRY: StringName = &"parry"

static func _sorted_attrs(inst: ItemInstance) -> Array[ItemAttribute]:
	var out: Array[ItemAttribute] = []
	if inst == null:
		return out
	for a: ItemAttribute in inst.attributes:
		if a != null:
			out.append(a)
	out.sort_custom(func(a: ItemAttribute, b: ItemAttribute) -> bool:
		# Stable ordering by id, then display_name.
		var ai := String(a.id)
		var bi := String(b.id)
		if ai == bi:
			return a.display_name < b.display_name
		return ai < bi
	)
	return out

static func dispatch_attack_start(ctx: CombatContext, inst: ItemInstance) -> void:
	for a: ItemAttribute in _sorted_attrs(inst):
		if a.applies_to_domain(DOMAIN_ATTACK_START):
			a.on_attack_start(ctx, inst)

static func dispatch_modify_ranged_shot(ctx: CombatContext, shot: RangedShotData, inst: ItemInstance) -> void:
	for a: ItemAttribute in _sorted_attrs(inst):
		if a.applies_to_domain(DOMAIN_RANGED_SHOT):
			a.modify_ranged_shot(ctx, shot, inst)

static func dispatch_projectile_spawn(ctx: CombatContext, projectile: Projectile, inst: ItemInstance) -> void:
	for a: ItemAttribute in _sorted_attrs(inst):
		if a.applies_to_domain(DOMAIN_PROJECTILE_SPAWN):
			a.on_projectile_spawn(ctx, projectile, inst)

static func dispatch_hit(ctx: CombatContext, hit: HitEvent, inst: ItemInstance) -> void:
	for a: ItemAttribute in _sorted_attrs(inst):
		if a.applies_to_domain(DOMAIN_HIT):
			a.on_hit(ctx, hit, inst)

static func dispatch_cast_start(ctx: CombatContext, inst: ItemInstance) -> void:
	for a: ItemAttribute in _sorted_attrs(inst):
		if a.applies_to_domain(DOMAIN_CAST):
			a.on_cast_start(ctx, inst)

static func dispatch_cast_apply(ctx: CombatContext, inst: ItemInstance) -> void:
	for a: ItemAttribute in _sorted_attrs(inst):
		if a.applies_to_domain(DOMAIN_CAST):
			a.on_cast_apply(ctx, inst)

static func dispatch_parry(ctx: CombatContext, inst: ItemInstance) -> void:
	for a: ItemAttribute in _sorted_attrs(inst):
		if a.applies_to_domain(DOMAIN_PARRY):
			a.on_parry(ctx, inst)

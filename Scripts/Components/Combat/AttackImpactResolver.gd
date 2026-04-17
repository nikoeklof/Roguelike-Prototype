extends RefCounted
class_name AttackImpactResolver


static func apply_hit(
	ctx: CombatContext,
	snapshot: AttackSnapshot,
	victim_root: Node,
	collider: Node,
	hit_dir: Vector2,
	base_damage: float = -1.0
) -> bool:
	if ctx == null:
		return false
	if not is_instance_valid(ctx.owner):
		return false
	if victim_root == null:
		return false
	if victim_root == ctx.owner:
		return false

	if not CombatQuery.can_damage(ctx.owner, victim_root):
		return false

	var hp: Health = CombatQuery.find_health(victim_root)
	if hp == null:
		return false

	var resolved_dir: Vector2 = hit_dir
	if resolved_dir.length() < 0.001:
		resolved_dir = Vector2.RIGHT
	else:
		resolved_dir = resolved_dir.normalized()

	var resolved_damage: float = 0.0
	if base_damage >= 0.0:
		resolved_damage = base_damage
	elif snapshot != null:
		resolved_damage = snapshot.damage

	var hit: HitEvent = HitEvent.new()
	hit.attacker = ctx.owner
	hit.item_node = ctx.item
	hit.item_instance = ctx.item_instance
	hit.victim = victim_root
	hit.collider = collider
	hit.dir = resolved_dir
	hit.base_damage = resolved_damage
	hit.damage = resolved_damage

	if ctx.item_instance != null:
		ItemAttributeBus.dispatch_hit(ctx, hit, ctx.item_instance)

	hp.take_damage(hit.damage, ctx.owner)

	var knockback: float = 0.0
	if snapshot != null:
		knockback = snapshot.knockback

	if knockback > 0.0 and victim_root is CharacterBody2D:
		var body: CharacterBody2D = victim_root as CharacterBody2D
		body.velocity += resolved_dir * knockback

	return true

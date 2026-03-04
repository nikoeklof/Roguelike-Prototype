extends ItemAttribute
class_name LungeAttribute

@export var distance: float = 80.0
@export var duration_sec: float = 0.12
@export var stop_on_hit: bool = true
@export var wall_padding: float = 2.0

@export var trans_type: Tween.TransitionType = Tween.TRANS_QUAD
@export var ease_type: Tween.EaseType = Tween.EASE_OUT

const _META_TWEEN: StringName = &"__lunge_tween"
const _META_LAST: StringName = &"__lunge_last"


func on_attack_start(context: CombatContext, _item_instance: ItemInstance) -> void:
	if context == null:
		return

	var owner: Node = context.owner
	if owner == null:
		return

	if not owner is CharacterBody2D:
		return

	var body: CharacterBody2D = owner as CharacterBody2D

	# Direction
	var dir: Vector2 = context.aim_dir
	if dir.length() < 0.001:
		dir = Vector2.RIGHT
	dir = dir.normalized()

	# Cancel previous lunge if active
	var prev: Variant = body.get_meta(_META_TWEEN, null)
	if prev is Tween:
		var prev_tween: Tween = prev
		if is_instance_valid(prev_tween):
			prev_tween.kill()

	body.set_meta(_META_LAST, 0.0)

	# Clamp by collision sweep
	var safe_dist: float = _compute_safe_lunge_distance(body, dir, distance, wall_padding)
	if safe_dist <= 0.01:
		_clear_lunge_meta(body)
		return

	var tween: Tween = body.create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(trans_type)
	tween.set_ease(ease_type)

	body.set_meta(_META_TWEEN, tween)

	var callable: Callable = Callable(self, "_lunge_step").bind(body, dir)
	tween.tween_method(callable, 0.0, safe_dist, max(duration_sec, 0.001))

	var end_cb: Callable = Callable(self, "_clear_lunge_meta").bind(body)
	tween.tween_callback(end_cb)


func _lunge_step(traveled: float, body: CharacterBody2D, dir: Vector2) -> void:
	if body == null or not is_instance_valid(body):
		return

	var last_variant: Variant = body.get_meta(_META_LAST, 0.0)
	var last: float = float(last_variant)

	var step: float = traveled - last
	if step <= 0.0:
		return

	body.set_meta(_META_LAST, traveled)

	var collision: KinematicCollision2D = body.move_and_collide(dir * step)
	if collision != null and stop_on_hit:
		var tw_variant: Variant = body.get_meta(_META_TWEEN, null)
		if tw_variant is Tween:
			var tw: Tween = tw_variant
			if is_instance_valid(tw):
				tw.kill()
		_clear_lunge_meta(body)


func _compute_safe_lunge_distance(
	body: CharacterBody2D,
	dir: Vector2,
	desired: float,
	padding: float
) -> float:

	var shape_node: CollisionShape2D = _find_collision_shape(body)
	if shape_node == null or shape_node.shape == null:
		return desired

	var params: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	params.shape = shape_node.shape
	params.transform = shape_node.global_transform
	params.motion = dir * desired
	params.exclude = [body.get_rid()]
	params.collide_with_areas = false
	params.collide_with_bodies = true

	var space: PhysicsDirectSpaceState2D = body.get_world_2d().direct_space_state
	var result: Array = space.cast_motion(params)  # [safe_frac, unsafe_frac]

	var safe_frac: float = float(result[0])
	var safe_dist: float = desired * safe_frac

	return max(0.0, safe_dist - max(padding, 0.0))


func _find_collision_shape(root: Node) -> CollisionShape2D:
	var direct: CollisionShape2D = root.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if direct != null:
		return direct

	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is CollisionShape2D:
			return n as CollisionShape2D

		var children: Array = n.get_children()
		for child in children:
			if child is Node:
				stack.push_back(child)

	return null


func _clear_lunge_meta(body: CharacterBody2D) -> void:
	if body == null or not is_instance_valid(body):
		return

	body.set_meta(_META_TWEEN, null)
	body.set_meta(_META_LAST, null)

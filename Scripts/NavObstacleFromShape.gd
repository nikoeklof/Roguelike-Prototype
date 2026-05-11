extends NavigationObstacle2D
class_name NavObstacleFromShape

func _ready() -> void:
	avoidance_enabled = true
	var parent := get_parent()
	if not parent:
		return
	for child in parent.get_children():
		if child is CollisionShape2D:
			_build_from(child as CollisionShape2D)
			return

func _build_from(cs: CollisionShape2D) -> void:
	if cs.shape == null:
		return
	var raw := _shape_to_polygon(cs.shape)
	if raw.is_empty():
		return
	var xform := cs.transform
	var out := PackedVector2Array()
	out.resize(raw.size())
	for i in raw.size():
		out[i] = xform * raw[i]
	vertices = out

func _shape_to_polygon(shape: Shape2D) -> PackedVector2Array:
	if shape is RectangleShape2D:
		var half := (shape as RectangleShape2D).size * 0.5
		return PackedVector2Array([
			Vector2(-half.x, -half.y),
			Vector2( half.x, -half.y),
			Vector2( half.x,  half.y),
			Vector2(-half.x,  half.y),
		])
	if shape is CircleShape2D:
		var r := (shape as CircleShape2D).radius
		var pts := PackedVector2Array()
		for i in 12:
			var a := TAU * i / 12.0
			pts.append(Vector2(cos(a) * r, sin(a) * r))
		return pts
	if shape is CapsuleShape2D:
		var cap := shape as CapsuleShape2D
		var r := cap.radius
		var half_h := maxf(cap.height * 0.5 - r, 0.0)
		var pts := PackedVector2Array()
		var steps := 8
		# Upper cap: right → top → left (center at y = -half_h)
		for i in range(steps + 1):
			var a := PI * i / steps
			pts.append(Vector2(cos(a) * r, -half_h - sin(a) * r))
		# Lower cap: left → bottom → right (center at y = +half_h)
		for i in range(steps + 1):
			var a := PI + PI * i / steps
			pts.append(Vector2(cos(a) * r, half_h - sin(a) * r))
		return pts
	if shape is ConvexPolygonShape2D:
		return (shape as ConvexPolygonShape2D).points.duplicate()
	return PackedVector2Array()

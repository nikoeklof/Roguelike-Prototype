extends Node
class_name FloorGenerator

const N: int = 1
const E: int = 2
const S: int = 4
const W: int = 8

const DIR_N: Vector2i = Vector2i(0, -1)
const DIR_E: Vector2i = Vector2i(1, 0)
const DIR_S: Vector2i = Vector2i(0, 1)
const DIR_W: Vector2i = Vector2i(-1, 0)
const DIRS: Array[Vector2i] = [DIR_N, DIR_E, DIR_S, DIR_W]

class RoomNode:
	var coord: Vector2i
	var kind: StringName = &"NORMAL"
	var exits_mask: int = 0
	var depth: int = -1

	func _init(c: Vector2i) -> void:
		coord = c

class FloorPlan:
	var seed: int
	var rooms: Dictionary = {}       # Vector2i -> RoomNode
	var coords: Array[Vector2i] = [] # typed list of keys

	func _init(s: int) -> void:
		seed = s
		rooms = {}
		coords = []

	func add_room(c: Vector2i, kind: StringName = &"NORMAL") -> void:
		if rooms.has(c):
			return
		var n := RoomNode.new(c)
		n.kind = kind
		rooms[c] = n
		coords.append(c)

# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------
func generate(
	_seed: int,
	main_len: int = 18,

	# Branching derived from main_len:
	# branch_count ~= round(main_len * branch_density)
	branch_density: float = 0.35,

	# branch_len_max ~= ceil(main_len * branch_len_ratio), then clamped.
	branch_len_ratio: float = 0.35,
	branch_len_min: int = 2,
	branch_len_max_cap: int = 8,

	# Layout shaping
	clump_penalty: float = 3.0,
	straight_bias: float = 0.9,
	min_separation: int = 1
) -> FloorPlan:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed

	var plan := FloorPlan.new(_seed)

	# Build topology first.
	var origin: Vector2i = Vector2i.ZERO
	plan.add_room(origin, &"NORMAL")

	# --- Main path (biased) ---
	var path: Array[Vector2i] = [origin]
	var cur: Vector2i = origin
	var last_dir: Vector2i = Vector2i.ZERO

	for _i in range(main_len):
		var next: Vector2i = _pick_next_step( plan.rooms, cur, rng, last_dir, clump_penalty, straight_bias, min_separation )
		if next == _NOT_FOUND():
			break
		last_dir = next - cur
		cur = next
		path.append(cur)
		plan.add_room(cur, &"NORMAL")

	# --- Branching derived from main_len ---
	var derived_branch_count: int = max(0, int(round(float(main_len) * max(0.0, branch_density))))

	var derived_branch_max_len: int = int(ceil(float(main_len) * max(0.0, branch_len_ratio)))
	derived_branch_max_len = max(branch_len_min, derived_branch_max_len)
	derived_branch_max_len = min(branch_len_max_cap, derived_branch_max_len)

	for _b in range(derived_branch_count):
		var anchor: Vector2i = path[rng.randi_range(0, path.size() - 1)]
		var branch_cur: Vector2i = anchor
		var branch_last_dir: Vector2i = Vector2i.ZERO

		# Each branch has a randomized length up to derived max (so floors don't feel samey).
		var this_len: int = rng.randi_range(branch_len_min, derived_branch_max_len)

		for _j in range(this_len):
			var next2: Vector2i = _pick_next_step( plan.rooms, branch_cur, rng, branch_last_dir, clump_penalty, straight_bias, min_separation )
			if next2 == _NOT_FOUND():
				break
			branch_last_dir = next2 - branch_cur
			branch_cur = next2
			plan.add_room(branch_cur, &"NORMAL")

	# Exits from adjacency
	_compute_exits(plan)

	# Choose START near centroid, prefer >=2 exits.
	var start: Vector2i = _pick_center_start(plan)

	for c: Vector2i in plan.coords:
		(plan.rooms[c] as RoomNode).kind = &"NORMAL"
	(plan.rooms[start] as RoomNode).kind = &"START"

	_assign_depths(plan, start)

	var boss_coord: Vector2i = _farthest_coord(plan)
	if boss_coord != start:
		(plan.rooms[boss_coord] as RoomNode).kind = &"BOSS"

	return plan

# -----------------------------------------------------------------------------
# Step selection (anti-clump)
# -----------------------------------------------------------------------------
func _NOT_FOUND() -> Vector2i:
	return Vector2i(2147483647, 2147483647)

func _pick_next_step(
	rooms: Dictionary,
	from: Vector2i,
	rng: RandomNumberGenerator,
	last_dir: Vector2i,
	clump_penalty: float,
	straight_bias: float,
	min_separation: int
) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for d: Vector2i in DIRS:
		var c: Vector2i = from + d
		if rooms.has(c):
			continue
		candidates.append(c)

	if candidates.is_empty():
		return _NOT_FOUND()

	var best_score: float = INF
	var best: Array[Vector2i] = []

	for c2: Vector2i in candidates:
		var dense: int = _adjacent_room_count(rooms, c2)
		var score: float = float(dense) * clump_penalty

		if min_separation > 0:
			score += float(_nearby_room_penalty(rooms, c2, min_separation))

		if last_dir != Vector2i.ZERO:
			var dir: Vector2i = c2 - from
			if dir == last_dir:
				score -= straight_bias

		if score < best_score:
			best_score = score
			best = [c2]
		elif is_equal_approx(score, best_score):
			best.append(c2)

	return best[rng.randi_range(0, best.size() - 1)]

func _adjacent_room_count(rooms: Dictionary, c: Vector2i) -> int:
	var count: int = 0
	if rooms.has(c + DIR_N): count += 1
	if rooms.has(c + DIR_E): count += 1
	if rooms.has(c + DIR_S): count += 1
	if rooms.has(c + DIR_W): count += 1
	return count

func _nearby_room_penalty(rooms: Dictionary, c: Vector2i, radius: int) -> int:
	var penalty: int = 0
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var dist: int = abs(dx) + abs(dy)
			if dist == 0 or dist > radius:
				continue
			var p: Vector2i = c + Vector2i(dx, dy)
			if rooms.has(p):
				penalty += 1
	return penalty

# -----------------------------------------------------------------------------
# Depth/exits/start/boss
# -----------------------------------------------------------------------------
func _assign_depths(plan: FloorPlan, start: Vector2i) -> void:
	for c: Vector2i in plan.coords:
		(plan.rooms[c] as RoomNode).depth = -1
	(plan.rooms[start] as RoomNode).depth = 0

	var q: Array[Vector2i] = [start]
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		var cd: int = (plan.rooms[cur] as RoomNode).depth

		for d: Vector2i in DIRS:
			var n: Vector2i = cur + d
			if plan.rooms.has(n):
				var nn := plan.rooms[n] as RoomNode
				if nn.depth == -1:
					nn.depth = cd + 1
					q.append(n)

func _farthest_coord(plan: FloorPlan) -> Vector2i:
	var best: Vector2i = plan.coords[0] if not plan.coords.is_empty() else Vector2i.ZERO
	var best_d: int = -1
	for c: Vector2i in plan.coords:
		var d: int = (plan.rooms[c] as RoomNode).depth
		if d > best_d:
			best_d = d
			best = c
	return best

func _compute_exits(plan: FloorPlan) -> void:
	for c: Vector2i in plan.coords:
		var mask: int = 0
		if plan.rooms.has(c + DIR_N): mask |= N
		if plan.rooms.has(c + DIR_E): mask |= E
		if plan.rooms.has(c + DIR_S): mask |= S
		if plan.rooms.has(c + DIR_W): mask |= W
		(plan.rooms[c] as RoomNode).exits_mask = mask

func _exit_count(mask: int) -> int:
	var count: int = 0
	if (mask & N) != 0: count += 1
	if (mask & E) != 0: count += 1
	if (mask & S) != 0: count += 1
	if (mask & W) != 0: count += 1
	return count

func _pick_center_start(plan: FloorPlan) -> Vector2i:
	var sum: Vector2 = Vector2.ZERO
	for c: Vector2i in plan.coords:
		sum += Vector2(float(c.x), float(c.y))
	var center: Vector2 = sum / float(max(1, plan.coords.size()))

	var best: Vector2i = plan.coords[0] if not plan.coords.is_empty() else Vector2i.ZERO
	var best_d2: float = INF
	var found_good: bool = false

	for c2: Vector2i in plan.coords:
		var node: RoomNode = plan.rooms[c2] as RoomNode
		var exits: int = _exit_count(node.exits_mask)
		var is_good: bool = exits >= 2

		if not found_good and not is_good:
			continue
		if is_good and not found_good:
			found_good = true
			best = c2
			best_d2 = center.distance_squared_to(Vector2(float(c2.x), float(c2.y)))
			continue
		if found_good and not is_good:
			continue

		var d2: float = center.distance_squared_to(Vector2(float(c2.x), float(c2.y)))
		if d2 < best_d2:
			best_d2 = d2
			best = c2
		elif is_equal_approx(d2, best_d2):
			var best_node: RoomNode = plan.rooms[best] as RoomNode
			var best_exits: int = _exit_count(best_node.exits_mask)
			if exits > best_exits:
				best = c2
			elif exits == best_exits:
				if c2.x < best.x or (c2.x == best.x and c2.y < best.y):
					best = c2

	if not found_good:
		best = plan.coords[0]
		best_d2 = INF
		for c3: Vector2i in plan.coords:
			var d23: float = center.distance_squared_to(Vector2(float(c3.x), float(c3.y)))
			if d23 < best_d2:
				best_d2 = d23
				best = c3
			elif is_equal_approx(d23, best_d2):
				if c3.x < best.x or (c3.x == best.x and c3.y < best.y):
					best = c3

	return best

extends RefCounted
class_name CombatContext

# A lightweight bundle of references/data for attack execution.
#
# This intentionally avoids reaching into the FSM or animation systems.
# Executors can query components they need through these references.

var owner: Node
var aim_dir: Vector2

# Optional component references (may be null depending on the entity).
var stats: Node
var equipment: Node
var tags: Node
var faction: Node
var capabilities: Node

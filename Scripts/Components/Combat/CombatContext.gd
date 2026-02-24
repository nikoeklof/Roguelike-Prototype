extends RefCounted
class_name CombatContext

# A lightweight bundle of references/data for attack execution.
# Executors can query components they need through these references.

var owner: Node
var aim_dir: Vector2

# The concrete equipment item node used for this attack (weapon/spell/etc).
var item: Node
# Optional runtime instance resource for the item (attribute/stat system).
var item_instance: ItemInstance

# Optional component references (may be null depending on the entity).
var stats: Node
var equipment: Node
var tags: Node
var faction: Node
var capabilities: Node

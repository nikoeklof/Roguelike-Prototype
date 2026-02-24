extends RefCounted
class_name HitEvent

# Who initiated the attack (usually the entity).
var attacker: Node
# The item node used (weapon/spell/shield node in equipment).
var item_node: Node
# The runtime item instance (resource).
var item_instance: ItemInstance

# What got hit (resolved root victim used by the executor).
var victim: Node
# The specific collider that triggered (area/body).
var collider: Node

# Direction at time of hit (usually aim dir).
var dir: Vector2 = Vector2.RIGHT

# Damage: attributes can modify these.
var base_damage: float = 0.0
var damage: float = 0.0

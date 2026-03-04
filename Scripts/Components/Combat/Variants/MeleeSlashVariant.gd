extends AttackVariant
class_name MeleeSlashVariant

# Hitbox geometry (local to hitbox node)
@export var offset: Vector2 = Vector2(18, 0)
@export var size: Vector2 = Vector2(26, 18)

# Behavior that is not part of ItemStats
@export var one_hit_per_target: bool = true

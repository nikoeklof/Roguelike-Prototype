extends AttackVariant
class_name MeleeSlashVariant

# Basic melee slash tuning
@export_range(0.0, 9999.0, 0.1) var base_damage: float = 1.0

# Hitbox geometry (local to owner)
@export var offset: Vector2 = Vector2(18, 0)
@export var size: Vector2 = Vector2(26, 18)

# How long the hitbox exists (seconds)
@export_range(0.01, 2.0, 0.01) var active_time: float = 0.10

# Optional: if true, only damage each target once per swing
@export var one_hit_per_target: bool = true

# Optional: knockback impulse applied to damaged targets (CharacterBody2D only)
@export_range(0.0, 5000.0, 1.0) var knockback: float = 0.0

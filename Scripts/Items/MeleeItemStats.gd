extends Resource
class_name MeleeItemStats

@export_group("Attack")
@export var damage: float = 10.0
@export_range(0.05, 10.0, 0.05) var cooldown_sec: float = 0.5
@export_range(0.0, 2.0, 0.01) var windup_time: float = 0.0
@export_range(0.01, 2.0, 0.01) var active_time: float = 0.10
@export_range(0.0, 2.0, 0.01) var recovery_time: float = 0.10

@export_group("Hitbox")
@export var hitbox_size: Vector2 = Vector2(40, 24)
@export var hitbox_offset: Vector2 = Vector2(20, 0)

@export_group("Feel")
@export var knockback: float = 0.0
@export_range(0.1, 2.0, 0.01) var move_speed_mult: float = 1.0

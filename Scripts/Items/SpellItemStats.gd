extends Resource
class_name SpellItemStats

@export_group("Timing")
@export_range(0.5, 60.0, 0.1) var cooldown_sec: float = 5.0
@export_range(0.0, 2.0, 0.01) var windup_time: float = 0.0
@export_range(0.0, 2.0, 0.01) var recovery_time: float = 0.0

@export_group("Feel")
@export_range(0.1, 2.0, 0.01) var move_speed_mult: float = 1.0

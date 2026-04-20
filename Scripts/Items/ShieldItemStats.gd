extends Resource
class_name ShieldItemStats

@export_group("Passive Defense")
@export var flat_damage_reduction: float = 0.0
@export_range(0.5, 1.0, 0.01) var damage_taken_mult: float = 1.0

@export_group("Movement")
@export_range(0.5, 1.5, 0.01) var move_speed_mult: float = 1.0

@export_group("Health")
@export var bonus_max_hp: float = 0.0
@export var heal_on_equip: float = 0.0

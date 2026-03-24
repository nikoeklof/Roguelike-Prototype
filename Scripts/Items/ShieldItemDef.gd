extends ItemDef
class_name ShieldItemDef

enum ShieldType {
	ACTIVE,    # Can block projectiles/melee, has movement penalty
	PASSIVE    # Stat buffs only, no active blocking
}

@export var shield_type: ShieldType = ShieldType.PASSIVE

# ACTIVE SHIELD STATS
@export_range(0.0, 1.0, 0.01) var block_damage_reduction: float = 0.7  # 70% reduction
@export_range(0.1, 0.9, 0.05) var movement_speed_mult_while_blocking: float = 0.6  # 40% slower

# PASSIVE SHIELD STATS
@export_range(0.0, 1.0, 0.01) var passive_damage_reduction_mult: float = 0.1  # 10% reduction
@export_range(0.8, 1.2, 0.05) var passive_movement_speed_mult: float = 0.95  # 5% slower
@export_range(0.0, 50.0, 1.0) var flat_damage_reduction: float = 0.0


func get_display_name() -> String:
	var type_name = ShieldType.keys()[shield_type]
	return "%s (%s)" % [resource_name, type_name]

extends Resource
class_name ItemDef

enum Category { MELEE, RANGED, SPELL, SHIELD }

@export var id: StringName = &""
@export var display_name: String = "Item"

@export var category: Category = Category.MELEE

# Base stats at level 0.
@export var base_stats: ItemStats

# Optional behavior/config profile for ranged-style attacks.
# This survives generic template spawning because it lives on the item data.
@export var ranged_attack_profile: RangedAttackProfile


func get_base_stats_safe() -> ItemStats:
	if base_stats != null:
		return base_stats
	return ItemStats.new()


func get_ranged_profile_safe() -> RangedAttackProfile:
	return ranged_attack_profile

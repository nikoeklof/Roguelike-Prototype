extends Resource
class_name ItemDef

enum Category { MELEE, RANGED, SPELL, SHIELD }

@export var id: StringName = &""
@export var display_name: String = "Item"

@export var category: Category = Category.MELEE

# Base stats at upgrade level 0.
@export var base_stats: ItemStats

# Per-upgrade additive increments.
# Example: damage=0.5 means each upgrade level adds +0.5 damage.
@export var upgrade_step: ItemStats

# Attribute pool allowed for this item template.
# At runtime we pick from this pool deterministically using the ItemInstance seed.
@export var allowed_attributes: Array[ItemAttribute] = []


func get_base_stats_safe() -> ItemStats:
	return base_stats if base_stats != null else ItemStats.new()

func get_upgrade_step_safe() -> ItemStats:
	return upgrade_step if upgrade_step != null else ItemStats.new()

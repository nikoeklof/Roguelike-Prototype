extends ItemDef
class_name RangedItemDef

# Ranged-specific: attack profile with spread, hitscan, beam configs
@export var ranged_attack_profile: RangedAttackProfile


func _init() -> void:
	category = Category.RANGED


func get_ranged_profile_safe() -> RangedAttackProfile:
	return ranged_attack_profile

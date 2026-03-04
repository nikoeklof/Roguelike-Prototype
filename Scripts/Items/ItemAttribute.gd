extends Resource
class_name ItemAttribute

@export var id: StringName = &""
@export var display_name: String = ""

# Editor-only: shown in the attribute picker tooltip.
@export_multiline var editor_description: String = ""

# Optional: used by the attribute bus to skip irrelevant attributes at runtime.
# If empty, the bus will fall back to default_domains() (and if that is also empty,
# the attribute is treated as "legacy" and will be queried for all domains).
@export var domains: PackedStringArray = PackedStringArray()


func get_domains() -> PackedStringArray:
	if domains != null and domains.size() > 0:
		return domains
	return default_domains()


# Override in derived attributes to declare intent without editing .tres files.
func default_domains() -> PackedStringArray:
	return PackedStringArray()

# ---- Hooks (keep your existing signatures/logic below) ----
func get_stat_additive(_context: CombatContext, _item_instance: ItemInstance) -> ItemStats:
	return null

func on_attack_start(_context: CombatContext, _item_instance: ItemInstance) -> void:
	pass

func on_hit(_context: CombatContext, _hit: HitEvent, _item_instance: ItemInstance) -> void:
	pass

func on_projectile_spawn(_context: CombatContext, _projectile: Projectile, _item_instance: ItemInstance) -> void:
	pass

func on_cast_start(_context: CombatContext, _item_instance: ItemInstance) -> void:
	pass

func on_cast_apply(_context: CombatContext, _item_instance: ItemInstance) -> void:
	pass

func on_parry(_context: CombatContext, _item_instance: ItemInstance) -> void:
	pass

func modify_ranged_shot(_context: CombatContext, _shot: RangedShotData, _item_instance: ItemInstance) -> void:
	pass

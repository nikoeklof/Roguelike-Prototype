extends Resource
class_name ItemAttribute

@export var id: StringName = &""
@export var display_name: String = ""

# Editor-only: shown in the attribute picker tooltip.
@export_multiline var editor_description: String = ""

# Domains let us scale to hundreds of attributes without asking every attribute
# about every calculation/event.
#
# If empty, the attribute is treated as "legacy" and will apply to all domains.
@export var domains: PackedStringArray = []

func default_domains() -> PackedStringArray:
	return PackedStringArray()

func get_domains() -> PackedStringArray:
	# If the resource doesn't set domains, fall back to script defaults.
	if domains.size() > 0:
		return domains
	return default_domains()

func applies_to_domain(domain: StringName) -> bool:
	var d: PackedStringArray = get_domains()
	if d.size() == 0:
		return true
	return String(domain) in d


# ---- Modifier pipeline (preferred) ----
func contribute_modifiers(_context: CombatContext, _item_instance: ItemInstance, _domain: StringName, _out_mods: Array) -> void:
	pass

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

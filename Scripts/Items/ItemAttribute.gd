extends Resource
class_name ItemAttribute

@export var id: StringName = &""
@export var display_name: String = "Attribute"
@export var local_seed_salt: int = 0

func get_local_rng(item_instance: ItemInstance) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var s := 0
	if item_instance != null:
		s = item_instance.seed
	s = int((s * 1103515245 + 12345) & 0x7fffffff)
	s = int((s + local_seed_salt) & 0x7fffffff)
	rng.seed = s
	return rng

# ---- Stat modification hook (optional) ----
func get_stat_additive(_context: CombatContext, _item_instance: ItemInstance) -> ItemStats:
	return null

# ---- Weapon / hit hooks ----
func on_attack_start(_context: CombatContext, _item_instance: ItemInstance) -> void:
	pass

func on_hit(_context: CombatContext, _hit: HitEvent, _item_instance: ItemInstance) -> void:
	pass

func on_projectile_spawn(_context: CombatContext, _projectile: Node, _item_instance: ItemInstance) -> void:
	pass

# ---- Spell hooks (NEW) ----
func on_cast_start(_context: CombatContext, _item_instance: ItemInstance) -> void:
	pass

func on_cast_apply(_context: CombatContext, _item_instance: ItemInstance) -> void:
	pass

# ---- Shield hooks ----
func on_block(_context: CombatContext, _item_instance: ItemInstance) -> void:
	pass

func on_parry(_context: CombatContext, _item_instance: ItemInstance) -> void:
	pass

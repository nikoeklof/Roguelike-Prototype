extends Shield
class_name TestShield

@export var label: String = "TestShield"

# Simple, testable passives.
@export var bonus_max_hp: float = 0.0
@export var heal_on_equip: float = 0.0

# Example stat modifiers (uses Stats modifier API).
@export var move_speed_mult: float = 1.0          # 1.0 = no change
@export var damage_taken_mult: float = 1.0        # <1 = tanky, >1 = squishy
@export var flat_damage_reduction: float = 0.0

var _key: StringName
var _owner: Node

func _ready() -> void:
	_key = StringName("shield_" + label)

func on_equipped(owner_entity: Node) -> void:
	_owner = owner_entity
	if owner_entity == null:
		return

	var hp := _find_health(owner_entity)
	if hp != null:
		if bonus_max_hp != 0.0:
			hp.add_max_hp(bonus_max_hp, heal_on_equip, false)
		elif heal_on_equip != 0.0:
			hp.heal(heal_on_equip)

	var stats := _find_stats(owner_entity)
	if stats != null:
		if not is_equal_approx(move_speed_mult, 1.0):
			stats.set_move_speed_mult(_key, move_speed_mult)
		if not is_equal_approx(damage_taken_mult, 1.0):
			stats.set_damage_taken_mult(_key, damage_taken_mult)
		if flat_damage_reduction != 0.0:
			stats.set_flat_damage_reduction(_key, flat_damage_reduction)

func on_unequipped(owner_entity: Node) -> void:
	var target := owner_entity if owner_entity != null else _owner
	if target == null:
		return

	var hp := _find_health(target)
	if hp != null and bonus_max_hp != 0.0:
		hp.add_max_hp(-bonus_max_hp, 0.0, false)

	var stats := _find_stats(target)
	if stats != null:
		stats.clear_move_speed_mult(_key)
		stats.clear_damage_taken_mult(_key)
		stats.clear_flat_damage_reduction(_key)

	_owner = null

func _find_health(root: Node) -> Health:
	if root is Entity:
		return (root as Entity).find_component(&"Health") as Health
	return root.get_node_or_null("Health") as Health

func _find_stats(root: Node) -> Stats:
	if root is Entity:
		return (root as Entity).find_component(&"Stats") as Stats
	return root.get_node_or_null("Stats") as Stats

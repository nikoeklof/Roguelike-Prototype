extends Spell
class_name HealSpell

@export var heal_amount: float = 2.0

func _ready() -> void:
	spell_type = SpellType.DEFENSIVE

func _do_cast(owner_entity: Node, _dir: Vector2) -> void:
	var h := owner_entity.get_node_or_null("Health") as Health
	if h:
		h.heal(heal_amount)

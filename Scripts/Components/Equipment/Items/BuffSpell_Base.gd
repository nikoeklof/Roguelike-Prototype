extends Spell
class_name BuffSpell

func _do_cast(_owner_entity: Node, _dir: Vector2) -> void:
	pass  # Buff effects are applied via on_cast_apply on each attribute, dispatched by Spell.try_cast.

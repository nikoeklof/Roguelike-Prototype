extends EquipmentSlot
class_name SpellSlot

func try_cast(owner_entity: Node, dir: Vector2) -> bool:
	var s := get_item() as Spell
	if s == null:
		return false
	return s.try_cast(owner_entity, dir)

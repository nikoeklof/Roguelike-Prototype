extends Spell
class_name BuffSpell


func _do_cast(owner_entity: Node, _dir: Vector2) -> void:
	if _instance == null or owner_entity == null:
		return
	var spell_def: SpellItemDef = _instance.def as SpellItemDef
	if spell_def == null or spell_def.core_effect == null:
		return
	var ctx: CombatContext = _make_context(owner_entity, _dir)
	spell_def.core_effect.apply_buff(owner_entity, ctx, _instance)

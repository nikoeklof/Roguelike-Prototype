extends AIBehaviorModule
class_name SpellAIModule

## Spell range used only for OFFENSIVE (debuff) spells.
## Buff spells have no range requirement — they affect the caster.
@export var spell_range: float = 250.0


func decide(context: Dictionary) -> AIDecision:
	if _target == null or _combat == null:
		return null

	# Only act while in active combat.
	var awareness: int = context.get("awareness", EnemyAI.Awareness.IDLE)
	if awareness != EnemyAI.Awareness.ALERT:
		return null

	var spell_cooldown: float = context.get("spell_cooldown", 0.0)
	if spell_cooldown > 0.0:
		return null

	var spell_type: int = _get_spell_type()

	if spell_type == Spell.SpellType.DEFENSIVE:
		# Buff: cast whenever ready and in combat. No range/LOS requirement.
		# Priority 75 puts it in movement_decisions above "chase" (70) so it fires
		# opportunistically, but melee_attack (100) still beats it when in range.
		return AIDecision.new("cast_buff_spell", 75, {"ready": true})

	else:
		# Offensive / debuff: must be in range and have LOS.
		var distance: float = context.get("distance", INF)
		var has_los: bool = context.get("has_los", false)
		var invuln: bool = context.get("target_invulnerable", false)
		var repositioning: bool = context.get("repositioning", false)

		if distance <= spell_range and has_los and not invuln and not repositioning:
			return AIDecision.new("cast_spell", 90, {"ready": true, "distance": distance})

		# Out of range or no LOS — return null so the AI chases normally.
		return null


func _get_spell_type() -> int:
	if _equipment == null:
		return Spell.SpellType.OFFENSIVE
	var spell_slot: Node = _equipment.get_node_or_null("SpellSlot")
	if spell_slot == null or not spell_slot.has_method("get_item"):
		return Spell.SpellType.OFFENSIVE
	var item: Node = spell_slot.call("get_item") as Node
	if item == null:
		return Spell.SpellType.OFFENSIVE
	if "spell_type" in item:
		return int(item.get("spell_type"))
	return Spell.SpellType.OFFENSIVE


func physics_update(_delta: float, _decision: AIDecision) -> void:
	pass

extends DebugHUDSection
class_name PlayerStatsSection


func section_name() -> String:
	return "STATS"


func build_text(ctx: DebugHUDContext) -> String:
	var stats: Stats = ctx.player_stats
	if stats == null:
		return "(no Stats component)"

	var base_move_speed: float = stats.base_move_speed
	var effective_move_speed: float = base_move_speed * stats.move_speed_mult()

	var t: String = ""
	t += "Movement Speed Mult: %.2fx" % stats.move_speed_mult()
	t += "\nEffective Move Speed: %.1f" % effective_move_speed
	t += "\nAccel Mult: %.2fx" % stats.accel_mult()
	t += "\nFriction Mult: %.2fx" % stats.friction_mult()
	t += "\n\nAttack Speed Mult: %.2fx" % stats.attack_speed_mult()
	t += "\nDamage Taken Mult: %.2fx" % stats.damage_taken_mult()
	t += "\nFlat Damage Reduction: %.1f" % stats.flat_damage_reduction()

	# Spell cooldown
	var cooldown_remaining: float = stats.get_spell_cooldown_remaining()
	t += "\n\nSpell Cooldown: "
	if cooldown_remaining > 0.0:
		t += "%.2fs" % cooldown_remaining
	else:
		t += "Ready"

	return t

extends SpellEffect
class_name StoneSkinEffect

const STAT_KEY_REDUCTION: StringName = &"buff_stone_skin_reduction"
const STAT_KEY_SPEED:     StringName = &"buff_stone_skin_speed"
const TIMER_META:         StringName = &"_buff_stone_skin_tmr"

@export_range(0.1, 50.0, 0.5) var flat_damage_reduction: float = 3.0
@export_range(0.5, 1.0, 0.01) var move_speed_mult: float = 0.7
@export_range(0.1, 20.0, 0.1) var duration_sec: float = 6.0


func apply_buff(caster: Node, _context: CombatContext, _instance: ItemInstance) -> void:
	var stats: Stats = _find_stats(caster)
	if stats == null:
		return
	var potency: float  = _get_effect_potency(_instance)
	var actual_fdr: float = flat_damage_reduction * potency
	var actual_dur: float = _get_effect_duration(duration_sec, _instance)
	stats.set_flat_damage_reduction(STAT_KEY_REDUCTION, actual_fdr)
	stats.set_move_speed_mult(STAT_KEY_SPEED, move_speed_mult)
	_refresh_timer(caster, TIMER_META, actual_dur, func() -> void:
		if is_instance_valid(stats):
			stats.clear_flat_damage_reduction(STAT_KEY_REDUCTION)
			stats.clear_move_speed_mult(STAT_KEY_SPEED)
	)

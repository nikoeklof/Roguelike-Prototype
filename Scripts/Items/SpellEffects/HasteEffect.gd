extends SpellEffect
class_name HasteEffect

const STAT_KEY:   StringName = &"buff_haste"
const TIMER_META: StringName = &"_buff_haste_tmr"

@export_range(1.01, 3.0, 0.01) var move_speed_mult: float = 1.25
@export_range(0.1, 20.0, 0.1)  var duration_sec: float = 4.0


func apply_buff(caster: Node, _context: CombatContext, _instance: ItemInstance) -> void:
	var stats: Stats = _find_stats(caster)
	if stats == null:
		return
	var potency: float = _get_effect_potency(_instance)
	var actual_dur: float = _get_effect_duration(duration_sec, _instance)
	stats.set_move_speed_mult(STAT_KEY, _scale_mult_stat(move_speed_mult, potency))
	_refresh_timer(caster, TIMER_META, actual_dur, func() -> void:
		if is_instance_valid(stats):
			stats.clear_move_speed_mult(STAT_KEY)
	)

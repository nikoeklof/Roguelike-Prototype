extends SpellEffect
class_name SlowEffect

const STAT_KEY:   StringName = &"debuff_slow"
const TIMER_META: StringName = &"_debuff_slow_tmr"

@export_range(0.1, 0.9, 0.05) var move_speed_mult: float = 0.5
@export_range(0.1, 20.0, 0.1) var duration_sec: float = 3.0


func apply_debuff(target: Node, _context: CombatContext, _instance: ItemInstance) -> void:
	var stats: Stats = _find_stats(target)
	if stats == null:
		return
	var potency: float = _get_effect_potency(_instance)
	var actual_mult: float = clampf(_scale_mult_stat(move_speed_mult, potency), 0.05, 1.0)
	var actual_dur: float  = _get_effect_duration(duration_sec, _instance)
	stats.set_move_speed_mult(STAT_KEY, actual_mult)
	_set_visual_debuff(target, 1.0)
	_set_visual_freeze(target, 1.0)
	_refresh_timer(target, TIMER_META, actual_dur, func() -> void:
		if is_instance_valid(stats):
			stats.clear_move_speed_mult(STAT_KEY)
		_set_visual_debuff(target, 0.0)
		_set_visual_freeze(target, 0.0)
	)

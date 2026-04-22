extends SpellEffect
class_name FrailtyEffect

const STAT_KEY:   StringName = &"debuff_frailty"
const TIMER_META: StringName = &"_debuff_frailty_tmr"

@export_range(1.01, 3.0, 0.01) var damage_taken_mult: float = 1.4
@export_range(0.1, 20.0, 0.1)  var duration_sec: float = 4.0


func apply_debuff(target: Node, _context: CombatContext, _instance: ItemInstance) -> void:
	var stats: Stats = _find_stats(target)
	if stats == null:
		return
	var potency: float = _get_effect_potency(_instance)
	var actual_mult: float = _scale_mult_stat(damage_taken_mult, potency)
	var actual_dur: float  = _get_effect_duration(duration_sec, _instance)
	stats.set_damage_taken_mult(STAT_KEY, actual_mult)
	_set_visual_debuff(target, 1.0)
	_set_visual_poison(target, 1.0)
	_refresh_timer(target, TIMER_META, actual_dur, func() -> void:
		if is_instance_valid(stats):
			stats.clear_damage_taken_mult(STAT_KEY)
		if is_instance_valid(target):
			_set_visual_debuff(target, 0.0)
			_set_visual_poison(target, 0.0)
	)

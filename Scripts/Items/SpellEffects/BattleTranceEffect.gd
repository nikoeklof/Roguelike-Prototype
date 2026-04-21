extends SpellEffect
class_name BattleTranceEffect

const STAT_KEY_SPEED:  StringName = &"buff_battle_trance_speed"
const STAT_KEY_ATTACK: StringName = &"buff_battle_trance_attack"
const STAT_KEY_ACCEL:  StringName = &"buff_battle_trance_accel"
const TIMER_META:      StringName = &"_buff_battle_trance_tmr"

@export_range(1.01, 3.0, 0.01) var attack_speed_mult: float = 1.3
@export_range(1.01, 3.0, 0.01) var move_speed_mult: float = 1.25
@export_range(1.01, 3.0, 0.01) var accel_mult: float = 1.25
@export_range(0.1, 20.0, 0.1)  var duration_sec: float = 5.0


func apply_buff(caster: Node, _context: CombatContext, _instance: ItemInstance) -> void:
	var stats: Stats = _find_stats(caster)
	if stats == null:
		return
	var potency: float = _get_effect_potency(_instance)
	var actual_dur: float = _get_effect_duration(duration_sec, _instance)
	stats.set_move_speed_mult(STAT_KEY_SPEED,  _scale_mult_stat(move_speed_mult, potency))
	stats.set_accel_mult(STAT_KEY_ACCEL,       _scale_mult_stat(accel_mult, potency))
	stats.set_attack_speed_mult(STAT_KEY_ATTACK, _scale_mult_stat(attack_speed_mult, potency))
	_refresh_timer(caster, TIMER_META, actual_dur, func() -> void:
		if is_instance_valid(stats):
			stats.clear_move_speed_mult(STAT_KEY_SPEED)
			stats.clear_accel_mult(STAT_KEY_ACCEL)
			stats.clear_attack_speed_mult(STAT_KEY_ATTACK)
	)

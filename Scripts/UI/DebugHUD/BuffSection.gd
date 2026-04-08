extends DebugHUDSection
class_name BuffsSection

var _buff_timers: Dictionary = {}  # key -> end_time


func section_name() -> String:
	return "ACTIVE BUFFS"


func build_text(ctx: DebugHUDContext) -> String:
	var stats: Stats = ctx.player_stats
	if stats == null:
		return "(none)"

	var buffs: Array[String] = []
	var now: float = Time.get_ticks_msec() / 1000.0

	# Collect all active buff keys
	_collect_buffs(buffs, stats._move_speed_mult_mods, now)
	_collect_buffs(buffs, stats._accel_mult_mods, now)
	_collect_buffs(buffs, stats._friction_mult_mods, now)
	_collect_buffs(buffs, stats._attack_speed_mult_mods, now)
	_collect_buffs(buffs, stats._damage_taken_mult_mods, now)
	_collect_buffs(buffs, stats._flat_damage_reduction_mods, now)
	_collect_buffs(buffs, stats._melee_damage_mult_mods, now)
	_collect_buffs(buffs, stats._ranged_damage_mult_mods, now)

	# Add passive shield ability buffs
	if ctx.player_passive_shield != null and ctx.player_equipment != null:
		var shield_slot: ShieldSlot = ctx.player_equipment.get_node_or_null("ShieldSlot") as ShieldSlot
		if shield_slot != null:
			var shield: Shield = shield_slot.get_item() as Shield
			if shield != null:
				var shield_instance: ItemInstance = shield.get_item_instance()
				if shield_instance != null:
					var passive_buffs: Array[String] = ctx.player_passive_shield.get_active_ability_buffs(shield_instance)
					for buff_text: String in passive_buffs:
						buffs.append(buff_text)

	if buffs.is_empty():
		return "(none)"

	# Deduplicate and sort
	var unique: Dictionary = {}
	for buff: String in buffs:
		unique[buff] = true

	var sorted_buffs: Array[String] = []
	for buff_name: String in unique.keys():
		sorted_buffs.append(buff_name)
	sorted_buffs.sort()

	var t: String = ""
	for buff: String in sorted_buffs:
		var remaining: float = _buff_timers.get(buff, 0.0) - now
		if remaining > 0.0:
			t += "\n %s (%.1fs)" % [buff, remaining]
		else:
			t += "\n %s" % buff

	return t


func _collect_buffs(buffs: Array[String], mods: Dictionary, now: float) -> void:
	for key: StringName in mods.keys():
		var buff_name: String = str(key)
		buffs.append(buff_name)

		if not _buff_timers.has(buff_name):
			var duration: float = 5.0
			if "battle_trance" in buff_name:
				duration = 5.0
			elif "stone_skin" in buff_name:
				duration = 6.0
			_buff_timers[buff_name] = now + duration

		if _buff_timers[buff_name] <= now:
			_buff_timers.erase(buff_name)

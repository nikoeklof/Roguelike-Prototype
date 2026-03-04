extends RefCounted
class_name ModifierResolver

static func _sort_mods(mods: Array[StatModifier]) -> void:
	mods.sort_custom(func(a: StatModifier, b: StatModifier) -> bool:
		if a.priority == b.priority:
			# Deterministic tie-breaker
			return String(a.source_attr_id) < String(b.source_attr_id)
		return a.priority < b.priority
	)

static func resolve_float(base_value: float, mods: Array[StatModifier]) -> float:
	_sort_mods(mods)
	var v: float = base_value
	for m: StatModifier in mods:
		match m.op:
			StatModifier.Op.ADD:
				v += float(m.value)
			StatModifier.Op.MUL:
				v *= (1.0 + float(m.value))
			StatModifier.Op.OVERRIDE:
				v = float(m.value)
	return v

static func resolve_int(base_value: int, mods: Array[StatModifier]) -> int:
	_sort_mods(mods)
	var v: float = float(base_value)
	for m: StatModifier in mods:
		match m.op:
			StatModifier.Op.ADD:
				v += float(m.value)
			StatModifier.Op.MUL:
				v *= (1.0 + float(m.value))
			StatModifier.Op.OVERRIDE:
				v = float(m.value)
	return int(round(v))

static func resolve_vec2(base_value: Vector2, mods: Array[StatModifier]) -> Vector2:
	_sort_mods(mods)
	var v: Vector2 = base_value
	for m: StatModifier in mods:
		match m.op:
			StatModifier.Op.ADD:
				v += (m.value as Vector2)
			StatModifier.Op.MUL:
				# For Vector2 we interpret MUL as uniform scalar multiplier delta
				v *= (1.0 + float(m.value))
			StatModifier.Op.OVERRIDE:
				v = (m.value as Vector2)
	return v

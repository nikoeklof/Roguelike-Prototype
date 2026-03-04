extends RefCounted
class_name StatModifier

enum Op {
	ADD,
	MUL, # v *= (1 + value)
	OVERRIDE,
}

var stat: StringName
var op: int
var value: Variant
var priority: int
var source_attr_id: StringName

func _init(_stat: StringName, _op: int, _value: Variant, _priority: int = 0, _source_attr_id: StringName = &"") -> void:
	stat = _stat
	op = _op
	value = _value
	priority = _priority
	source_attr_id = _source_attr_id

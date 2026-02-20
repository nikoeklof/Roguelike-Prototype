extends Node
class_name Faction

signal faction_changed(new_faction: Id)

enum Id {
	NEUTRAL = 0,
	PLAYER = 1,
	ENEMY = 2,
}

# Backing field so the setter doesn't recurse.
var _faction: Id = Id.NEUTRAL

@export var faction: Id = Id.NEUTRAL:
	get:
		return _faction
	set(value):
		if _faction == value:
			return
		_faction = value
		faction_changed.emit(_faction)

@export var friendly_fire: bool = false


func _ready() -> void:
	# Optional: auto-sync with Tags component
	var tags := get_parent().get_node_or_null("Tags")
	if tags:
		match faction:
			Id.PLAYER: tags.add_tag(&"player")
			Id.ENEMY: tags.add_tag(&"enemy")


func set_faction(value: Id) -> void:
	# Convenience API for callers that prefer a method.
	faction = value


func can_damage(other: Node) -> bool:
	var other_f := _get_other_faction(other)
	if other_f == null:
		return true # allow crates, props etc

	if friendly_fire:
		return true

	return faction != other_f.faction or faction == Id.NEUTRAL or other_f.faction == Id.NEUTRAL


func is_hostile_to(other: Node) -> bool:
	var other_f := _get_other_faction(other)
	if other_f == null:
		return false
	return faction != other_f.faction and other_f.faction != Id.NEUTRAL


func _get_other_faction(other: Node) -> Faction:
	if other == null:
		return null

	var f := other.get_node_or_null("Faction") as Faction
	if f:
		return f

	# fallback search once (cheap)
	for c in other.get_children():
		var fc := c as Faction
		if fc:
			return fc

	return null

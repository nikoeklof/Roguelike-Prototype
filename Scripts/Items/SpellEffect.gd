extends Resource
class_name SpellEffect

## Abstract base for spell core effects.
## Buff effects override apply_buff. Debuff effects override apply_debuff.
## Helpers are shared so subclasses stay lean.

@export var display_name: String = ""
@export var icon: Texture2D = null


# Override in buff subclasses — applies to caster immediately on cast.
func apply_buff(_caster: Node, _context: CombatContext, _instance: ItemInstance) -> void:
	pass


# Override in debuff subclasses — called once per target that the delivery hits.
func apply_debuff(_target: Node, _context: CombatContext, _instance: ItemInstance) -> void:
	pass


# ------------------------------------------------------------------ #
#  Shared helpers
# ------------------------------------------------------------------ #

func _find_stats(root: Node) -> Stats:
	if root is Entity:
		return (root as Entity).find_component(&"Stats") as Stats
	return root.get_node_or_null("Stats") as Stats


func _find_faction(root: Node) -> Faction:
	if root is Entity:
		return (root as Entity).find_component(&"Faction") as Faction
	return root.get_node_or_null("Faction") as Faction


## Cancel any existing timer stored in meta_key, start a new one.
## on_expire is called when the timer fires (before cleanup).
func _refresh_timer(host: Node, timer_meta: StringName, duration: float, on_expire: Callable) -> void:
	if host.has_meta(timer_meta):
		var old: Variant = host.get_meta(timer_meta)
		if old is Timer and is_instance_valid(old as Timer):
			(old as Timer).queue_free()
		host.remove_meta(timer_meta)

	var t := Timer.new()
	t.one_shot  = true
	t.wait_time = maxf(0.01, duration)
	host.add_child(t)
	host.set_meta(timer_meta, t)
	t.timeout.connect(func() -> void:
		on_expire.call()
		if is_instance_valid(host) and host.has_meta(timer_meta):
			host.remove_meta(timer_meta)
		if is_instance_valid(t):
			t.queue_free()
	, CONNECT_ONE_SHOT)
	t.start()


func _set_visual_debuff(target: Node, amount: float) -> void:
	var vc := _find_vc(target)
	if vc != null:
		vc.set_debuff_intensity(amount)


func _set_visual_poison(target: Node, amount: float) -> void:
	var vc := _find_vc(target)
	if vc != null:
		vc.set_poison_amount(amount)


func _set_visual_freeze(target: Node, amount: float) -> void:
	var vc := _find_vc(target)
	if vc != null:
		vc.set_freeze_amount(amount)


## Returns base_sec scaled by any SpellExtendedDuration attributes on inst.
func _get_effect_duration(base_sec: float, inst: ItemInstance) -> float:
	if inst == null:
		return base_sec
	var mult: float = 1.0
	for v: Variant in inst.attributes:
		if v is Object and (v as Object).has_method(&"get_spell_duration_mult"):
			mult *= float((v as Object).call(&"get_spell_duration_mult"))
	return base_sec * mult


## Returns combined potency multiplier from any SpellAmplifiedPotency attributes.
func _get_effect_potency(inst: ItemInstance) -> float:
	if inst == null:
		return 1.0
	var mult: float = 1.0
	for v: Variant in inst.attributes:
		if v is Object and (v as Object).has_method(&"get_spell_potency_mult"):
			mult *= float((v as Object).call(&"get_spell_potency_mult"))
	return mult


## Scale a multiplier stat's deviation from 1.0 by potency.
## e.g. base=1.4 potency=1.2 → 1.48  |  base=0.5 potency=1.2 → 0.4
func _scale_mult_stat(base: float, potency: float) -> float:
	return 1.0 + (base - 1.0) * potency


func _find_vc(root: Node) -> EntityVisualController:
	if root is Entity:
		return (root as Entity).find_component(&"EntityVisualController") as EntityVisualController
	return root.get_node_or_null("EntityVisualController") as EntityVisualController

extends RefCounted
class_name CombatAttributeBus

# Centralized, deterministic attribute dispatch + domain filtering.

var _ctx: CombatContext


func _init(ctx: CombatContext) -> void:
	_ctx = ctx


func _sorted_attrs() -> Array[ItemAttribute]:
	if _ctx == null or _ctx.item_instance == null:
		return []
	var inst: ItemInstance = _ctx.item_instance
	if inst.has_method("get_attributes_sorted"):
		return inst.get_attributes_sorted()

	var arr: Array[ItemAttribute] = []
	for a: ItemAttribute in inst.attributes:
		if a != null:
			arr.append(a)
	arr.sort_custom(func(a: ItemAttribute, b: ItemAttribute) -> bool:
		return _attr_sort_key(a) < _attr_sort_key(b)
	)
	return arr


func _attr_sort_key(a: ItemAttribute) -> String:
	if a == null:
		return ""
	var id_str := String(a.id)
	if id_str.is_empty():
		id_str = String(a.display_name)
	var sp := ""
	var scr: Script = a.get_script() as Script
	if scr != null:
		sp = scr.resource_path
	return id_str + "|" + sp


func _in_domain(a: ItemAttribute, domain: StringName) -> bool:
	if a == null:
		return false
	var d: PackedStringArray = a.get_domains()
	if d == null or d.size() == 0:
		return true # legacy: apply everywhere
	return String(domain) in d


func dispatch_attack_start() -> void:
	for a: ItemAttribute in _sorted_attrs():
		if _in_domain(a, AttributeDomains.ATTACK_START):
			a.on_attack_start(_ctx, _ctx.item_instance)


func dispatch_on_hit(hit: HitEvent) -> void:
	for a: ItemAttribute in _sorted_attrs():
		if _in_domain(a, AttributeDomains.HIT):
			a.on_hit(_ctx, hit, _ctx.item_instance)


func dispatch_projectile_spawn(projectile: Projectile) -> void:
	for a: ItemAttribute in _sorted_attrs():
		if _in_domain(a, AttributeDomains.PROJECTILE_SPAWN):
			a.on_projectile_spawn(_ctx, projectile, _ctx.item_instance)


func dispatch_modify_ranged_shot(shot: RangedShotData) -> void:
	for a: ItemAttribute in _sorted_attrs():
		if _in_domain(a, AttributeDomains.RANGED_SHOT):
			a.modify_ranged_shot(_ctx, shot, _ctx.item_instance)


func dispatch_cast_start() -> void:
	for a: ItemAttribute in _sorted_attrs():
		if _in_domain(a, AttributeDomains.CAST_START):
			a.on_cast_start(_ctx, _ctx.item_instance)


func dispatch_cast_apply() -> void:
	for a: ItemAttribute in _sorted_attrs():
		if _in_domain(a, AttributeDomains.CAST_APPLY):
			a.on_cast_apply(_ctx, _ctx.item_instance)


func dispatch_parry() -> void:
	for a: ItemAttribute in _sorted_attrs():
		if _in_domain(a, AttributeDomains.PARRY):
			a.on_parry(_ctx, _ctx.item_instance)


func collect_stat_additives() -> ItemStats:
	var out := ItemStats.new()
	if _ctx == null or _ctx.item_instance == null:
		return out
	for a: ItemAttribute in _sorted_attrs():
		if not _in_domain(a, AttributeDomains.STATS):
			continue
		var add: ItemStats = a.get_stat_additive(_ctx, _ctx.item_instance)
		if add != null:
			out.apply_additive(add)
	return out

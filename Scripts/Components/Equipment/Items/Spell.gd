extends Node
class_name Spell

signal cast_finished(success: bool)

enum SpellType { OFFENSIVE, DEFENSIVE }

@export var spell_type: SpellType = SpellType.OFFENSIVE
@export var allow_move_during_cast: bool = false

@export var pickup_slot_kind: Equipment.SlotKind = Equipment.SlotKind.SPELL
@export var pickup_icon: Texture2D

@export var item_def: ItemDef
@export var item_seed: int = 0
@export_range(0, 8, 1) var editor_attribute_count: int = 0

var _instance: ItemInstance = null
var _cd_until: float = 0.0


func _ready() -> void:
	if _instance != null:
		return
	if item_def == null:
		push_warning("%s: item_def is null (Spell expects ItemDef)." % name)
		return

	_instance = ItemInstance.new()
	_instance.def = item_def
	_instance.seed = item_seed
	_instance.ensure_initialized()
	if editor_attribute_count > 0:
		_instance.roll_attributes(editor_attribute_count)


func get_item_instance() -> ItemInstance:
	return _instance


func set_item_instance(inst: ItemInstance) -> void:
	_instance = inst
	if _instance != null and _instance.def != null:
		item_def = _instance.def
		item_seed = _instance.seed


func can_cast() -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	return now >= _cd_until


func get_pickup_slot_kind() -> int:
	return int(pickup_slot_kind)


func get_pickup_icon() -> Texture2D:
	return pickup_icon


func try_cast(owner_entity: Node, dir: Vector2) -> bool:
	if owner_entity == null or not can_cast():
		return false

	var d: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT

	var cooldown_sec: float = 0.0
	var cast_time_sec: float = 0.0
	var ctx: CombatContext = _make_context(owner_entity, d)

	if _instance != null:
		var stats: ItemStats = _instance.compute_stats(ctx)
		cooldown_sec = stats.cooldown_sec
		cast_time_sec = stats.windup_time

	_dispatch_cast_start(ctx)

	var now: float = Time.get_ticks_msec() / 1000.0
	_cd_until = now + max(cooldown_sec, 0.0)

	if cast_time_sec <= 0.0:
		_do_cast(owner_entity, d)
		_dispatch_cast_apply(ctx)
		cast_finished.emit(true)
		return true

	var t: Timer = Timer.new()
	t.one_shot = true
	t.wait_time = cast_time_sec
	owner_entity.add_child(t)
	t.timeout.connect(Callable(self, "_finish_delayed_cast").bind(owner_entity, d, t), CONNECT_ONE_SHOT)
	t.start()
	return true


func _finish_delayed_cast(owner_entity: Node, dir: Vector2, timer: Timer) -> void:
	if is_instance_valid(owner_entity):
		_do_cast(owner_entity, dir)
		_dispatch_cast_apply(_make_context(owner_entity, dir))

	cast_finished.emit(true)

	if is_instance_valid(timer):
		timer.queue_free()


func _do_cast(_owner_entity: Node, _dir: Vector2) -> void:
	pass


func _make_context(owner_entity: Node, aim_dir: Vector2) -> CombatContext:
	var ctx: CombatContext = CombatContext.new()
	ctx.owner = owner_entity
	ctx.aim_dir = aim_dir
	ctx.item = self
	ctx.item_instance = _instance

	if owner_entity is Entity:
		var ent: Entity = owner_entity as Entity
		ctx.stats = ent.find_component(&"Stats")
		ctx.tags = ent.find_component(&"Tags")
		ctx.faction = ent.find_component(&"Faction")
		ctx.capabilities = ent.find_component(&"Capabilities")
	else:
		ctx.stats = owner_entity.get_node_or_null("Stats")
		ctx.faction = owner_entity.get_node_or_null("Faction")
		ctx.tags = owner_entity.get_node_or_null("Tags")
		ctx.capabilities = owner_entity.get_node_or_null("Capabilities")

	return ctx


func _dispatch_cast_start(ctx: CombatContext) -> void:
	if _instance == null:
		return
	for a: Variant in _instance.attributes:
		if a == null:
			continue
		(a as ItemAttribute).on_cast_start(ctx, _instance)


func _dispatch_cast_apply(ctx: CombatContext) -> void:
	if _instance == null:
		return
	for a: Variant in _instance.attributes:
		if a == null:
			continue
		(a as ItemAttribute).on_cast_apply(ctx, _instance)

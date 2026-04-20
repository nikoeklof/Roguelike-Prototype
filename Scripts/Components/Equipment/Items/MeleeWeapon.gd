extends Weapon
class_name MeleeWeapon

@export var item_def: MeleeItemDef
@export var item_seed: int = 0
@export_range(0, 8, 1) var editor_attribute_count: int = 0

@export var melee_executor_scene: PackedScene = preload("res://Scenes/Combat/Executors/MeleeSlashExecutor.tscn")

var _instance: ItemInstance = null


var rarity: int:
	get:
		return 0 if _instance == null else _instance.rarity()


func _ready() -> void:
	if _instance != null:
		return

	if item_def == null:
		push_warning("%s: item_def is null." % name)
		return

	_instance = ItemInstance.new()
	_instance.def = item_def
	_instance.item_seed = item_seed
	_instance.ensure_initialized()


func get_item_instance() -> ItemInstance:
	return _instance


func set_item_instance(inst: ItemInstance) -> void:
	_instance = inst
	if _instance != null and _instance.def != null:
		item_def = _instance.def as MeleeItemDef
		item_seed = _instance.item_seed


func get_attack_variant(_ctx: CombatContext) -> AttackVariant:
	if not can_attack():
		return null
	if _instance == null:
		_ready()
	if _instance == null:
		return null

	var stats: MeleeItemStats = item_def.stats if item_def != null else null

	var variant: MeleeSlashVariant = MeleeSlashVariant.new()
	variant.executor_scene = melee_executor_scene
	variant.one_hit_per_target = true

	if item_def != null:
		variant.swing_style = item_def.swing_style
		variant.arc_degrees = item_def.arc_degrees
		variant.shield_penetration = item_def.shield_penetration
		variant.lunge_speed = item_def.lunge_speed

	if stats != null:
		variant.offset = stats.hitbox_offset
		variant.size = stats.hitbox_size
		variant.windup_time = stats.windup_time
		variant.recovery_time = stats.recovery_time

	return variant


func try_attack(dir: Vector2, owner_entity: Node) -> bool:
	if owner_entity == null:
		return false
	if not can_attack():
		return false

	var cooldown_sec: float = 0.0
	if _instance != null:
		var ctx: CombatContext = CombatContext.new()
		ctx.owner = owner_entity
		ctx.aim_dir = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
		ctx.item = self
		ctx.item_instance = _instance

		var s: ItemStats = _instance.compute_stats(ctx)
		cooldown_sec = s.cooldown_sec

	commit_cooldown(cooldown_sec)
	return false

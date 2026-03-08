extends Weapon
class_name MeleeWeapon

@export var item_def: ItemDef
@export var item_seed: int = 0
@export_range(0, 8, 1) var editor_attribute_count: int = 0

@export var melee_executor_scene: PackedScene = preload("res://Scenes/Combat/Executors/MeleeSlashExecutor.tscn")

# Transitional defaults. Long-term these should move into data resources.
@export var default_hitbox_offset: Vector2 = Vector2(10, 0)
@export var default_hitbox_size: Vector2 = Vector2(26, 18)
@export_range(0.01, 2.0, 0.01) var default_active_time: float = 0.10
@export_range(0.0, 5000.0, 1.0) var default_knockback: float = 0.0
@export_range(0.0, 2.0, 0.01) var default_windup: float = 0.0
@export_range(0.0, 2.0, 0.01) var default_recovery: float = 0.10

var _instance: ItemInstance = null


var rarity: int:
	get:
		return 0 if _instance == null else _instance.rarity()


func _ready() -> void:
	if _instance != null:
		return

	if item_def == null:
		push_warning("%s: item_def is null. This weapon cannot run the new item system." % name)
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


func get_attack_variant(_ctx: CombatContext) -> AttackVariant:
	if not can_attack():
		return null
	if _instance == null:
		_ready()
	if _instance == null:
		return null
	var variant: MeleeSlashVariant = MeleeSlashVariant.new()
	variant.executor_scene = melee_executor_scene
	variant.offset = default_hitbox_offset
	variant.size = default_hitbox_size
	variant.one_hit_per_target = true
	variant.windup_time = default_windup
	variant.recovery_time = default_recovery
	return variant


func try_attack(dir: Vector2, owner_entity: Node) -> bool:
	# Legacy-safe fallback only.
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

		var stats: ItemStats = _instance.compute_stats(ctx)
		cooldown_sec = stats.cooldown_sec

	commit_cooldown(cooldown_sec)
	return false

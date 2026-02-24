extends Weapon
class_name MeleeWeapon

# ---- New data-driven item system ----
@export var item_def: ItemDef
@export var item_seed: int = 0

# If this weapon is hand-placed (not rolled by pickup), you can optionally roll attributes here.
# For rolled pickups, leave at 0 and let ItemPickupRoller assign the instance.
@export_range(0, 8, 1) var editor_attribute_count: int = 0

@export var melee_executor_scene: PackedScene = preload("res://Scenes/Combat/Executors/MeleeSlashExecutor.tscn")

# Defaults used only when stat fields are not provided by computed ItemStats.
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
	# If injected by pickup, do nothing.
	if _instance != null:
		return

	# If hand-authored, create a deterministic instance from item_seed.
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


func get_attack_variant(ctx: CombatContext) -> AttackVariant:
	if item_def == null:
		return null
	if _instance == null:
		_ready()
	if _instance == null:
		return null

	ctx.item_instance = _instance

	var stats := _instance.compute_stats(ctx)

	var v := MeleeSlashVariant.new()
	v.executor_scene = melee_executor_scene

	# Damage MUST come from stats now.
	# If you forget to set base_stats.damage, you will deal 0 damage (by design).
	v.base_damage = stats.damage

	# Timings
	v.windup_time = stats.windup_time if stats.windup_time > 0.0 else default_windup
	v.recovery_time = stats.recovery_time if stats.recovery_time > 0.0 else default_recovery
	v.active_time = stats.active_time if stats.active_time > 0.0 else default_active_time

	# Geometry (WeaponSocket-origin system)
	v.offset = stats.hitbox_offset if stats.hitbox_offset != Vector2.ZERO else default_hitbox_offset
	v.size = stats.hitbox_size if stats.hitbox_size != Vector2.ZERO else default_hitbox_size

	# Knockback
	v.knockback = stats.knockback if stats.knockback > 0.0 else default_knockback

	return v


func try_attack(dir: Vector2, owner_entity: Node) -> bool:
	# Combat should be using get_attack_variant() + executor.
	# If something calls try_attack directly, we still gate cooldown correctly.
	if owner_entity == null:
		return false
	if not can_attack():
		return false

	var cd := 0.0
	if _instance != null:
		var ctx := CombatContext.new()
		ctx.owner = owner_entity
		ctx.aim_dir = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
		ctx.item = self
		ctx.item_instance = _instance
		cd = _instance.compute_stats(ctx).cooldown_sec

	commit_cooldown(cd)
	return false

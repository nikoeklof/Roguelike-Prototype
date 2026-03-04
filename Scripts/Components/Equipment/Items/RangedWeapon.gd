extends Weapon
class_name RangedWeapon

# ---- New data-driven item system ----
@export var item_def: ItemDef
@export var item_seed: int = 0
@export_range(0, 8, 1) var editor_attribute_count: int = 0

# Executor used by RangedFireVariant
@export var ranged_executor_scene: PackedScene = preload("res://Scenes/Combat/Executors/RangedFireExecutor.tscn")

# Inspector-driven mechanical defaults (attributes can override via modify_ranged_shot)
@export var projectile_scene: PackedScene
@export var muzzle_offset: Vector2 = Vector2.ZERO

@export_range(0.0, 5000.0, 1.0) var speed: float = 450.0
@export_range(-2000.0, 2000.0, 1.0) var gravity: float = 0.0
@export_range(0.05, 30.0, 0.05) var lifetime_sec: float = 2.0
@export_range(0.0, 1.0, 0.01) var inherit_owner_velocity: float = 0.0

@export_range(0.0, 60.0, 0.1) var spread_degrees: float = 0.0
@export_range(0.0, 60.0, 0.1) var spread_pattern_degrees: float = 0.0

# Default ranges for non-projectile modes (attributes can override)
@export_range(1.0, 5000.0, 1.0) var hitscan_range: float = 900.0
@export_range(1.0, 5000.0, 1.0) var beam_range: float = 900.0
@export_range(0.05, 5.0, 0.01) var beam_duration_sec: float = 0.35
@export_range(0.02, 1.0, 0.01) var beam_tick_sec: float = 0.10

# Timing defaults if stats don’t provide them
@export_range(0.0, 2.0, 0.01) var default_windup: float = 0.0
@export_range(0.0, 2.0, 0.01) var default_recovery: float = 0.10

# Default base mode (attributes can change shot.mode)
@export var default_mode: RangedShotData.ShotMode = RangedShotData.ShotMode.PROJECTILE

var _instance: ItemInstance = null


func _ready() -> void:
	if _instance != null:
		return
	if item_def == null:
		push_warning("%s: item_def is null (RangedWeapon expects ItemDef)." % name)
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
	# Gate by weapon cooldown in the NEW executor path.
	if not can_attack():
		return null

	if item_def == null:
		return null
	if _instance == null:
		_ready()
	if _instance == null:
		return null

	ctx.item_instance = _instance

	var stats: ItemStats = _instance.compute_stats(ctx)

	# Commit cooldown here so executor-path respects cooldown.
	commit_cooldown(stats.cooldown_sec)

	var v: RangedFireVariant = RangedFireVariant.new()
	v.executor_scene = ranged_executor_scene

	# Timing (use stats if provided, otherwise inspector defaults)
	v.windup_time = stats.windup_time if stats.windup_time > 0.0 else default_windup
	v.recovery_time = stats.recovery_time if stats.recovery_time > 0.0 else default_recovery

	# Mechanical defaults (attributes can override via modify_ranged_shot)
	v.default_mode = default_mode
	# Preferred: mode is rolled and stored on the ItemInstance.
	if _instance != null and int(_instance.ranged_mode) >= 0:
		v.default_mode = int(_instance.ranged_mode)
	v.spread_degrees = spread_degrees
	v.spread_pattern_degrees = spread_pattern_degrees
	v.muzzle_offset = muzzle_offset

	v.projectile_scene = projectile_scene
	v.projectile_speed = speed
	v.projectile_gravity = gravity
	v.projectile_lifetime_sec = lifetime_sec
	v.inherit_owner_velocity = inherit_owner_velocity

	v.hitscan_range = hitscan_range
	v.beam_range = beam_range
	v.beam_duration_sec = beam_duration_sec
	v.beam_tick_sec = beam_tick_sec

	return v


func try_attack(dir: Vector2, owner_entity: Node) -> bool:
	# Legacy path kept only so older callers don’t break.
	# Combat should be using get_attack_variant() + executor.
	if owner_entity == null:
		return false
	if not can_attack():
		return false

	# If something calls try_attack directly, we still gate cooldown correctly.
	var cd: float = 0.0
	if _instance != null:
		var ctx: CombatContext = CombatContext.new()
		ctx.owner = owner_entity
		ctx.aim_dir = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
		ctx.item = self
		ctx.item_instance = _instance
		cd = _instance.compute_stats(ctx).cooldown_sec

	commit_cooldown(cd)
	return false

extends Weapon
class_name RangedWeapon

@export var item_def: ItemDef
@export var item_seed: int = 0
@export_range(0, 8, 1) var editor_attribute_count: int = 0

@export var ranged_executor_scene: PackedScene = preload("res://Scenes/Combat/Executors/RangedFireExecutor.tscn")

@export var projectile_spec: ProjectileSpec
@export var projectile_scene: PackedScene = preload("res://Scenes/Templates/EquipmentItems/Projectile_template.tscn")
@export var muzzle_offset: Vector2 = Vector2.ZERO

@export_range(0.0, 5000.0, 1.0) var speed: float = 450.0
@export_range(-2000.0, 2000.0, 1.0) var gravity: float = 0.0
@export_range(0.05, 30.0, 0.05) var lifetime_sec: float = 2.0
@export_range(1.0, 256.0, 1.0) var projectile_radius: float = 6.0
@export_range(0.0, 1.0, 0.01) var inherit_owner_velocity: float = 0.0
@export_range(0.0, 5000.0, 1.0) var projectile_range: float = 0.0
@export var projectile_collision_mask: int = 0x7FFFFFFF
@export var projectile_sprite_texture: Texture2D
@export var projectile_sprite_tint: Color = Color.WHITE

@export_range(0.0, 60.0, 0.1) var spread_degrees: float = 0.0
@export_range(0.0, 60.0, 0.1) var spread_pattern_degrees: float = 0.0

@export_range(1.0, 5000.0, 1.0) var hitscan_range: float = 900.0
@export_range(1.0, 5000.0, 1.0) var beam_range: float = 900.0
@export_range(0.05, 5.0, 0.01) var beam_duration_sec: float = 0.35
@export_range(0.02, 1.0, 0.01) var beam_tick_sec: float = 0.10

@export_range(0.0, 2.0, 0.01) var default_windup: float = 0.0
@export_range(0.0, 2.0, 0.01) var default_recovery: float = 0.10

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
		item_seed = _instance.item_seed


func get_ranged_profile() -> RangedAttackProfile:
	if item_def == null:
		return null
	return item_def.get_ranged_profile_safe()


func fires_while_held() -> bool:
	return true


func get_attack_variant(ctx: CombatContext) -> AttackVariant:
	if not can_attack():
		return null

	if item_def == null:
		return null

	if _instance == null:
		_ready()

	if _instance == null:
		return null

	ctx.item_instance = _instance

	var profile: RangedAttackProfile = item_def.get_ranged_profile_safe()

	var variant: RangedFireVariant = RangedFireVariant.new()
	variant.executor_scene = ranged_executor_scene

	variant.windup_time = default_windup
	variant.recovery_time = default_recovery

	variant.default_mode = default_mode
	if profile != null:
		variant.default_mode = profile.default_mode

	if int(_instance.ranged_mode) >= 0:
		variant.default_mode = _instance.ranged_mode as RangedShotData.ShotMode

	if profile != null:
		variant.spread_degrees = profile.spread_degrees
		variant.spread_pattern_degrees = profile.spread_pattern_degrees
		variant.muzzle_offset = profile.muzzle_offset
	else:
		variant.spread_degrees = spread_degrees
		variant.spread_pattern_degrees = spread_pattern_degrees
		variant.muzzle_offset = muzzle_offset

	if profile != null:
		variant.projectile_spec = profile.projectile_spec
		variant.projectile_scene = profile.projectile_scene
		variant.projectile_speed = profile.projectile_speed
		variant.projectile_gravity = profile.projectile_gravity
		variant.projectile_lifetime_sec = profile.projectile_lifetime_sec
		variant.projectile_radius = profile.projectile_radius
		variant.inherit_owner_velocity = profile.inherit_owner_velocity
		variant.projectile_range = profile.projectile_range
		variant.projectile_collision_mask = profile.projectile_collision_mask
		variant.projectile_sprite_texture = profile.projectile_sprite_texture
		variant.projectile_sprite_tint = profile.projectile_sprite_tint

		variant.hitscan_range = profile.hitscan_range
		variant.beam_range = profile.beam_range
		variant.beam_duration_sec = profile.beam_duration_sec
		variant.beam_tick_sec = profile.beam_tick_sec
	else:
		variant.projectile_spec = projectile_spec
		variant.projectile_scene = projectile_scene
		variant.projectile_speed = speed
		variant.projectile_gravity = gravity
		variant.projectile_lifetime_sec = lifetime_sec
		variant.projectile_radius = projectile_radius
		variant.inherit_owner_velocity = inherit_owner_velocity
		variant.projectile_range = projectile_range
		variant.projectile_collision_mask = projectile_collision_mask
		variant.projectile_sprite_texture = projectile_sprite_texture
		variant.projectile_sprite_tint = projectile_sprite_tint

		variant.hitscan_range = hitscan_range
		variant.beam_range = beam_range
		variant.beam_duration_sec = beam_duration_sec
		variant.beam_tick_sec = beam_tick_sec

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

		var stats: ItemStats = _instance.compute_stats(ctx)
		cooldown_sec = stats.cooldown_sec

	commit_cooldown(cooldown_sec)
	return false

extends Weapon
class_name RangedWeapon

@export var item_def: RangedItemDef
@export var item_seed: int = 0
@export_range(0, 8, 1) var editor_attribute_count: int = 0

@export var ranged_executor_scene: PackedScene = preload("res://Scenes/Combat/Executors/RangedFireExecutor.tscn")

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
		item_def = _instance.def as RangedItemDef
		item_seed = _instance.item_seed


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

	var stats: RangedItemStats = item_def.stats

	var variant: RangedFireVariant = RangedFireVariant.new()
	variant.executor_scene = ranged_executor_scene

	if stats != null:
		variant.windup_time = stats.windup_time
		variant.recovery_time = stats.recovery_time
		variant.default_mode = stats.default_mode
		variant.spread_degrees = stats.spread_degrees
		variant.spread_pattern_degrees = stats.spread_pattern_degrees
		variant.muzzle_offset = stats.muzzle_offset
		variant.projectile_scene = stats.projectile_scene
		variant.projectile_speed = stats.projectile_speed
		variant.projectile_gravity = stats.projectile_gravity
		variant.projectile_lifetime_sec = stats.projectile_lifetime_sec
		variant.projectile_radius = stats.projectile_radius
		variant.inherit_owner_velocity = stats.inherit_owner_velocity
		variant.projectile_range = stats.projectile_range
		variant.projectile_collision_mask = stats.projectile_collision_mask
		variant.projectile_sprite_texture = stats.projectile_sprite_texture
		variant.projectile_sprite_tint = stats.projectile_sprite_tint
		variant.hitscan_range = stats.hitscan_range
		variant.beam_range = stats.beam_range
		variant.beam_duration_sec = stats.beam_duration_sec
		variant.beam_tick_sec = stats.beam_tick_sec

	if _instance.ranged_mode >= 0:
		variant.default_mode = _instance.ranged_mode as RangedShotData.ShotMode

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

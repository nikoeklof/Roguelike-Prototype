extends Resource
class_name RangedAttackProfile

@export var default_mode: RangedShotData.ShotMode = RangedShotData.ShotMode.PROJECTILE

@export var projectile_spec: ProjectileSpec

@export_range(0.0, 60.0, 0.1) var spread_degrees: float = 0.0
@export_range(0.0, 60.0, 0.1) var spread_pattern_degrees: float = 0.0
@export var muzzle_offset: Vector2 = Vector2.ZERO

@export_range(1.0, 5000.0, 1.0) var hitscan_range: float = 900.0
@export_range(1.0, 5000.0, 1.0) var beam_range: float = 900.0
@export_range(0.05, 5.0, 0.01) var beam_duration_sec: float = 0.35
@export_range(0.02, 1.0, 0.01) var beam_tick_sec: float = 0.10

@export var projectile_scene: PackedScene
@export_range(0.0, 5000.0, 1.0) var projectile_speed: float = 450.0
@export_range(-5000.0, 5000.0, 1.0) var projectile_gravity: float = 0.0
@export_range(0.05, 30.0, 0.05) var projectile_lifetime_sec: float = 2.0
@export_range(1.0, 256.0, 1.0) var projectile_radius: float = 6.0
@export_range(0.0, 1.0, 0.01) var inherit_owner_velocity: float = 0.0
@export_range(0.0, 5000.0, 1.0) var projectile_range: float = 0.0
@export var projectile_collision_mask: int = 0x7FFFFFFF
@export var projectile_sprite_texture: Texture2D
@export var projectile_sprite_tint: Color = Color.WHITE

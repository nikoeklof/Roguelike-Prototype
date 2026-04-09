extends RefCounted
class_name RangedShotData

enum ShotMode { PROJECTILE, HITSCAN, BEAM }

var mode: ShotMode = ShotMode.PROJECTILE

var origin: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT

var damage: float = 1.0
var pierce: int = 0

var speed: float = 450.0
var gravity: float = 0.0
var lifetime_sec: float = 2.0
var max_range: float = 900.0

var beam_duration_sec: float = 0.35
var beam_tick_sec: float = 0.10

var projectile_scene: PackedScene = null
var projectile_spec: ProjectileSpec = null
var projectile_radius: float = 6.0
var projectile_collision_mask: int = 0x7FFFFFFF
var projectile_sprite_texture: Texture2D = null
var projectile_sprite_tint: Color = Color.WHITE

var inherit_owner_velocity: float = 0.0

var shot_index: int = 0
var shot_count: int = 1

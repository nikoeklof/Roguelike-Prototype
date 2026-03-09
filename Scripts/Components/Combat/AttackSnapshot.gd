extends RefCounted
class_name AttackSnapshot

var context: CombatContext
var item_instance: ItemInstance
var stats: ItemStats

var damage: float = 0.0
var cooldown_sec: float = 0.0
var windup_time: float = 0.0
var active_time: float = 0.0
var recovery_time: float = 0.0
var knockback: float = 0.0

var hitbox_offset: Vector2 = Vector2.ZERO
var hitbox_size: Vector2 = Vector2.ZERO

var projectile_count: int = 1
var pierce: int = 0
var ranged_mode: int = 0

var spread_roll: int = 0

var muzzle_offset: Vector2 = Vector2.ZERO
var spread_degrees: float = 0.0
var spread_pattern_degrees: float = 0.0

var projectile_spec: ProjectileSpec = null
var projectile_scene: PackedScene = null
var projectile_speed: float = 450.0
var projectile_gravity: float = 0.0
var projectile_lifetime_sec: float = 2.0
var projectile_radius: float = 6.0
var projectile_inherit_owner_velocity: float = 0.0
var projectile_range: float = 0.0
var projectile_collision_mask: int = 0x7FFFFFFF
var projectile_sprite_texture: Texture2D = null
var projectile_sprite_tint: Color = Color.WHITE

var hitscan_range: float = 900.0

var beam_range: float = 900.0
var beam_duration_sec: float = 0.35
var beam_tick_sec: float = 0.10
